import math
import logging
import httpx
from config import OSRM_API_URL, NOMINATIM_API_URL

logger = logging.getLogger("crowdnav.route")

class RouteService:
    async def get_route(self, from_lon: float, from_lat: float, to_lon: float, to_lat: float, avoid_points: list = None):
        if avoid_points is None:
            avoid_points = []
            
        coordinates = f"{from_lon},{from_lat};{to_lon},{to_lat}"
        url = f"{OSRM_API_URL}/route/v1/driving/{coordinates}?overview=full&geometries=geojson&steps=true&alternatives=true"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers={"User-Agent": "CrowdNav-Python/1.0"})
            if response.status_code != 200:
                raise RuntimeError(f"OSRM API error: {response.status_code}")
            
            data = response.json()
            if data.get("code") != "Ok" or not data.get("routes"):
                raise RuntimeError("No route found")
            
            routes = data["routes"]
            best_route = routes[0]
            
            if len(avoid_points) > 0 and len(routes) > 1:
                best_route = self._select_best_route(routes, avoid_points)
                
            steps = []
            if best_route.get("legs") and len(best_route["legs"]) > 0:
                steps = best_route["legs"][0].get("steps", [])
                
            alternatives = []
            for r in routes[1:]:
                alternatives.append({
                    "geometry": r.get("geometry"),
                    "duration": r.get("duration"),
                    "distance": r.get("distance"),
                })
                
            return {
                "geometry": best_route.get("geometry"),
                "duration": best_route.get("duration"),
                "distance": best_route.get("distance"),
                "steps": steps,
                "alternatives": alternatives,
            }

    async def get_route_avoiding_areas(self, from_lon: float, from_lat: float, to_lon: float, to_lat: float, avoid_areas: list):
        try:
            waypoints = self._generate_avoidance_waypoints(from_lon, from_lat, to_lon, to_lat, avoid_areas)
            
            coord_str = f"{from_lon},{from_lat}"
            for wp in waypoints:
                coord_str += f";{wp[0]},{wp[1]}"
            coord_str += f";{to_lon},{to_lat}"
            
            url = f"{OSRM_API_URL}/route/v1/driving/{coord_str}?overview=full&geometries=geojson&steps=true"
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(url, headers={"User-Agent": "CrowdNav-Python/1.0"})
                data = response.json()
                
                if data.get("code") != "Ok" or not data.get("routes"):
                    return await self.get_route(from_lon, from_lat, to_lon, to_lat)
                
                route = data["routes"][0]
                steps = []
                if route.get("legs"):
                    for leg in route["legs"]:
                        steps.extend(leg.get("steps", []))
                        
                return {
                    "geometry": route.get("geometry"),
                    "duration": route.get("duration"),
                    "distance": route.get("distance"),
                    "steps": steps,
                    "avoidedAreas": len(avoid_areas),
                }
        except Exception as e:
            logger.error(f"Avoidance routing error: {e}")
            return await self.get_route(from_lon, from_lat, to_lon, to_lat)

    async def geocode(self, query: str):
        url = f"{NOMINATIM_API_URL}/search?q={query}&format=json&limit=5&addressdetails=1"
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers={"User-Agent": "CrowdNav-Python/1.0"})
            data = response.json()
            results = []
            for item in data:
                results.append({
                    "displayName": item.get("display_name"),
                    "latitude": float(item.get("lat", 0)),
                    "longitude": float(item.get("lon", 0)),
                    "type": item.get("type"),
                    "address": item.get("address"),
                })
            return results

    async def reverse_geocode(self, latitude: float, longitude: float):
        url = f"{NOMINATIM_API_URL}/reverse?lat={latitude}&lon={longitude}&format=json"
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers={"User-Agent": "CrowdNav-Python/1.0"})
            data = response.json()
            return {
                "displayName": data.get("display_name"),
                "address": data.get("address"),
            }

    def _select_best_route(self, routes: list, avoid_points: list):
        best_route = routes[0]
        best_score = float("-inf")
        
        for route in routes:
            min_dist = float("inf")
            coords = route.get("geometry", {}).get("coordinates", [])
            
            for avoid in avoid_points:
                for coord in coords:
                    dist = self._haversine_distance(coord[1], coord[0], avoid[1], avoid[0])
                    min_dist = min(min_dist, dist)
                    
            score = min_dist - (route.get("duration", 0) / 60.0)
            if score > best_score:
                best_score = score
                best_route = route
                
        return best_route

    def _generate_avoidance_waypoints(self, from_lon: float, from_lat: float, to_lon: float, to_lat: float, avoid_areas: list):
        waypoints = []
        offset_deg = 0.003  # ~300m offset
        
        for area in avoid_areas:
            area_coords = area.get("coordinates", [0, 0])
            a_lon, a_lat = area_coords[0], area_coords[1]
            
            min_lon = min(from_lon, to_lon) - 0.01
            max_lon = max(from_lon, to_lon) + 0.01
            min_lat = min(from_lat, to_lat) - 0.01
            max_lat = max(from_lat, to_lat) + 0.01
            
            if min_lon <= a_lon <= max_lon and min_lat <= a_lat <= max_lat:
                bearing = math.atan2(to_lat - from_lat, to_lon - from_lon)
                perp_bearing = bearing + (math.pi / 2.0)
                waypoints.append([
                    a_lon + offset_deg * math.cos(perp_bearing),
                    a_lat + offset_deg * math.sin(perp_bearing),
                ])
                
        return waypoints

    def _haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        r = 6371000  # meters
        d_lat = math.radians(lat2 - lat1)
        d_lon = math.radians(lon2 - lon1)
        a = (math.sin(d_lat / 2.0) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(d_lon / 2.0) ** 2)
        return r * 2.0 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

route_service = RouteService()
