import logging
from motor.motor_asyncio import AsyncIOMotorClient
from config import MONGODB_URI, DB_NAME

logger = logging.getLogger("crowdnav")

class Database:
    client: AsyncIOMotorClient = None
    db = None

db_instance = Database()

async def init_db():
    try:
        db_instance.client = AsyncIOMotorClient(MONGODB_URI, serverSelectionTimeoutMS=3000)
        db_instance.db = db_instance.client[DB_NAME]
        
        # Ping server to verify connection
        await db_instance.client.admin.command('ping')
        logger.info("✅ Connected to MongoDB")
        
        # Create geospatial 2dsphere indexes
        await db_instance.db["reports"].create_index([("location", "2dsphere")])
        await db_instance.db["reports"].create_index([("reportId", 1)], unique=True)
        await db_instance.db["reports"].create_index([("isActive", 1)])
        
        await db_instance.db["hotspots"].create_index([("location", "2dsphere")])
        await db_instance.db["hotspots"].create_index([("isActive", 1), ("confidenceScore", -1)])
        
        await db_instance.db["users"].create_index([("deviceId", 1)], unique=True)
        
        logger.info("✅ Indexes initialized successfully")
    except Exception as e:
        logger.warning(f"⚠️ MongoDB connection failed: {e}. Running in limited DB mode.")
        db_instance.db = None

def get_db():
    return db_instance.db
