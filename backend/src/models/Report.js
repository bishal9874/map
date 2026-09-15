const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  reportId: {
    type: String,
    required: true,
    unique: true,
  },
  userId: {
    type: String,
    default: 'anonymous',
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
    },
  },
  reason: {
    type: String,
    enum: ['road_blocked', 'traffic', 'accident', 'personal_preference', 'other'],
    required: true,
  },
  reasonText: {
    type: String,
    default: '',
  },
  severity: {
    type: Number,
    min: 1,
    max: 5,
    default: 3,
  },
  confidenceScore: {
    type: Number,
    min: 0,
    max: 1,
    default: 0.5,
  },
  corroborations: {
    type: Number,
    default: 1,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
  },
  routeSegment: {
    from: {
      type: [Number],
      default: undefined,
    },
    to: {
      type: [Number],
      default: undefined,
    },
  },
}, {
  timestamps: true,
});

// Geospatial index for proximity queries
reportSchema.index({ location: '2dsphere' });
reportSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
reportSchema.index({ isActive: 1 });

// Static method to find nearby reports
reportSchema.statics.findNearby = function(longitude, latitude, maxDistanceMeters = 500) {
  return this.find({
    isActive: true,
    location: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [longitude, latitude],
        },
        $maxDistance: maxDistanceMeters,
      },
    },
  });
};

// Static method to find reports along a route
reportSchema.statics.findAlongRoute = function(routeCoordinates, bufferMeters = 200) {
  return this.find({
    isActive: true,
    location: {
      $geoWithin: {
        $geometry: {
          type: 'Polygon',
          coordinates: [createRouteBuffer(routeCoordinates, bufferMeters)],
        },
      },
    },
  });
};

// Helper to create a rough buffer around a route
function createRouteBuffer(coordinates, bufferMeters) {
  const bufferDeg = bufferMeters / 111320; // rough meters to degrees
  const forward = [];
  const backward = [];

  for (const coord of coordinates) {
    forward.push([coord[0] + bufferDeg, coord[1] + bufferDeg]);
    backward.unshift([coord[0] - bufferDeg, coord[1] - bufferDeg]);
  }

  const ring = [...forward, ...backward];
  ring.push(ring[0]); // close the ring
  return ring;
}

module.exports = mongoose.model('Report', reportSchema);
