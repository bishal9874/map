from fastapi import APIRouter, HTTPException, Query, Request
from models import ReportCreate, SmartRouteRequest, RouteReportsRequest, UserRegister
from services.route_service import route_service
from services.report_service import report_service
from services.ai_service import ai_service
from database import get_db

router = APIRouter(prefix="/api")

# ============ ROUTING ENDPOINTS ============

@router.get("/route")
async def get_route(fromLat: float = Query(...), fromLon: float = Query(...), toLat: float = Query(...), toLon: float = Query(...)):
    try:
        route = await route_service.get_route(fromLon, fromLat, toLon, toLat)
        return {"success": True, "route": route}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/route/smart")
async def get_smart_route(body: SmartRouteRequest):
    try:
        direct_route = await route_service.get_route(body.fromLon, body.fromLat, body.toLon, body.toLat)
        coords = direct_route.get("geometry", {}).get("coordinates", [])
        recommendations = await ai_service.get_route_recommendations(coords)

        if recommendations.get("shouldReroute") and len(recommendations.get("avoidAreas", [])) > 0:
            smart_route = await route_service.get_route_avoiding_areas(
                body.fromLon, body.fromLat, body.toLon, body.toLat, recommendations["avoidAreas"]
            )
            return {
                "success": True,
                "route": smart_route,
                "warnings": recommendations.get("warnings", []),
                "avoidedAreas": len(recommendations.get("avoidAreas", [])),
                "originalRoute": direct_route,
            }
        else:
            return {
                "success": True,
                "route": direct_route,
                "warnings": recommendations.get("warnings", []),
                "avoidedAreas": 0,
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/geocode")
async def geocode(q: str = Query(...)):
    try:
        results = await route_service.geocode(q)
        return {"success": True, "results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reverse-geocode")
async def reverse_geocode(lat: float = Query(...), lon: float = Query(...)):
    try:
        result = await route_service.reverse_geocode(lat, lon)
        return {"success": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============ REPORT ENDPOINTS ============

@router.post("/reports")
async def submit_report(body: ReportCreate, request: Request):
    try:
        result = await report_service.submit_report(
            user_id=body.userId,
            latitude=body.latitude,
            longitude=body.longitude,
            reason=body.reason,
            reason_text=body.reasonText,
            severity=body.severity,
        )

        sio = getattr(request.app.state, "sio", None)
        if sio:
            await sio.emit("new_report", {
                "report": result.get("report"),
                "isCorroboration": result.get("isCorroboration"),
            })

        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/reports/nearby")
async def get_nearby_reports(lat: float = Query(...), lon: float = Query(...), radius: int = Query(2000)):
    try:
        reports = await report_service.get_nearby_reports(lat, lon, radius)
        return {"success": True, "reports": reports}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/reports/route")
async def get_route_reports(body: RouteReportsRequest):
    try:
        reports = await report_service.get_route_reports(body.coordinates)
        return {"success": True, "reports": reports}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============ CROWD INTELLIGENCE ENDPOINTS ============

@router.get("/hotspots")
async def get_hotspots(lat: float = Query(...), lon: float = Query(...), radius: int = Query(5000)):
    try:
        hotspots = await report_service.get_hotspots(lat, lon, radius)
        return {"success": True, "hotspots": hotspots}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/intelligence")
async def get_intelligence(lat: float = Query(...), lon: float = Query(...), radius: int = Query(5000)):
    try:
        data = await report_service.get_aggregated_data(lat, lon, radius)
        return {"success": True, "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============ AI ENDPOINTS ============

@router.get("/predictions")
async def get_predictions(lat: float = Query(...), lon: float = Query(...), hour: int = Query(None)):
    try:
        predictions = await ai_service.predict_issues(lat, lon, hour)
        return {"success": True, "predictions": predictions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/alerts")
async def get_alerts(lat: float = Query(...), lon: float = Query(...)):
    try:
        reports = await report_service.get_nearby_reports(lat, lon, 500)
        alerts = []
        for r in reports:
            if r.get("confidenceScore", 0) >= 0.3:
                reason = r.get("reason", "other")
                alerts.append({
                    "id": r.get("reportId"),
                    "type": reason,
                    "location": r.get("location", {}).get("coordinates", []),
                    "message": _get_alert_message(reason),
                    "severity": r.get("severity", 3),
                    "confidence": r.get("confidenceScore", 0.5),
                    "reportedAt": r.get("createdAt"),
                })
        return {"success": True, "alerts": alerts}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def _get_alert_message(reason: str) -> str:
    messages = {
        "road_blocked": "🚧 Road blocked ahead",
        "traffic": "🚗 Heavy traffic reported",
        "accident": "⚠️ Accident reported ahead",
        "personal_preference": "📍 Route change reported",
        "other": "⚠️ Issue reported ahead",
    }
    return messages.get(reason, "⚠️ Caution ahead")

# ============ USER ENDPOINTS ============

@router.post("/users/register")
async def register_user(body: UserRegister):
    try:
        db = get_db()
        if db is not None:
            user = await db["users"].find_one({"deviceId": body.deviceId})
            if not user:
                user_doc = {
                    "deviceId": body.deviceId,
                    "displayName": body.displayName or "Anonymous Navigator",
                    "points": 0,
                    "reportsSubmitted": 0,
                    "trustScore": 0.5,
                    "badges": [],
                }
                res = await db["users"].insert_one(user_doc)
                user_doc["_id"] = str(res.inserted_id)
                user = user_doc
            else:
                user["_id"] = str(user["_id"])
        else:
            user = {
                "deviceId": body.deviceId,
                "displayName": body.displayName or "Anonymous Navigator",
                "points": 0,
                "reportsSubmitted": 0,
                "trustScore": 0.5,
                "badges": [],
            }
        return {"success": True, "user": user}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/users/{device_id}")
async def get_user(device_id: str):
    try:
        db = get_db()
        if db is not None:
            user = await db["users"].find_one({"deviceId": device_id})
            if not user:
                raise HTTPException(status_code=404, detail="User not found")
            user["_id"] = str(user["_id"])
            return {"success": True, "user": user}
        else:
            return {"success": True, "user": {"deviceId": device_id, "displayName": "Anonymous Navigator", "points": 0}}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
