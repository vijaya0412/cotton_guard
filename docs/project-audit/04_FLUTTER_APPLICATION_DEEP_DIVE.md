# 04 — Flutter Mobile Application Deep Dive

This document provides a comprehensive technical breakdown of the **Cotton Guard** Flutter mobile client (`com.cottonguard.app.cottonguard`).

---

## 1. Application Architecture & Widget Hierarchy

The mobile application utilizes a modular, layered architecture adhering to modern Flutter best practices. State is managed reactively via `ChangeNotifier` controllers and persisted locally using `SharedPreferences`.

```
                  ┌──────────────────────────────┐
                  │       CottonGuardApp         │
                  │   (lib/main.dart: Multi-     │
                  │    Provider & ThemeBuilder)  │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │         SplashScreen         │
                  │ (Checks session & bootstrap) │
                  └──────────────┬───────────────┘
                                 │
          ┌──────────────────────┴──────────────────────┐
          │ (First Launch)                              │ (Authenticated / Returning)
          ▼                                             ▼
┌──────────────────┐                         ┌───────────────────────┐
│ OnboardingScreen │                         │  MainNavigationShell  │
│  (3-step intro)  │                         │  (4-Tab Bottom Nav)   │
└─────────┬────────┘                         └───────────┬───────────┘
          │                                              │
          ▼                                              ├─► [Tab 0]: HomeDashboardScreen
┌──────────────────┐                                     ├─► [Tab 1]: ScanScreen
│   LoginScreen    │                                     ├─► [Tab 2]: DiseaseLibraryScreen
│ (Email / Google) │                                     └─► [Tab 3]: ProfileScreen
└─────────┬────────┘                                                 │
          │                                                          ├─► ServerConnectionScreen
          ▼ (Sign-in Success)                                        ├─► ServerDiagnosticsScreen
┌────────────────────────────────────────────────────────┐           ├─► AdminControlScreen
│                   MainNavigationShell                  │           ├─► AdvisoryScreen
└────────────────────────────────────────────────────────┘           └─► HistoryScreen
```

---

## 2. State Management Architecture

State is decoupled into four dedicated controllers extending `ChangeNotifier`:

