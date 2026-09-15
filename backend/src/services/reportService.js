const Report = require('../models/Report');
const Hotspot = require('../models/Hotspot');
const User = require('../models/User');
const { v4: uuidv4 } = require('uuid');

class ReportService {
  /**
   * Submit a new diversion report
   */
  async submitReport({ userId, latitude, longitude, reason, reasonText, severity }) {
    try {
      // Check for existing nearby reports (within 100m)
      const nearbyReports = await Report.findNearby(longitude, latitude, 100);
      
      // If there's a recent similar report, corroborate instead of creating new
      const similarReport = nearbyReports.find(r => 
        r.reason === reason && 
        (Date.now() - r.createdAt.getTime()) < 60 * 60 * 1000 // within 1 hour
      );
      
      if (similarReport) {
        return this._corroborateReport(similarReport, userId);
      }
      
      // Create new report
      const report = new Report({
        reportId: uuidv4(),
        userId: userId || 'anonymous',
        location: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        reason,
        reasonText: reasonText || '',
        severity: severity || 3,
        confidenceScore: 0.3, // starts low, increases with corroborations
      });
      
      await report.save();
      
      // Update or create hotspot
      await this._updateHotspot(longitude, latitude, reason, severity);
      
      // Award points to user
      if (userId && userId !== 'anonymous') {
        await this._awardUserPoints(userId, 10);
      }
      
      return {
        success: true,
        report: report,
        isCorroboration: false,
      };
    } catch (error) {
      console.error('Report submission error:', error);
      throw error;
    }
  }
  
  /**
   * Get active reports near a location
   */
  async getNearbyReports(latitude, longitude, radiusMeters = 2000) {
    try {
      const reports = await Report.findNearby(longitude, latitude, radiusMeters);
      return reports.filter(r => r.isActive);
    } catch (error) {
      console.error('Nearby reports error:', error);
      throw error;
    }
  }
  
  /**
   * Get reports along a route
   */
  async getRouteReports(routeCoordinates) {
    try {
      // Sample points along the route to check for reports
      const reports = [];
      const step = Math.max(1, Math.floor(routeCoordinates.length / 20));
      
      for (let i = 0; i < routeCoordinates.length; i += step) {
        const coord = routeCoordinates[i];
        const nearby = await Report.findNearby(coord[0], coord[1], 300);
        
        for (const report of nearby) {
          if (!reports.find(r => r.reportId === report.reportId)) {
            reports.push(report);
          }
        }
      }
      
      return reports;
    } catch (error) {
      console.error('Route reports error:', error);
      throw error;
    }
  }
  
  /**
   * Get all active hotspots
   */
  async getHotspots(latitude, longitude, radiusMeters = 5000) {
    try {
      const hotspots = await Hotspot.find({
        isActive: true,
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [longitude, latitude],
            },
            $maxDistance: radiusMeters,
          },
        },
      }).sort({ confidenceScore: -1 }).limit(50);
      
      return hotspots;
    } catch (error) {
      console.error('Hotspots fetch error:', error);
      throw error;
    }
  }
  
  /**
   * Aggregate reports for crowd intelligence
   */
  async getAggregatedData(latitude, longitude, radiusMeters = 5000) {
    try {
      const reports = await this.getNearbyReports(latitude, longitude, radiusMeters);
      
      // Group by reason
      const reasonCounts = {};
      const locationClusters = {};
      
      for (const report of reports) {
        // Count reasons
        reasonCounts[report.reason] = (reasonCounts[report.reason] || 0) + 1;
        
        // Cluster locations (grid-based, ~100m cells)
        const gridKey = `${Math.round(report.location.coordinates[0] * 1000) / 1000},${Math.round(report.location.coordinates[1] * 1000) / 1000}`;
        
        if (!locationClusters[gridKey]) {
          locationClusters[gridKey] = {
            coordinates: report.location.coordinates,
            count: 0,
            reasons: {},
            avgSeverity: 0,
          };
        }
        
        locationClusters[gridKey].count++;
        locationClusters[gridKey].reasons[report.reason] = 
          (locationClusters[gridKey].reasons[report.reason] || 0) + 1;
        locationClusters[gridKey].avgSeverity = 
          (locationClusters[gridKey].avgSeverity * (locationClusters[gridKey].count - 1) + report.severity) / locationClusters[gridKey].count;
      }
      
      // Calculate confidence scores for clusters
      const clusters = Object.values(locationClusters).map(cluster => ({
        ...cluster,
        confidenceScore: Math.min(1.0, cluster.count * 0.15),
        primaryReason: Object.entries(cluster.reasons)
          .sort((a, b) => b[1] - a[1])[0]?.[0] || 'unknown',
      }));
      
      return {
        totalReports: reports.length,
        reasonBreakdown: reasonCounts,
        problemAreas: clusters.filter(c => c.count >= 2).sort((a, b) => b.confidenceScore - a.confidenceScore),
        allClusters: clusters,
      };
    } catch (error) {
      console.error('Aggregation error:', error);
      throw error;
    }
  }
  
  async _corroborateReport(existingReport, userId) {
    existingReport.corroborations += 1;
    existingReport.confidenceScore = Math.min(1.0, existingReport.corroborations * 0.15);
    
    // Extend expiration with more corroborations
    existingReport.expiresAt = new Date(Date.now() + existingReport.corroborations * 60 * 60 * 1000);
    
    await existingReport.save();
    
    if (userId && userId !== 'anonymous') {
      await this._awardUserPoints(userId, 5);
    }
    
    return {
      success: true,
      report: existingReport,
      isCorroboration: true,
    };
  }
  
  async _updateHotspot(longitude, latitude, reason, severity) {
    const nearbyHotspot = await Hotspot.findOne({
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude],
          },
          $maxDistance: 200,
        },
      },
    });
    
    if (nearbyHotspot) {
      nearbyHotspot.totalReports += 1;
      nearbyHotspot.recentReports += 1;
      nearbyHotspot.lastReportedAt = new Date();
      nearbyHotspot.averageSeverity = 
        (nearbyHotspot.averageSeverity * (nearbyHotspot.totalReports - 1) + severity) / nearbyHotspot.totalReports;
      nearbyHotspot.confidenceScore = Math.min(1.0, nearbyHotspot.totalReports * 0.1);
      nearbyHotspot.isActive = true;
      await nearbyHotspot.save();
    } else {
      await Hotspot.create({
        location: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        totalReports: 1,
        recentReports: 1,
        primaryReason: reason,
        averageSeverity: severity || 3,
        confidenceScore: 0.1,
        lastReportedAt: new Date(),
      });
    }
  }
  
  async _awardUserPoints(deviceId, points) {
    try {
      let user = await User.findOne({ deviceId });
      if (!user) {
        user = new User({ deviceId });
      }
      await user.addPoints(points);
    } catch (error) {
      console.error('Points award error:', error);
    }
  }
}

module.exports = new ReportService();
