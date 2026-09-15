const mongoose = require('mongoose');

const hotspotSchema = new mongoose.Schema({
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
  totalReports: {
    type: Number,
    default: 0,
  },
  recentReports: {
    type: Number,
    default: 0,
  },
  primaryReason: {
    type: String,
    enum: ['road_blocked', 'traffic', 'accident', 'personal_preference', 'other'],
  },
  averageSeverity: {
    type: Number,
    default: 3,
  },
  confidenceScore: {
    type: Number,
    min: 0,
    max: 1,
    default: 0.5,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  lastReportedAt: {
    type: Date,
    default: Date.now,
  },
  predictions: {
    likelyToOccurAgain: { type: Boolean, default: false },
    predictedTimeRange: { type: String, default: '' },
    historicalPattern: { type: String, default: '' },
  },
}, {
  timestamps: true,
});

hotspotSchema.index({ location: '2dsphere' });
hotspotSchema.index({ isActive: 1, confidenceScore: -1 });

module.exports = mongoose.model('Hotspot', hotspotSchema);
