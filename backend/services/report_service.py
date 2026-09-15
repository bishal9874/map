import uuid
import logging
from datetime import datetime, timedelta, timezone
from database import get_db

logger = logging.getLogger("crowdnav.report")

class ReportService:
    async def submit_report(self, user_id: str, latitude: float, longitude: float, reason: str, reason_text: str = "", severity: int = 3):
        db = get_db()
        now = datetime.now(timezone.utc)
        
        if db is None:
            # InMemory mock response if DB not connected
            report = {
                "reportId": str(uuid.uuid4()),
                "userId": user_id or "anonymous",
                "location": {"type": "Point", "coordinates": [longitude, latitude]},
                "reason": reason,
                "reasonText": reason_text or "",
                "severity": severity or 3,
                "confidenceScore": 0.3,
                "corroborations": 1,
                "isActive": True,
                "expiresAt": now + timedelta(hours=2),
                "createdAt": now,
                "updatedAt": now,
            }
            return {"success": True, "report": report, "isCorroboration": False}

        # Check for nearby reports within 100m
        nearby = await self._find_nearby_reports(longitude, latitude, 100)
        
        # Check if there is a recent similar report within 1 hour
        similar_report = None
        for r in nearby:
            if r.get("reason") == reason:
                created_at = r.get("createdAt")
                if isinstance(created_at, datetime):
                    if (now - created_at.replace(tzinfo=timezone.utc if created_at.tzinfo is None else created_at)).total_seconds() < 3600:
                        similar_report = r
                        break

        if similar_report:
            return await self._corroborate_report(similar_report, user_id)

        report_doc = {
            "reportId": str(uuid.uuid4()),
            "userId": user_id or "anonymous",
            "location": {
                "type": "Point",
                "coordinates": [longitude, latitude],
            },
            "reason": reason,
            "reasonText": reason_text or "",
            "severity": severity or 3,
            "confidenceScore": 0.3,
            "corroborations": 1,
            "isActive": True,
            "expiresAt": now + timedelta(hours=2),
            "createdAt": now,
            "updatedAt": now,
        }
        
        res = await db["reports"].insert_one(report_doc)
        report_doc["_id"] = str(res.inserted_id)

        await self._update_hotspot(longitude, latitude, reason, severity)
        if user_id and user_id != "anonymous":
            await self._award_user_points(user_id, 10)

        return {"success": True, "report": report_doc, "isCorroboration": False}

    async def get_nearby_reports(self, latitude: float, longitude: float, radius_meters: int = 2000):
        return await self._find_nearby_reports(longitude, latitude, radius_meters)

    async def get_route_reports(self, route_coordinates: list):
        reports = []
        seen_ids = set()
        step = max(1, len(route_coordinates) // 20)
        
        for i in range(0, len(route_coordinates), step):
            coord = route_coordinates[i]
            nearby = await self._find_nearby_reports(coord[0], coord[1], 300)
            for r in nearby:
                r_id = r.get("reportId")
                if r_id not in seen_ids:
                    seen_ids.add(r_id)
                    reports.append(r)
        return reports

    async def get_hotspots(self, latitude: float, longitude: float, radius_meters: int = 5000):
        db = get_db()
        if db is None:
            return []
            
        cursor = db["hotspots"].find({
            "isActive": True,
            "location": {
                "$near": {
                    "$geometry": {
                        "type": "Point",
                        "coordinates": [longitude, latitude],
                    },
                    "$maxDistance": radius_meters,
                }
            }
        }).sort("confidenceScore", -1).limit(50)
        
        results = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            results.append(doc)
        return results

    async def get_aggregated_data(self, latitude: float, longitude: float, radius_meters: int = 5000):
        reports = await self.get_nearby_reports(latitude, longitude, radius_meters)
        reason_counts = {}
        location_clusters = {}

        for r in reports:
            reason = r.get("reason", "unknown")
            reason_counts[reason] = reason_counts.get(reason, 0) + 1
            
            coords = r.get("location", {}).get("coordinates", [0, 0])
            grid_key = f"{round(coords[0] * 1000) / 1000},{round(coords[1] * 1000) / 1000}"
            
            if grid_key not in location_clusters:
                location_clusters[grid_key] = {
                    "coordinates": coords,
                    "count": 0,
                    "reasons": {},
                    "avgSeverity": 0.0,
                }
                
            cluster = location_clusters[grid_key]
            cluster["count"] += 1
            cluster["reasons"][reason] = cluster["reasons"].get(reason, 0) + 1
            
            prev_sum = cluster["avgSeverity"] * (cluster["count"] - 1)
            cluster["avgSeverity"] = (prev_sum + r.get("severity", 3)) / cluster["count"]

        clusters = []
        for cluster in location_clusters.values():
            sorted_reasons = sorted(cluster["reasons"].items(), key=lambda x: x[1], reverse=True)
            primary = sorted_reasons[0][0] if sorted_reasons else "unknown"
            clusters.append({
                "coordinates": cluster["coordinates"],
                "count": cluster["count"],
                "reasons": cluster["reasons"],
                "avgSeverity": cluster["avgSeverity"],
                "confidenceScore": min(1.0, cluster["count"] * 0.15),
                "primaryReason": primary,
            })

        problem_areas = [c for c in clusters if c["count"] >= 2]
        problem_areas.sort(key=lambda x: x["confidenceScore"], reverse=True)

        return {
            "totalReports": len(reports),
            "reasonBreakdown": reason_counts,
            "problemAreas": problem_areas,
            "allClusters": clusters,
        }

    async def _find_nearby_reports(self, longitude: float, latitude: float, max_distance: int = 500):
        db = get_db()
        if db is None:
            return []
            
        cursor = db["reports"].find({
            "isActive": True,
            "location": {
                "$near": {
                    "$geometry": {
                        "type": "Point",
                        "coordinates": [longitude, latitude],
                    },
                    "$maxDistance": max_distance,
                }
            }
        })
        
        results = []
        async for doc in cursor:
            doc["_id"] = str(doc["_id"])
            results.append(doc)
        return results

    async def _corroborate_report(self, existing_report: dict, user_id: str):
        db = get_db()
        now = datetime.now(timezone.utc)
        
        corroborations = existing_report.get("corroborations", 1) + 1
        confidence_score = min(1.0, corroborations * 0.15)
        expires_at = now + timedelta(hours=corroborations)
        
        if db is not None:
            await db["reports"].update_one(
                {"reportId": existing_report["reportId"]},
                {"$set": {
                    "corroborations": corroborations,
                    "confidenceScore": confidence_score,
                    "expiresAt": expires_at,
                    "updatedAt": now,
                }}
            )

        existing_report["corroborations"] = corroborations
        existing_report["confidenceScore"] = confidence_score
        existing_report["expiresAt"] = expires_at

        if user_id and user_id != "anonymous":
            await self._award_user_points(user_id, 5)

        return {"success": True, "report": existing_report, "isCorroboration": True}

    async def _update_hotspot(self, longitude: float, latitude: float, reason: str, severity: int):
        db = get_db()
        if db is None:
            return
            
        now = datetime.now(timezone.utc)
        nearby_hotspot = await db["hotspots"].find_one({
            "location": {
                "$near": {
                    "$geometry": {
                        "type": "Point",
                        "coordinates": [longitude, latitude],
                    },
                    "$maxDistance": 200,
                }
            }
        })
        
        if nearby_hotspot:
            total_reports = nearby_hotspot.get("totalReports", 0) + 1
            recent_reports = nearby_hotspot.get("recentReports", 0) + 1
            avg_sev = nearby_hotspot.get("averageSeverity", 3)
            new_avg_sev = (avg_sev * (total_reports - 1) + severity) / total_reports
            conf_score = min(1.0, total_reports * 0.1)
            
            await db["hotspots"].update_one(
                {"_id": nearby_hotspot["_id"]},
                {"$set": {
                    "totalReports": total_reports,
                    "recentReports": recent_reports,
                    "lastReportedAt": now,
                    "averageSeverity": new_avg_sev,
                    "confidenceScore": conf_score,
                    "isActive": True,
                }}
            )
        else:
            await db["hotspots"].insert_one({
                "location": {"type": "Point", "coordinates": [longitude, latitude]},
                "totalReports": 1,
                "recentReports": 1,
                "primaryReason": reason,
                "averageSeverity": severity or 3,
                "confidenceScore": 0.1,
                "isActive": True,
                "lastReportedAt": now,
                "createdAt": now,
                "updatedAt": now,
            })

    async def _award_user_points(self, device_id: str, points: int):
        db = get_db()
        if db is None:
            return
            
        try:
            now = datetime.now(timezone.utc)
            user = await db["users"].find_one({"deviceId": device_id})
            if not user:
                user = {
                    "deviceId": device_id,
                    "displayName": "Anonymous Navigator",
                    "points": 0,
                    "reportsSubmitted": 0,
                    "trustScore": 0.5,
                    "badges": [],
                    "createdAt": now,
                }
                
            pts = user.get("points", 0) + points
            reports_sub = user.get("reportsSubmitted", 0) + 1
            trust_score = min(1.0, 0.5 + (reports_sub * 0.02))
            
            badges = user.get("badges", [])
            badge_thresholds = [
                (5, "First Responder"),
                (25, "Road Guardian"),
                (50, "Navigation Expert"),
                (100, "CrowdNav Legend"),
            ]
            
            existing_badge_names = {b.get("name") for b in badges if isinstance(b, dict)}
            for threshold, name in badge_thresholds:
                if reports_sub >= threshold and name not in existing_badge_names:
                    badges.append({"name": name, "earnedAt": now})
                    
            await db["users"].update_one(
                {"deviceId": device_id},
                {"$set": {
                    "points": pts,
                    "reportsSubmitted": reports_sub,
                    "trustScore": trust_score,
                    "badges": badges,
                    "lastActive": now,
                    "updatedAt": now,
                }},
                upsert=True
            )
        except Exception as e:
            logger.error(f"Points award error: {e}")

report_service = ReportService()
