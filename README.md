# CiviSense AI — Frontend

> **Flutter mobile and web client for the CiviSense AI platform.**

This repository contains the frontend application for CiviSense AI, built with Flutter. It provides role-based interfaces for citizens, municipal officers, authority figures, and system administrators.

---

## Features

### Role-Based Access

The application supports four distinct user roles, each with a tailored experience:

1. **Citizen**
   - Public registration (gated to supported jurisdictions: GHMC, Cyberabad Municipal Corporation, Malkajgiri Municipal Corporation).
   - Secure login.
   - Submit new civic complaints with multimodal data: image capture, GPS coordinates, and text description.
   - View personal complaint history and status.

2. **Officer**
   - Login (accounts provisioned by admins only).
   - View assigned pending reports. Assignments are deterministic, based on active status, matching jurisdiction and department, and lowest pending workload (with stable user ID tie-breaking).

3. **Authority**
   - Login.
   - Review and mark reports as resolved using the unique issue number.

4. **Admin**
   - Login.
   - View all system reports with optional status filtering.
   - Access high-level analytics and aggregated data.
   - Provision new officer accounts.

### Key Capabilities

- **Secure API Communication:** Bearer token authentication via JWT (stored locally).
- **Multipart Uploads:** Sends image bytes, coordinates, and text descriptions seamlessly to the backend AI pipeline.
- **Image Viewing:** Secure, authenticated image retrieval for authorised roles.

---

## Technology Stack

- **Framework:** Flutter / Dart (SDK ^3.11.1)
- **State Management:** `provider`
- **HTTP Client:** `http`
- **Local Storage:** `shared_preferences`
- **Hardware Integration:** `image_picker` (camera/gallery), `geolocator` (GPS)
- **UI/UX:** `google_fonts`, `cupertino_icons`, custom glass-morphism theme

---

## Local Setup

### Prerequisites

- Flutter SDK (≥ 3.11.1)
- Dart SDK
- A running instance of the CiviSense AI backend

### Running the App

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure and Run:**
   The API base URL is injected at build time. It must be provided via `--dart-define`.

   *Running on a local emulator/web (pointing to localhost backend):*
   ```bash
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```

   *Running on a physical device (pointing to your host machine's IP):*
   ```bash
   flutter run --dart-define=API_BASE_URL=http://<YOUR_HOST_IP>:8000
   ```

---

## Limitations

- Push notifications are not currently implemented.
- Offline mode and local caching of reports are not supported.
- The UI is optimised for mobile form factors; web/desktop layouts are functional but not fully responsive.
- Real Flutter runtime validation has not been performed in this automated environment.
