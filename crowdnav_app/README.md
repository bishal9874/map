# 🧭 CrowdNav Client App (Frontend)

A cross-platform mobile and web navigation application built with **Flutter**, designed to provide adaptive, crowd-powered routing using **OpenStreetMap**. The app empowers drivers with real-time GPS tracking, automatic diversion detection, and community-driven incident reporting.

---

## 📱 App Highlights & Capabilities

### 🗺️ Interactive OpenStreetMap & Visualization
- **Dark-Themed Map Canvas**: Utilizes high-contrast OpenStreetMap raster tiles styled with custom dark-mode matrix filters for reduced night-time glare and visual clarity.
- **Route Polyline Overlay**: Renders active navigation routes with glowing dual-layered neon polylines for high visibility.
- **Dynamic Pins & Markers**: Visual indicators for starting point (Marker A), destination (Marker B), and user location.
- **Animated Map Camera**: Smooth camera transitions (`CurvedAnimation`) when focusing on destinations, recentering on the user, or fitting route boundaries.

### 📍 Location Tracking & Navigation Engine
- **Live GPS Tracking**: Real-time position, bearing, and speed stream updates using the `geolocator` service.
- **Live User Marker**: Custom pulsating radar-effect marker indicating current user location and orientation.
- **Trip Statistics HUD**: Real-time calculation of remaining travel distance, estimated time of arrival (ETA), and trip progress.

### 🔍 Smart Search & Autocomplete
- **Search Debouncing**: Integrated 500ms debounce timer in `NavigationProvider` that eliminates redundant API calls while typing.
- **Source & Destination Autocomplete**: Search for landmarks and addresses with instant suggestion lists.
- **Reverse Geocoding**: Automatically converts GPS coordinates to human-readable street names.
- **Current Location Shortcut**: Pre-fills starting point with current device coordinates with one tap.

### 🚧 Crowd Intelligence & Incident Reporting
- **Automatic Diversion Detection**: Continuously monitors the user's distance from the planned route. If deviation exceeds the **50-meter threshold**, the app automatically detects the off-route status and prompts a diversion dialog.
- **One-Tap Incident Reporting**: Quick-report modal for drivers to flag road conditions with categorized icons:
  - 🛑 **Road Blocked**
  - 🚗 **Heavy Traffic**
  - 💥 **Accident**
  - 🔀 **Personal Choice / Detour**
  - 📝 **Custom Notes**
- **Proximity Hazard Alerts**: Interactive animated warning banners (`AlertBanner`) alerting drivers when approaching verified community-reported road hazards.
- **Interactive Report Markers**: Nearby reported issues are plotted directly on the map with severity-coded icons and confidence scores.

### 🏁 Trip Completion
- **Arrival Detection**: Automatically senses when the user reaches within 50 meters of their destination and displays a trip summary completion dialog.

---

## 🏗️ Frontend Architecture & Structure

The app follows a clean, decoupled architecture powered by the **Provider** state management pattern:

```
crowdnav_app/
├── lib/
│   ├── main.dart                      # App entry point, orientation lock, dark system chrome
│   │
│   ├── screens/                       # Top-level screen views
│   │   ├── splash_screen.dart         # Animated branded splash screen with gradient transitions
│   │   └── map_screen.dart            # Main map canvas, layer stacking, FABs, and dialog triggers
│   │
│   ├── providers/                     # State management layer
│   │   └── navigation_provider.dart   # Central ChangeNotifier managing route state, GPS tracking,
│   │                                  # search debounce, diversion checks, and report timers
│   │
│   ├── widgets/                       # Reusable modular UI components
│   │   ├── search_panel.dart          # Route planning search card with origin/destination inputs
│   │   ├── navigation_panel.dart      # Active navigation HUD displaying live ETA, distance & controls
│   │   ├── diversion_dialog.dart      # Modal prompting users to report reasons for route deviation
│   │   └── alert_banner.dart          # Slide-in warning banner for upcoming route hazards
│   │
│   ├── services/                      # External communication & hardware integration
│   │   ├── location_service.dart      # GPS permissions, continuous tracking streams, distance calculations
│   │   └── api_service.dart           # Platform-aware networking (Web/Mobile/Desktop) & fallbacks
│   │
│   ├── models/                        # Typed data transfer objects
│   │   ├── route_model.dart           # Route geometry, coordinate points, distance, and duration
│   │   ├── report_model.dart          # Incident reports, alert schemas, and confidence scores
│   │   └── geocoding_result.dart      # Location search results with lat/lon coordinates
│   │
│   └── utils/
│       └── app_theme.dart             # Unified design system: dark palettes, glowing accents, typography
│
└── pubspec.yaml                       # App dependencies and assets configuration
```

---

## 🛠️ Tech Stack & Key Libraries

| Package | Purpose |
|---------|---------|
| **Flutter SDK** | Cross-platform UI toolkit (Dart 3+) |
| **`flutter_map`** (v7.0+) | High-performance OpenStreetMap raster tile rendering |
| **`latlong2`** | Geodesic calculations and LatLng geometric representations |
| **`provider`** | Reactive state management between UI widgets and navigation logic |
| **`geolocator`** | Native GPS location streaming, permission handling, and distance calculations |
| **`flutter_animate`** | Fluid micro-interactions, pulse effects, and dialog entrances |
| **`http`** | REST API networking with timeouts and cross-platform fallbacks |
| **`shared_preferences`**| Local device key-value storage for settings and cached data |

---

## 🌐 Cross-Platform Support

The frontend is configured with native runners for multiple targets:
- 📱 **Android**: Optimized for Android 5.0+ (API level 21+) with fine and background location permissions.
- 🍏 **iOS**: Configured with `SceneDelegate` and CoreLocation usage descriptions.
- 💻 **Web (Chrome/Edge)**: Platform-aware networking that routes requests cleanly without browser CORS blocks.
- 🖥️ **Desktop (Windows & macOS)**: Native desktop executable runners for fast local development and testing.

---

## 🚀 Running the App Locally

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.0 or higher)
- Google Chrome (for web testing) or an Android device/emulator

### Installation & Execution

1. **Navigate into the frontend project directory:**
   ```bash
   cd crowdnav_app
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on your preferred platform:**
   - **Run on Web (Chrome):**
     ```bash
     flutter run -d chrome
     ```
   - **Run on Android Emulator / Physical Device:**
     ```bash
     flutter run
     ```
   - **Run on Windows Desktop:**
     ```bash
     flutter run -d windows
     ```
   - **Run on macOS Desktop:**
     ```bash
     flutter run -d macos
     ```

---

## 🎨 UI Design System

- **Background / Surface**: Dark mode canvas (`#121218`, `#1E1E28`)
- **Primary Accent**: Electric Cyan (`#00D2FF`) for routes and active GPS indicators
- **Alert Colors**:
  - 🛑 Road Blocked: `#EF5350`
  - ⚠️ Heavy Traffic: `#FFB300`
  - 💥 Accident: `#FF5722`
  - ✅ Clear / On Route: `#00E676`
