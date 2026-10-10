# 14 — Setup, Build & Developer Run Guide

This document provides a step-by-step technical guide for setting up, building, testing, and running **Cotton Guard** on Windows, Android devices, and Docker environments.

---

## 1. System Prerequisites

Before starting, verify the following software is installed on your workstation:
1. **Flutter SDK**: Version `3.13.4` or newer (Dart `3.x`).
2. **Android SDK & Platform-Tools**: Android Studio with Android SDK Command-line Tools, Platform-Tools (`adb`), and Java 17.
3. **Python**: Version `3.12` or `3.13` (64-bit).
4. **Git**: Git for Windows.
5. **Docker** *(Optional)*: Docker Desktop for Windows with WSL2 backend.

---

## 2. Local Backend Setup & Execution

Run the following commands in PowerShell from the project root directory (`E:\project\kushi`):

### Step 1: Create and Activate Python Virtual Environment
```powershell
# Create virtual environment using Python 3.13
py -3.13 -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1
```

### Step 2: Install Backend Dependencies
```powershell
pip install --upgrade pip
pip install -r backend/requirements.txt
```

### Step 3: Initialize Database & Provision Administrator
```powershell
# Initialise schema and seed canonical knowledge base
python backend/database.py

# (Optional) Provision initial administrator account
$env:ADMIN_EMAIL="admin@cottonguard.org"
$env:ADMIN_INITIAL_PASSWORD="SecureAdminPassword2026!"
python backend/provision_admin.py
```

### Step 4: Start the FastAPI Server
```powershell
# Runs server on 0.0.0.0:7860 (accessible to emulators and LAN)
python backend/run_server.py
```
*The API is now accessible at `http://localhost:7860` or `http://127.0.0.1:7860`.*

### Step 5: Execute Backend Automated Test Suites
```powershell
# Run backend test suite (37 tests)
py -3.13 -m pytest backend/ -v

# Run ML pipeline test suite (11 tests)
py -3.13 -m pytest test/test_ml_pipeline.py -v
```

---

## 3. Flutter Mobile Application Setup & Execution

Open a new PowerShell terminal in `E:\project\kushi`:

### Step 1: Check Environment Health & Install Dependencies
```powershell
flutter doctor
flutter pub get
```

### Step 2: Run Static Code Analysis & Widget Tests
```powershell
# Run static analysis (enforces 0 errors, 0 warnings)
flutter analyze

# Run unit and widget test suite (20 tests)
flutter test
```

### Step 3: Launch on Android Emulator
```powershell
# Start your configured Android emulator from Android Studio, then run:
flutter run
```
*Note: In the emulator, you can connect to the local backend using `http://10.0.2.2:8000/api/v1` or the live cloud backend.*

### Step 4: Run on Physical Android Phone via USB
1. Enable **Developer Options** and **USB Debugging** on your Android smartphone.
2. Connect phone via USB cable and authorize computer.
3. Verify connection:
   ```powershell
   adb devices
   ```
4. Run the app directly on your phone:
   ```powershell
   flutter run
   ```

### Step 5: Compile Production Release APK
```powershell
flutter build apk --release
```
- **Output Location**: [`build/app/outputs/flutter-apk/app-release.apk`](file:///E:/project/kushi/build/app/outputs/flutter-apk/app-release.apk)
- **Size**: ~58.9 MB
- **Installation via ADB**:
  ```powershell
  adb install -r build\app\outputs\flutter-apk\app-release.apk
  ```

---

## 4. Local Docker Container Build & Run

To test the production container locally:

### Step 1: Build Container Image
```powershell
docker build -t cotton-guard:latest .
```

### Step 2: Run Container
```powershell
docker run -d `
  --name cotton-guard-api `
  -p 7860:7860 `
  -e PORT=7860 `
  -e ENVIRONMENT=development `
  cotton-guard:latest
```

### Step 3: Verify Health Endpoint
```powershell
curl http://localhost:7860/api/v1/health
```

---

## 5. Connecting Mobile App to Your Backend

The app includes an in-app server connection manager:
1. Open the mobile app and navigate to **Profile Tab** $\rightarrow$ **Server Connection**.
2. Select one of the presets or enter a custom address:
   - **Production Cloud**: `https://cotton-guard.onrender.com/api/v1` *(Default)*
   - **Android Emulator**: `http://10.0.2.2:8000/api/v1`
   - **Localhost**: `http://127.0.0.1:8000/api/v1`
   - **Physical Device over LAN**: `http://<YOUR_COMPUTER_LAN_IP>:7860/api/v1`
3. Tap **Test Latency** to verify HTTP reachability, model status, and ping time.
4. Tap **Save Endpoint**. The setting persists across app restarts.
