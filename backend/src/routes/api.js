const express = require('express');
const router = express.Router();
const routeService = require('../services/routeService');
const reportService = require('../services/reportService');
const aiService = require('../services/aiService');

// ============ ROUTING ENDPOINTS ============

/**
 * GET /api/route
 * Generate a route between two points
 */
router.get('/route', async (req, res) => {
  try {
    const { fromLat, fromLon, toLat, toLon } = req.query;
    
    if (!fromLat || !fromLon || !toLat || !toLon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const route = await routeService.getRoute(
      parseFloat(fromLon), parseFloat(fromLat),
      parseFloat(toLon), parseFloat(toLat)
    );
    
    res.json({ success: true, route });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/route/smart
 * Generate a smart route avoiding problem areas
 */
router.post('/route/smart', async (req, res) => {
  try {
    const { fromLat, fromLon, toLat, toLon } = req.body;
    
    if (!fromLat || !fromLon || !toLat || !toLon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    // Get current reports/hotspots along the direct route
    const directRoute = await routeService.getRoute(
      parseFloat(fromLon), parseFloat(fromLat),
      parseFloat(toLon), parseFloat(toLat)
    );
    
    // Check for issues along the route
    const recommendations = await aiService.getRouteRecommendations(
      directRoute.geometry.coordinates
    );
    
    if (recommendations.shouldReroute && recommendations.avoidAreas.length > 0) {
      // Get an alternative route avoiding problem areas
      const smartRoute = await routeService.getRouteAvoidingAreas(
        parseFloat(fromLon), parseFloat(fromLat),
        parseFloat(toLon), parseFloat(toLat),
        recommendations.avoidAreas
      );
      
      res.json({
        success: true,
        route: smartRoute,
        warnings: recommendations.warnings,
        avoidedAreas: recommendations.avoidAreas.length,
        originalRoute: directRoute,
      });
    } else {
      res.json({
        success: true,
        route: directRoute,
        warnings: recommendations.warnings,
        avoidedAreas: 0,
      });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/geocode
 * Search for places
 */
router.get('/geocode', async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.status(400).json({ error: 'Missing query' });
    
    const results = await routeService.geocode(q);
    res.json({ success: true, results });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/reverse-geocode
 */
router.get('/reverse-geocode', async (req, res) => {
  try {
    const { lat, lon } = req.query;
    if (!lat || !lon) return res.status(400).json({ error: 'Missing coordinates' });
    
    const result = await routeService.reverseGeocode(parseFloat(lat), parseFloat(lon));
    res.json({ success: true, result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ REPORT ENDPOINTS ============

/**
 * POST /api/reports
 * Submit a new diversion report
 */
router.post('/reports', async (req, res) => {
  try {
    const { userId, latitude, longitude, reason, reasonText, severity } = req.body;
    
    if (!latitude || !longitude || !reason) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const result = await reportService.submitReport({
      userId,
      latitude: parseFloat(latitude),
      longitude: parseFloat(longitude),
      reason,
      reasonText,
      severity: parseInt(severity) || 3,
    });
    
    // Emit to connected clients via socket
    if (req.app.get('io')) {
      req.app.get('io').emit('new_report', {
        report: result.report,
        isCorroboration: result.isCorroboration,
      });
    }
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/reports/nearby
 * Get reports near a location
 */
router.get('/reports/nearby', async (req, res) => {
  try {
    const { lat, lon, radius } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const reports = await reportService.getNearbyReports(
      parseFloat(lat), parseFloat(lon), parseInt(radius) || 2000
    );
    
    res.json({ success: true, reports });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/reports/route
 * Get reports along a route
 */
router.post('/reports/route', async (req, res) => {
  try {
    const { coordinates } = req.body;
    
    if (!coordinates || !Array.isArray(coordinates)) {
      return res.status(400).json({ error: 'Missing route coordinates' });
    }
    
    const reports = await reportService.getRouteReports(coordinates);
    res.json({ success: true, reports });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ CROWD INTELLIGENCE ENDPOINTS ============

/**
 * GET /api/hotspots
 * Get problem area hotspots
 */
router.get('/hotspots', async (req, res) => {
  try {
    const { lat, lon, radius } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const hotspots = await reportService.getHotspots(
      parseFloat(lat), parseFloat(lon), parseInt(radius) || 5000
    );
    
    res.json({ success: true, hotspots });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/intelligence
 * Get aggregated crowd intelligence data
 */
router.get('/intelligence', async (req, res) => {
  try {
    const { lat, lon, radius } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const data = await reportService.getAggregatedData(
      parseFloat(lat), parseFloat(lon), parseInt(radius) || 5000
    );
    
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============ AI ENDPOINTS ============

/**
 * GET /api/predictions
 * Get AI predictions for road issues
 */
router.get('/predictions', async (req, res) => {
  try {
    const { lat, lon, hour } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const predictions = await aiService.predictIssues(
      parseFloat(lat), parseFloat(lon), parseInt(hour)
    );
    
    res.json({ success: true, predictions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/alerts
 * Get real-time alerts for a location
 */
router.get('/alerts', async (req, res) => {
  try {
    const { lat, lon } = req.query;
    
    if (!lat || !lon) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }
    
    const reports = await reportService.getNearbyReports(
      parseFloat(lat), parseFloat(lon), 500
    );
    
    const alerts = reports
      .filter(r => r.confidenceScore >= 0.3)
      .map(r => ({
        id: r.reportId,
        type: r.reason,
        location: r.location.coordinates,
        message: _getAlertMessage(r.reason),
        severity: r.severity,
        confidence: r.confidenceScore,
        reportedAt: r.createdAt,
      }));
    
    res.json({ success: true, alerts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

function _getAlertMessage(reason) {
  const messages = {
    'road_blocked': '🚧 Road blocked ahead',
    'traffic': '🚗 Heavy traffic reported',
    'accident': '⚠️ Accident reported ahead',
    'personal_preference': '📍 Route change reported',
    'other': '⚠️ Issue reported ahead',
  };
  return messages[reason] || '⚠️ Caution ahead';
}

// ============ USER ENDPOINTS ============

/**
 * POST /api/users/register
 */
router.post('/users/register', async (req, res) => {
  try {
    const { deviceId, displayName } = req.body;
    const User = require('../models/User');
    
    let user = await User.findOne({ deviceId });
    if (!user) {
      user = await User.create({ deviceId, displayName });
    }
    
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/users/:deviceId
 */
router.get('/users/:deviceId', async (req, res) => {
  try {
    const User = require('../models/User');
    const user = await User.findOne({ deviceId: req.params.deviceId });
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
