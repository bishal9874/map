const Report = require('../models/Report');
const Hotspot = require('../models/Hotspot');

class AIService {
  /**
   * Predict potential road issues based on historical patterns
   */
  async predictIssues(latitude, longitude, timeOfDay) {
    try {
      const hotspots = await Hotspot.find({
        location: {
          $near: {
            $geometry: {
              type: 'Point',
              coordinates: [longitude, latitude],
            },
            $maxDistance: 5000,
          },
        },
      }).limit(20);
      
      const predictions = hotspots.map(hotspot => {
        // Simple prediction based on historical frequency
        const hoursSinceLastReport = (Date.now() - hotspot.lastReportedAt.getTime()) / (1000 * 60 * 60);
        const reportFrequency = hotspot.totalReports / Math.max(1, hoursSinceLastReport / 24);
        
        // Time-based pattern analysis
        const currentHour = timeOfDay || new Date().getHours();
        const isPeakHour = (currentHour >= 7 && currentHour <= 10) || (currentHour >= 16 && currentHour <= 20);
        
        const baseProbability = Math.min(0.95, reportFrequency * 0.1);
        const timeMultiplier = isPeakHour ? 1.5 : 0.8;
        const recencyMultiplier = hoursSinceLastReport < 2 ? 1.8 : 
                                   hoursSinceLastReport < 6 ? 1.3 : 
                                   hoursSinceLastReport < 24 ? 1.0 : 0.5;
        
        const probability = Math.min(0.95, baseProbability * timeMultiplier * recencyMultiplier);
        
        return {
          location: hotspot.location,
          reason: hotspot.primaryReason,
          probability: Math.round(probability * 100) / 100,
          severity: hotspot.averageSeverity,
          totalReports: hotspot.totalReports,
          lastReported: hotspot.lastReportedAt,
          prediction: probability > 0.6 ? 'high_risk' : 
                      probability > 0.3 ? 'moderate_risk' : 'low_risk',
        };
      });
      
      return predictions.sort((a, b) => b.probability - a.probability);
    } catch (error) {
      console.error('AI prediction error:', error);
      return [];
    }
  }
  
  /**
   * Filter potentially fake or low-quality reports
   */
  async filterReport(report, userTrustScore = 0.5) {
    // Quality scoring factors
    let qualityScore = 0;
    
    // Factor 1: User trust score
    qualityScore += userTrustScore * 30;
    
    // Factor 2: Location plausibility (is it near a road?)
    qualityScore += 20; // Assume valid for now
    
    // Factor 3: Corroboration from other users
    const nearbyReports = await Report.findNearby(
      report.location.coordinates[0],
      report.location.coordinates[1],
      200
    );
    const corroboratingReports = nearbyReports.filter(r => 
      r.reason === report.reason && 
      r.reportId !== report.reportId
    );
    qualityScore += Math.min(30, corroboratingReports.length * 10);
    
    // Factor 4: Time consistency (reports during normal hours)
    const reportHour = new Date(report.createdAt).getHours();
    if (reportHour >= 5 && reportHour <= 23) {
      qualityScore += 10;
    }
    
    // Factor 5: Reason specificity
    if (report.reason !== 'other' || (report.reasonText && report.reasonText.length > 10)) {
      qualityScore += 10;
    }
    
    return {
      qualityScore: Math.min(100, qualityScore),
      isReliable: qualityScore >= 40,
      factors: {
        userTrust: userTrustScore,
        corroborations: corroboratingReports.length,
        timeConsistency: reportHour >= 5 && reportHour <= 23,
      },
    };
  }
  
  /**
   * Generate smart route recommendations
   */
  async getRouteRecommendations(routeCoordinates) {
    const avoidAreas = [];
    const warnings = [];
    
    // Check each segment of the route for issues
    const step = Math.max(1, Math.floor(routeCoordinates.length / 30));
    
    for (let i = 0; i < routeCoordinates.length; i += step) {
      const coord = routeCoordinates[i];
      const predictions = await this.predictIssues(coord[1], coord[0]);
      
      for (const pred of predictions) {
        if (pred.probability > 0.5) {
          avoidAreas.push({
            coordinates: pred.location.coordinates,
            reason: pred.reason,
            probability: pred.probability,
            severity: pred.severity,
          });
          
          warnings.push({
            location: pred.location.coordinates,
            message: this._generateWarningMessage(pred.reason, pred.probability),
            severity: pred.severity,
            distanceAlongRoute: i / routeCoordinates.length,
          });
        }
      }
    }
    
    return {
      avoidAreas,
      warnings,
      shouldReroute: avoidAreas.some(a => a.probability > 0.7 && a.severity >= 4),
    };
  }
  
  _generateWarningMessage(reason, probability) {
    const intensityMap = {
      'road_blocked': probability > 0.7 ? 'Road likely blocked ahead' : 'Possible road blockage ahead',
      'traffic': probability > 0.7 ? 'Heavy traffic expected ahead' : 'Moderate traffic reported ahead',
      'accident': probability > 0.7 ? 'Accident reported ahead' : 'Possible accident zone ahead',
      'other': 'Road issue reported ahead',
    };
    return intensityMap[reason] || 'Caution: issue reported ahead';
  }
}

module.exports = new AIService();
