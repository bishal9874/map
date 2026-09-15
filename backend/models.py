from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field
from datetime import datetime

class LocationPoint(BaseModel):
    type: str = "Point"
    coordinates: List[float]  # [longitude, latitude]

class ReportCreate(BaseModel):
    userId: Optional[str] = "anonymous"
    latitude: float
    longitude: float
    reason: str
    reasonText: Optional[str] = ""
    severity: Optional[int] = 3

class ReportResponse(BaseModel):
    reportId: str
    userId: str
    location: Dict[str, Any]
    reason: str
    reasonText: str
    severity: int
    confidenceScore: float
    corroborations: int
    isActive: bool
    expiresAt: datetime
    createdAt: datetime

class SmartRouteRequest(BaseModel):
    fromLat: float
    fromLon: float
    toLat: float
    toLon: float

class RouteReportsRequest(BaseModel):
    coordinates: List[List[float]]

class UserRegister(BaseModel):
    deviceId: str
    displayName: Optional[str] = "Anonymous Navigator"
