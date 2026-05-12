# CivicSafe Flutter Frontend

CivicSafe is a comprehensive smart civic issue detection platform. This frontend is built with Flutter and connects to the FastAPI backend. It features role-based dashboards (Citizen, Admin, Authority), image-based reporting with GPS coordinates, and analytics.

## Prerequisites

To run this application, you need to have Flutter installed on your system.

1. **Install Flutter SDK:**
   Follow the official instructions for Windows here: [Install Flutter on Windows](https://docs.flutter.dev/get-started/install/windows)

2. **Verify Installation:**
   Run `flutter doctor` in your terminal to ensure all necessary tools (like Chrome for web testing) are installed and configured.

## Setup Instructions

1. **Navigate to the frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Start the Backend:**
   Ensure your FastAPI backend is running before launching the frontend. In a separate terminal, navigate to the `backend` directory and run:
   ```bash
   uv run uvicorn main:app --host 127.0.0.1 --port 8000 --reload
   ```

4. **Run the Flutter App (Web/Chrome):**
   ```bash
   flutter run -d chrome --web-port 8080
   ```

5. **Access the Application:**
   Once the build completes, Chrome will automatically open. If not, manually navigate to `http://localhost:8080` in your web browser.

## Generating an APK (Android)

To build a release APK that you can install on Android devices:

```bash
flutter build apk --release
```

Once the build process finishes, you can find the generated APK file at:
`build/app/outputs/flutter-apk/app-release.apk`
