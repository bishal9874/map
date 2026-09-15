import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import socketio
import uvicorn

from config import PORT, CORS_ORIGINS
from database import init_db
from routes.api import router as api_router
from services.report_service import report_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("crowdnav.main")

sio = socketio.AsyncServer(async_mode="asgi", cors_allowed_origins="*")

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting CrowdNav Python Backend...")
    await init_db()
    yield
    logger.info("CrowdNav Python Backend shut down.")

fastapi_app = FastAPI(
    title="CrowdNav Backend (Python)",
    version="1.0.0",
    description="Crowd-powered navigation backend written in Python with FastAPI, Motor, and SocketIO.",
    lifespan=lifespan,
)

# CORS middleware
fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store sio instance on app state for access in route handlers
fastapi_app.state.sio = sio

# Include REST routes
fastapi_app.include_router(api_router)

@fastapi_app.get("/health")
async def health_check():
    from database import get_db
    db = get_db()
    return {
        "status": "ok",
        "mongodb": "connected" if db is not None else "disconnected",
    }

# Socket.IO Event Handlers
@sio.event
async def connect(sid, environ):
    logger.info(f"Client connected: {sid}")

@sio.event
async def disconnect(sid):
    logger.info(f"Client disconnected: {sid}")

@sio.event
async def location_update(sid, data):
    if not isinstance(data, dict):
        return
        
    lat = data.get("latitude")
    lon = data.get("longitude")
    
    if lat is None or lon is None:
        return

    try:
        nearby_reports = await report_service.get_nearby_reports(float(lat), float(lon), radius_meters=500)
        alerts = []
        for r in nearby_reports:
            if r.get("confidenceScore", 0) >= 0.3:
                alerts.append({
                    "id": r.get("reportId"),
                    "type": r.get("reason"),
                    "location": r.get("location", {}).get("coordinates", []),
                    "severity": r.get("severity", 3),
                    "confidence": r.get("confidenceScore", 0.5),
                })
                
        if len(alerts) > 0:
            await sio.emit("nearby_alerts", {"alerts": alerts}, to=sid)
    except Exception as e:
        logger.error(f"Socket location_update error: {e}")

# Combine FastAPI and Socket.IO into single ASGI application
app = socketio.ASGIApp(sio, other_asgi_app=fastapi_app)

if __name__ == "__main__":
    logger.info(f"🚀 Running CrowdNav Python Backend on port {PORT}...")
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)
