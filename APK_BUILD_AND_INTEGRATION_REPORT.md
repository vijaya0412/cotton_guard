# COTTON GUARD — RELEASE APK BUILD & VERIFIED INTEGRATION REPORT

**Build Date:** October 10, 2026  
**Artifact Status:** RELEASE BUILD SUCCESSFUL  
**Application ID:** `com.cottonguard.app.cottonguard`  
**Application Name:** Cotton Guard  
**Package Version:** `1.0.0` (Version Code `1`)  

---

## 1. Release APK Artifact Metadata

| Property | Value |
| :--- | :--- |
| **Output File** | `app-release.apk` |
| **Absolute Path** | `E:\project\kushi\build\app\outputs\flutter-apk\app-release.apk` |
| **Desktop Path** | `C:\Users\duppa\Desktop\CottonGuard.apk` |
| **File Size** | `61,604,916 bytes` (58.75 MB) |
| **Build Timestamp** | `2026-10-10 17:35:29` |
| **SHA-256 Checksum** | `0BF36166EE27D800BD2B68250671C5F5F704241BE72D268245450596737382C4` |
| **Application ID** | `com.cottonguard.app.cottonguard` |
| **Application Label** | `Cotton Guard` |
| **Launchable Activity Icon** | Explicitly registered (`res/BW.xml` adaptive/round) |
| **APK Signature Schemes** | APK Signature Scheme v2 (Verified) |
| **Signing Certificate SHA-1** | `4E:97:C3:84:CF:BD:0D:13:2B:81:EC:7A:1D:E1:DA:7C:23:8D:64:8B` |
| **Signing Certificate SHA-256** | `D2:8F:C4:6A:EE:2A:D5:F0:EB:B1:5A:AD:0D:02:32:11:4F:7B:33:0E:A3:12:35:3B:C0:01:4E:4A:4A:E6:DD:DB` |
| **Target Architecture** | Universal ARM64-v8a / armeabi-v7a / x86_64 |

---

## 2. Integrated Feature Verification

### 2.1 Official App Logo & Android Launcher Branding
- **Source Image:** Uploaded Cotton Guard high-resolution badge processed into a centered 1024×1024 RGBA transparent PNG.
- **Flutter Assets:** `assets/images/cotton_guard_logo.png` integrated into Splash, Login, Profile, Settings, and About dialogs.
- **Launcher Icons:** Regenerated across all Android densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`):
  - Legacy squircle: `ic_launcher.png` on `#0D251D` background.
  - Round icon: `ic_launcher_round.png` on `#0D251D` background.
  - Adaptive icon: `ic_launcher_foreground.png` centered in safe zone over `@color/ic_launcher_background` (`#0D251D`).

### 2.2 Google OAuth 2.0 Web Client Integration
- **Web Client ID:** `647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com`
- **Flutter Implementation (`ApiConstants.googleServerClientId`):** Configured as non-nullable string passed to `GoogleSignIn(serverClientId: ...)` in `GoogleAuthService`.
- **Backend Configuration (`backend/.env` & `backend/main.py`):**
  - Loaded via `python-dotenv` into `GOOGLE_CLIENT_ID`.
  - `.env` and `*.env` are strictly excluded from Git and are never packaged into the APK.
- **Cryptographic Token Verification:**
  - Token authenticity verified against Google's public tokeninfo endpoint.
  - Issuer enforced: `accounts.google.com` or `https://accounts.google.com`.
  - Audience enforced: `aud == GOOGLE_CLIENT_ID`.
  - Expiration checked: `exp >= time.time()`.
  - Email verified check: `email_verified == True`.
  - Zero-Trust Identity: User email and name are extracted strictly from the verified token payload; client-supplied body parameters are completely ignored.

### 2.3 Minimal Redesigned Splash Screen
- Minimal circular emblem with smooth 1200ms scale/fade animation.
- Theme-adaptive color palette (`#0D251D` dark / `#F6FAF7` light).
- Predictable 1.5-second navigation without artificial delays.

### 2.4 Simplified Onboarding Flow & Direct Login Route
- **4 Informative Slides:**
  1. *Smart Cotton Leaf Scanning* (AI Vision Inference)
  2. *Disease Insights & Field Advisories* (Agronomic Database)
  3. *Location-Aware Weather & Alerts* (Live Field Weather)
  4. *Cotton Guard Smart Crop Health* — displaying the official centered Cotton Guard brand logo!
- **Streamlined Navigation:** Only a single "Continue" button on all slides. The multiple confusing choice buttons ("Create Account", "Sign In", "Explore as Guest") on the last slide have been completely removed.
- **Direct Login Navigation:** Tapping "Continue" on slide 4 (or "Skip" at any point) transitions immediately to the `LoginScreen`.
- **Integrated Login Experience:** `LoginScreen` presents the Cotton Guard logo banner, email/phone credentials login, the "Continue with Google" button (backed by Web OAuth client ID `647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com`), and an "Explore as Guest" option.