### 1. [`AuthController`](file:///E:/project/kushi/lib/controllers/auth_controller.dart)
- **Role**: Manages user authentication, token storage, and session lifecycle.
- **Key Methods**:
  - `loginWithEmail(email, password)`: Calls `/api/v1/auth/login`, stores session token, updates `currentUser`.
  - `registerWithEmail(...)`: Calls `/api/v1/auth/register`, verifies farmer role assignment.
  - `signInWithGoogle()`: Invokes [`GoogleAuthService`](file:///E:/project/kushi/lib/services/google_auth_service.dart), submits verified ID token to `/api/v1/auth/google`.
  - `logout()`: Clears active session tokens while preserving locally cached scan history.
- **State Properties**: `isAuthenticated`, `currentUser`, `authToken`, `isLoading`, `errorMessage`.

### 2. [`ConnectionController`](file:///E:/project/kushi/lib/controllers/connection_controller.dart)
- **Role**: Monitors real-time backend reachability, measures ping latency, and tracks model readiness.
- **Key Methods**:
  - `checkConnection()`: Pings `/api/v1/health` and captures network round-trip time.
  - `setServerUrl(newUrl)`: Updates the active backend address in [`StorageService`](file:///E:/project/kushi/lib/services/storage_service.dart).
- **State Properties**: `serverHealth`, `isConnected`, `isChecking`, `latencyMs`.

### 3. [`HistoryController`](file:///E:/project/kushi/lib/controllers/history_controller.dart)
- **Role**: Maintains persistent client-side record of all leaf scans performed by the user.
- **Key Methods**:
  - `loadHistory()`: Deserializes stored JSON list from `SharedPreferences`.
  - `addRecord(ScanRecord record)`: Appends new diagnosis record and flushes to disk.
  - `deleteRecord(String id)`: Removes specific scan entry.
  - `clearHistory()`: Wipes all historical records.
- **Analytics Properties**:
  - `totalScans`: Count of all historical diagnostic events.
  - `healthyCount`: Count of scans classified as "Healthy Leaf".
  - `diseasedCount`: Count of scans identified with active foliar disease.

### 4. [`ThemeController`](file:///E:/project/kushi/lib/controllers/theme_controller.dart)
- **Role**: Manages UI theme mode (Dark / Light) with dark-theme default optimized for outdoor agricultural use.

---

## 3. Scanning Workflow & Camera Viewfinder Lifecycle

The diagnostic flow in [`lib/screens/scan/`](file:///E:/project/kushi/lib/screens/scan/) is engineered for maximum reliability under variable field conditions:

### 1. Viewfinder Screen ([`ScanScreen`](file:///E:/project/kushi/lib/screens/scan/scan_screen.dart))
- **Responsive Layout**: Uses a `LayoutBuilder` calculating available height:
  ```dart
  final availableHeight = constraints.maxHeight;
  final previewHeight = (availableHeight * 0.38).clamp(250.0, 310.0);
  ```
- **Frame Composition**: Centered rectangular target frame with animated green corner brackets ([`_CornerScanningBrackets`](file:///E:/project/kushi/lib/screens/scan/scan_screen.dart#L391)) and a guidance pill positioned cleanly at `bottom: 12`.
- **Button Placement**: An 18px top margin separates the viewfinder from the action row, ensuring "Take Photo" and "Gallery" buttons sit completely below the frame without overlapping across various screen ratios.

### 2. Image Confirmation ([`ImagePreviewScreen`](file:///E:/project/kushi/lib/screens/scan/image_preview_screen.dart))
- Displays the selected image full-frame.
- Provides immediate "Retake" or "Analyze with AI" options.
- Retains image in memory across retries to prevent data loss if a network timeout occurs.

### 3. AI Analysis ([`AIAnalysisScreen`](file:///E:/project/kushi/lib/screens/scan/ai_analysis_screen.dart))
- Executes an animated scanning reticle passing over the leaf image.
- Cycles through status feedback:
  1. *Validating image brightness & sharpness...*
  2. *Scanning leaf foliage contours...*
  3. *Running MobileNetV3-CBAM attention network...*
  4. *Fetching agronomic treatment advisory...*
- Invokes [`ApiService.predictDisease()`](file:///E:/project/kushi/lib/services/api_service.dart#L88) with the binary image stream.

### 4. Diagnostic Report ([`DiagnosisResultScreen`](file:///E:/project/kushi/lib/screens/scan/diagnosis_result_screen.dart))
- **Header**: Disease common name, scientific name, and high-visibility severity pill (None, Mild, Moderate, High, Critical).
- **Confidence Metric**: Circular/linear gauge showing prediction certainty (e.g. `98.5%`).
- **Tabbed Agronomic Advice**:
  - **Symptoms Tab**: Botanical indicators to verify on-field symptoms.
  - **Chemical Cure Tab**: Authoritative fungicide, bactericide, or insecticide dosages (e.g., *Copper Oxychloride 50 WP @ 2.5 g/L*).
  - **Organic & Prevention Tab**: Cultural practices, resistant seeds, sticky traps, and neem formulations.
- **Safety Safeguard**: If prediction uncertainty is detected, chemical cures are automatically hidden and replaced with an explicit cautionary advisory advising physical examination at the nearest Krishi Vigyan Kendra.

---

## 4. Local Persistence & Storage Service

Client-side data persistence is encapsulated within [`StorageService`](file:///E:/project/kushi/lib/services/storage_service.dart):

| Storage Key | Data Format | Architectural Purpose |
| :--- | :--- | :--- |
| `auth_token` | `String` | Base64 HMAC-SHA256 session token for authenticated API calls. |
| `user_profile` | `String` (JSON) | Cached user account details (ID, name, email, phone, location, avatar path). |
| `scan_history` | `String` (JSON Array) | Serialized list of historical [`ScanRecord`](file:///E:/project/kushi/lib/models/scan_record.dart) objects. |
| `server_url` | `String` | Configured backend endpoint (defaults to `https://cotton-guard.onrender.com/api/v1`). |
| `theme_mode` | `String` | Selected theme mode (`dark` or `light`). |

---

## 5. Geographical & Weather Integration

### Indian District Database
- Implemented in [`india_states_districts.dart`](file:///E:/project/kushi/lib/data/india_states_districts.dart) and [`indian_locations.dart`](file:///E:/project/kushi/lib/data/indian_locations.dart).
- Covers **780+ districts across all 28 States and 8 Union Territories** of India with verified geographic coordinates (latitude and longitude).
- Presented via [`LocationPickerSheet`](file:///E:/project/kushi/lib/widgets/location_picker_sheet.dart) with instant search filtering.

### Weather Forecast Service
- Implemented in [`WeatherService`](file:///E:/project/kushi/lib/services/weather_service.dart).
- Connects directly to the **Open-Meteo Free API**:
  `https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true&hourly=relative_humidity_2m,precipitation_probability`
- Parses metrics into [`WeatherData`](file:///E:/project/kushi/lib/models/weather_data.dart):
  - Current temperature (°C)
  - Relative humidity (%)
  - Wind speed (km/h)
  - Precipitation probability (%)
  - Agricultural condition summary (e.g. *Optimal Sowing Weather*, *High Humidity Disease Alert*).

---

## 6. Indian Time Service & Localized Greetings

Implemented in [`IndianTimeService`](file:///E:/project/kushi/lib/services/indian_time_service.dart):
- Calculates current Indian Standard Time (IST = UTC + 5:30) regardless of device clock drift.
- Returns contextual greetings:
  - **04:00 – 11:59**: *Subhodayam / Good Morning*
  - **12:00 – 16:59**: *Namaskaram / Good Afternoon*
  - **17:00 – 20:59**: *Shubhodhayam / Good Evening*
  - **21:00 – 03:59**: *Good Night*

---

## 7. Design System & Theming

- **Palette ([`AppColors`](file:///E:/project/kushi/lib/constants/app_colors.dart))**: Deep dark background (`#0F1412`), forest green surface (`#16201B`), high-visibility agriculture green primary (`#22C55E`), amber warning (`#F59E0B`), and crimson critical (`#EF4444`).
- **Typography ([`AppTypography`](file:///E:/project/kushi/lib/constants/app_typography.dart))**: Inter-based legible type hierarchy with generous line heights for outdoor sunlight visibility.
- **Components**: Translucent blur glassmorphic cards ([`GlassCard`](file:///E:/project/kushi/lib/widgets/glass_card.dart)), status pills ([`StatusBadge`](file:///E:/project/kushi/lib/widgets/status_badge.dart)), and ergonomic rounded action buttons ([`CustomButton`](file:///E:/project/kushi/lib/widgets/custom_button.dart)).
