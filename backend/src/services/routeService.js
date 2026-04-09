const fetch = require('node-fetch');

const OSRM_API = process.env.OSRM_API_URL || 'https://router.project-osrm.org';
const NOMINATIM_API = process.env.NOMINATIM_API_URL || 'https://nominatim.openstreetmap.org';

class RouteService {
  /**
   * Get a route between two points using OSRM
   * @param {number} fromLon - Start longitude
   * @param {number} fromLat - Start latitude
   * @param {number} toLon - End longitude
   * @param {number} toLat - End latitude
   * @param {Array} avoidPoints - Array of [lon, lat] points to avoid
   * @returns {Object} Route data with geometry, duration, distance
   */
  async getRoute(fromLon, fromLat, toLon, toLat, avoidPoints = []) {
    try {
      // Build waypoints string
      let coordinates = `${fromLon},${fromLat};${toLon},${toLat}`;
      
      const url = `${OSRM_API}/route/v1/driving/${coordinates}?overview=full&geometries=geojson&steps=true&alternatives=true`;
      
      const response = await fetch(url, {
        headers: {
          'User-Agent': 'CrowdNav/1.0',
        },
      });
      
      if (!response.ok) {
        throw new Error(`OSRM API error: ${response.status}`);
      }
      
      const data = await response.json();
      
      if (data.code !== 'Ok' || !data.routes || data.routes.length === 0) {
        throw new Error('No route found');
      }
      
      // If we have avoid points, try to filter or re-route
      let bestRoute = data.routes[0];
      
      if (avoidPoints.length > 0 && data.routes.length > 1) {
        // Score each route by how far it stays from avoid points
        bestRoute = this._selectBestRoute(data.routes, avoidPoints);
      }
      
      return {
        geometry: bestRoute.geometry,
        duration: bestRoute.duration,
        distance: bestRoute.distance,
        steps: bestRoute.legs[0]?.steps || [],
        alternatives: data.routes.slice(1).map(r => ({
          geometry: r.geometry,
          duration: r.duration,
          distance: r.distance,
        })),
      };
    } catch (error) {
      console.error('Route generation error:', error);
      throw error;
    }
  }
  
  /**
   * Get route with intermediate waypoints to avoid problem areas
   */
  async getRouteAvoidingAreas(fromLon, fromLat, toLon, toLat, avoidAreas) {
    try {
      // Generate waypoints that route around avoid areas
      const waypoints = this._generateAvoidanceWaypoints(
        fromLon, fromLat, toLon, toLat, avoidAreas
      );
      
      let coordStr = `${fromLon},${fromLat}`;
      for (const wp of waypoints) {
        coordStr += `;${wp[0]},${wp[1]}`;
      }
      coordStr += `;${toLon},${toLat}`;
      
      const url = `${OSRM_API}/route/v1/driving/${coordStr}?overview=full&geometries=geojson&steps=true`;
      
      const response = await fetch(url, {
        headers: { 'User-Agent': 'CrowdNav/1.0' },
      });
      
      const data = await response.json();
      
      if (data.code !== 'Ok' || !data.routes?.length) {
        // Fallback to direct route
        return this.getRoute(fromLon, fromLat, toLon, toLat);
      }
      
      return {
        geometry: data.routes[0].geometry,
        duration: data.routes[0].duration,
        distance: data.routes[0].distance,
        steps: data.routes[0].legs?.flatMap(l => l.steps) || [],
        avoidedAreas: avoidAreas.length,
      };
    } catch (error) {
      console.error('Avoidance routing error:', error);
      return this.getRoute(fromLon, fromLat, toLon, toLat);
    }
  }
  
  /**
   * Geocode a place name to coordinates
   */
  async geocode(query) {
    try {
      const url = `${NOMINATIM_API}/search?q=${encodeURIComponent(query)}&format=json&limit=5&addressdetails=1`;
      
      const response = await fetch(url, {
        headers: { 'User-Agent': 'CrowdNav/1.0' },
      });
      
      const data = await response.json();
      
      return data.map(item => ({
        displayName: item.display_name,
        latitude: parseFloat(item.lat),
        longitude: parseFloat(item.lon),
        type: item.type,
        address: item.address,
      }));
    } catch (error) {
      console.error('Geocoding error:', error);
      throw error;
    }
  }
  
  /**
   * Reverse geocode coordinates to an address
   */
  async reverseGeocode(latitude, longitude) {
    try {
      const url = `${NOMINATIM_API}/reverse?lat=${latitude}&lon=${longitude}&format=json`;
      
      const response = await fetch(url, {
        headers: { 'User-Agent': 'CrowdNav/1.0' },
      });
      
      const data = await response.json();
      
      return {
        displayName: data.display_name,
        address: data.address,
      };
    } catch (error) {
      console.error('Reverse geocoding error:', error);
      throw error;
    }
  }
  
  _selectBestRoute(routes, avoidPoints) {
    let bestRoute = routes[0];
    let bestScore = -Infinity;
    
    for (const route of routes) {
      let minDist = Infinity;
      const coords = route.geometry.coordinates;
      
      for (const avoid of avoidPoints) {
        for (const coord of coords) {
          const dist = this._haversineDistance(coord[1], coord[0], avoid[1], avoid[0]);
          minDist = Math.min(minDist, dist);
        }
      }
      
      // Score = distance from problems - route duration penalty
      const score = minDist - (route.duration / 60);
      
      if (score > bestScore) {
        bestScore = score;
        bestRoute = route;
      }
    }
    
    return bestRoute;
  }
  
  _generateAvoidanceWaypoints(fromLon, fromLat, toLon, toLat, avoidAreas) {
    const waypoints = [];
    const offsetDeg = 0.003; // ~300m offset
    
    for (const area of avoidAreas) {
      const aLon = area.coordinates[0];
      const aLat = area.coordinates[1];
      
      // Check if this area is roughly between start and end
      const minLon = Math.min(fromLon, toLon) - 0.01;
      const maxLon = Math.max(fromLon, toLon) + 0.01;
      const minLat = Math.min(fromLat, toLat) - 0.01;
      const maxLat = Math.max(fromLat, toLat) + 0.01;
      
      if (aLon >= minLon && aLon <= maxLon && aLat >= minLat && aLat <= maxLat) {
        // Add a waypoint that bypasses the problem area
        const bearing = Math.atan2(toLat - fromLat, toLon - fromLon);
        const perpBearing = bearing + Math.PI / 2;
        
        waypoints.push([
          aLon + offsetDeg * Math.cos(perpBearing),
          aLat + offsetDeg * Math.sin(perpBearing),
        ]);
      }
    }
    
    return waypoints;
  }
  
  _haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371000;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}

module.exports = new RouteService();