### 2.5 Jitter-Free AI Image Analysis
- Single calm progress ring animation controller with `RepaintBoundary`.
- `cacheWidth: 600` hardware-accelerated texture downscaling.
- Synchronized stages matching the real FastAPI inference response future:
  1. *Inspecting leaf surface...*
  2. *Verifying cotton foliage...*
  3. *Evaluating disease biomarkers...*
  4. *Finalizing agronomic advisory...*

### 2.6 28 Indian States & 8 Union Territories with 786 Districts
- Official Local Government Directory (LGD) / Census of India database compiled into `lib/data/india_states_districts.dart`.
- Two-tier state/UT dropdown + quick horizontal chips + instant district search filter in `LocationPickerSheet`.
- Exact coordinates saved to user profile and passed to weather service.

### 2.7 Real-Time Weather via Open-Meteo
- 30-minute local caching mechanism in `StorageService`.
- Formatted units (°C, %, km/h), observation timestamp, and freshness badges ("Live" vs "Cached").
- Agronomic weather advisory notes and manual refresh.

### 2.8 Production AI Model & Multi-Stage Pipeline
- MobileNetV3-Large + CBAM Attention (Hybrid CLAHE) in `ml/models/cotton_guard_model.onnx` (17.3 MB, SHA-256: `ff806f00...`).
- Multi-stage pipeline: Quality Gate (blur, brightness, contrast) → Foliage Gate (LAB color segmentation) → ONNX Inference → SQLite Advisory lookup (`advisory.db`).
- Live latency verified at ~18.8 ms.

---

## 3. Verification & Quality Assurance Suite

| Verification Test | Command | Outcome |
| :--- | :--- | :---: |
| **Backend API & ML Test Suite** | `py -3.13 -m pytest -v backend/test_api.py` | **12 / 12 Passed (100%)** |
| **Backend Auth & Security Suite** | `py -3.13 -m pytest -v backend/test_auth.py` | **5 / 5 Passed (100%)** |
| **Flutter Static Analysis** | `flutter analyze` | **0 issues found** |
| **Flutter Unit & Widget Tests** | `flutter test` | **17 / 17 Passed (100%)** |
| **FastAPI Backend Production Service** | `py -3.13 backend/run_server.py` | **Running on 0.0.0.0:8000** |

> [!NOTE]
> Automated tests confirm that token validation, audience enforcement, and identity extraction function properly. Physical device Google Sign-In must be validated on the physical Android device with a Google account added under **Test users** in Google Cloud Console.

---

## 4. Installation Instructions for Physical Android Device

> [!IMPORTANT]
> **Android Launcher Icon Cache Note:** Android home screen launchers cache application icons by package name. If an older build of Cotton Guard is already installed on your device, **uninstall the previous build first** before installing the new APK. This forces Android's launcher and task switcher to immediately bind the new official Cotton Guard app icon.

### Option A: Install via ADB (Clean Install - Recommended)
Connect your physical Android phone via USB with USB Debugging enabled:
```bash
# 1. Uninstall previous installation to purge cached icon & state
adb uninstall com.cottonguard.app.cottonguard

# 2. Install the new release build
adb install "E:\project\kushi\build\app\outputs\flutter-apk\app-release.apk"
```

### Option B: Direct Device Transfer
1. On your phone, **long-press the existing Cotton Guard icon and tap Uninstall**.
2. Copy `E:\project\kushi\build\app\outputs\flutter-apk\app-release.apk` to your phone's Internal Storage or send it via USB / Quick Share / Google Drive.
3. Open the APK file in your phone's file manager and tap **Install**.
4. Launch **Cotton Guard**:
   - The launcher displays the new **Cotton Guard** icon.
   - The splash screen reveals the logo and animates smoothly into onboarding.
   - Go through the onboarding slides using the single **Continue** button.
   - Slide 4 showcases the official Cotton Guard logo; tapping **Continue** lands you directly on the **Login** screen.
   - On the Login screen, choose **Continue with Google** or enter your credentials.

---

## 5. Physical Device Google Sign-In Acceptance Checklist

1. **Verify Test User Registration:** Ensure your testing Google account is added in **Google Cloud Console → Google Auth Platform → Audience → Test users**.
2. **Verify Network Connectivity:** In Cotton Guard, navigate to **Settings → Server Connection** and ensure the status shows **CONNECTED** to your host computer's IP (e.g., `http://192.168.x.x:8000`).
3. **Trigger Sign-In:** Tap **Continue with Google** on the Login screen, choose your Google account, and confirm that your Google profile name and photo load into the Cotton Guard dashboard.
