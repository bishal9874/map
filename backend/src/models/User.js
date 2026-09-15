const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  deviceId: {
    type: String,
    required: true,
    unique: true,
  },
  displayName: {
    type: String,
    default: 'Anonymous Navigator',
  },
  points: {
    type: Number,
    default: 0,
  },
  reportsSubmitted: {
    type: Number,
    default: 0,
  },
  trustScore: {
    type: Number,
    min: 0,
    max: 1,
    default: 0.5,
  },
  badges: [{
    name: String,
    earnedAt: Date,
  }],
  lastActive: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

// Award points for reporting
userSchema.methods.addPoints = function(pts) {
  this.points += pts;
  this.reportsSubmitted += 1;
  
  // Increase trust score based on contributions
  this.trustScore = Math.min(1.0, 0.5 + (this.reportsSubmitted * 0.02));
  
  // Check for badge eligibility
  const badges = [
    { threshold: 5, name: 'First Responder' },
    { threshold: 25, name: 'Road Guardian' },
    { threshold: 50, name: 'Navigation Expert' },
    { threshold: 100, name: 'CrowdNav Legend' },
  ];
  
  for (const badge of badges) {
    if (this.reportsSubmitted >= badge.threshold && 
        !this.badges.find(b => b.name === badge.name)) {
      this.badges.push({ name: badge.name, earnedAt: new Date() });
    }
  }
  
  return this.save();
};

module.exports = mongoose.model('User', userSchema);
