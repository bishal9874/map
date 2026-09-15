require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const http = require('http');
const { Server } = require('socket.io');

const apiRoutes = require('./routes/api');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Make io accessible in routes
app.set('io', io);

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// API Routes
app.use('/api', apiRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);
  
  // Client sends their location for real-time alerts
  socket.on('location_update', async (data) => {
    const { latitude, longitude } = data;
    
    try {
      const Report = require('./models/Report');
      const nearbyReports = await Report.findNearby(longitude, latitude, 500);
      
      const alerts = nearbyReports
        .filter(r => r.isActive && r.confidenceScore >= 0.3)
        .map(r => ({
          id: r.reportId,
          type: r.reason,
          location: r.location.coordinates,
          severity: r.severity,
          confidence: r.confidenceScore,
        }));
      
      if (alerts.length > 0) {
        socket.emit('nearby_alerts', { alerts });
      }
    } catch (error) {
      console.error('Location update error:', error);
    }
  });
  
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
  });
});

// Connect to MongoDB and start server
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/crowdnav';

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Connected to MongoDB');
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 CrowdNav Backend running on port ${PORT}`);
      console.log(`📡 WebSocket server ready`);
      console.log(`🔗 API: http://localhost:${PORT}/api`);
    });
  })
  .catch((err) => {
    console.error('❌ MongoDB connection error:', err.message);
    console.log('⚠️  Starting server without MongoDB (limited functionality)...');
    server.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 CrowdNav Backend running on port ${PORT} (No DB)`);
    });
  });

module.exports = { app, server, io };
