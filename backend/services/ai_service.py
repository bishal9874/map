import logging
from datetime import datetime, timezone
from services.report_service import report_service

logger = logging.getLogger("crowdnav.ai")

class AIService:
    async def predict_issues(self, latitude: float, longitude: float, time_of_day: int = None):
        try:
            hotspots = await report_service.get_hotspots(latitude, longitude, radius_meters=5000)
            predictions = []
            now = datetime.now(timezone.utc)
            current_hour = time_of_day if time_of_day is not None else now.hour

            for hotspot in hotspots[:20]:
                last_reported = hotspot.get("lastReportedAt")
                if isinstance(last_reported, datetime):
                    if last_reported.tzinfo is None:
                        last_reported = last_reported.replace(tzinfo=timezone.utc)
                    hours_since = max(0.1, (now - last_reported).total_seconds() / 3600.0)
                else:
                    hours_since = 24.0

                total_reports = hotspot.get("totalReports", 1)
                report_freq = total_reports / max(1.0, hours_since / 24.0)

                is_peak_hour = (7 <= current_hour <= 10) or (16 <= current_hour <= 20)
                base_prob = min(0.95, report_freq * 0.1)
                time_mult = 1.5 if is_peak_hour else 0.8

                if hours_since < 2:
                    recency_mult = 1.8
                elif hours_since < 6:
                    recency_mult = 1.3
                elif hours_since < 24:
                    recency_mult = 1.0
                else:
                    recency_mult = 0.5

                prob = min(0.95, base_prob * time_mult * recency_mult)
                prob_rounded = round(prob, 2)

                if prob_rounded > 0.6:
                    risk_level = "high_risk"
                elif prob_rounded > 0.3:
                    risk_level = "moderate_risk"
                else:
                    risk_level = "low_risk"

                predictions.append({
                    "location": hotspot.get("location"),
                    "reason": hotspot.get("primaryReason", "other"),
                    "probability": prob_rounded,
                    "severity": hotspot.get("averageSeverity", 3),
                    "totalReports": total_reports,
                    "lastReported": last_reported,
                    "prediction": risk_level,
                })

            predictions.sort(key=lambda x: x["probability"], reverse=True)
            return predictions
        except Exception as e:
            logger.error(f"AI prediction error: {e}")
            return []

    async def filter_report(self, report: dict, user_trust_score: float = 0.5):
        quality_score = user_trust_score * 30 + 20  # Base location plausibility

        location = report.get("location", {})
        coords = location.get("coordinates", [0, 0])
        nearby_reports = await report_service.get_nearby_reports(coords[1], coords[0], radius_meters=200)

        r_reason = report.get("reason")
        r_id = report.get("reportId")
        corroborating = [
            r for r in nearby_reports 
            if r.get("reason") == r_reason and r.get("reportId") != r_id
        ]
        quality_score += min(30, len(corroborating) * 10)

        created_at = report.get("createdAt")
        if isinstance(created_at, datetime):
            report_hour = created_at.hour
        else:
            report_hour = datetime.now(timezone.utc).hour

        time_consistent = 5 <= report_hour <= 23
        if time_consistent:
            quality_score += 10

        reason_text = report.get("reasonText", "")
        if r_reason != "other" or (reason_text and len(reason_text) > 10):
            quality_score += 10

        final_score = min(100.0, quality_score)
        return {
            "qualityScore": final_score,
            "isReliable": final_score >= 40,
            "factors": {
                "userTrust": user_trust_score,
                "corroborations": len(corroborating),
                "timeConsistency": time_consistent,
            },
        }

    async def get_route_recommendations(self, route_coordinates: list):
        avoid_areas = []
        warnings = []
        if not route_coordinates:
            return {"avoidAreas": avoid_areas, "warnings": warnings, "shouldReroute": False}

        step = max(1, len(route_coordinates) // 30)
        for i in range(0, len(route_coordinates), step):
            coord = route_coordinates[i]
            preds = await self.predict_issues(coord[1], coord[0])

            for pred in preds:
                if pred["probability"] > 0.5:
                    loc = pred.get("location", {})
                    coords = loc.get("coordinates", [0, 0])
                    reason = pred.get("reason", "other")
                    prob = pred.get("probability", 0)
                    sev = pred.get("severity", 3)

                    avoid_areas.append({
                        "coordinates": coords,
                        "reason": reason,
                        "probability": prob,
                        "severity": sev,
                    })

                    warnings.append({
                        "location": coords,
                        "message": self._generate_warning_message(reason, prob),
                        "severity": sev,
                        "distanceAlongRoute": i / float(len(route_coordinates)),
                    })

        should_reroute = any(a["probability"] > 0.7 and a["severity"] >= 4 for a in avoid_areas)
        return {
            "avoidAreas": avoid_areas,
            "warnings": warnings,
            "shouldReroute": should_reroute,
        }

    def _generate_warning_message(self, reason: str, probability: float) -> str:
        intensity_map = {
            "road_blocked": "Road likely blocked ahead" if probability > 0.7 else "Possible road blockage ahead",
            "traffic": "Heavy traffic expected ahead" if probability > 0.7 else "Moderate traffic reported ahead",
            "accident": "Accident reported ahead" if probability > 0.7 else "Possible accident zone ahead",
            "other": "Road issue reported ahead",
        }
        return intensity_map.get(reason, "Caution: issue reported ahead")

ai_service = AIService()
