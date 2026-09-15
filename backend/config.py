import os
from dotenv import load_dotenv

load_dotenv()

PORT = int(os.getenv("PORT", 3000))
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017/crowdnav")
DB_NAME = os.getenv("DB_NAME", "crowdnav")
OSRM_API_URL = os.getenv("OSRM_API_URL", "https://router.project-osrm.org")
NOMINATIM_API_URL = os.getenv("NOMINATIM_API_URL", "https://nominatim.openstreetmap.org")
CORS_ORIGINS = [origin.strip() for origin in os.getenv("CORS_ORIGINS", "*").split(",")]
