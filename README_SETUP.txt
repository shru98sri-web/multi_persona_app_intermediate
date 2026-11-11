TUITION BLUEPINK — COMPLETE FRONTEND + PYTHON BACKEND
====================================================

Included
--------
- Flutter frontend: unified Tuition AI/ML suite, PDF reader, marks gradebook,
  ScriptGrade OCR, and Utilities & Builders screens.
- Python Flask backend: backend/server.py
- Persistent backend state: backend/data/app_state.json (created automatically)
- Uploaded files: backend/uploads/ (created automatically)
- Required JSON/PDF sample assets and Flutter web index.html
- Blue/pink visual theme.

IMPORTANT VALIDATION NOTE
-------------------------
This package consolidates the latest corrected source files available in this
workspace. It has NOT been run through Flutter/Dart on a Windows Flutter SDK in
this environment. Therefore it would be misleading to guarantee that it is
100% error-free or claim that flutter analyze/build passed. Run the checks below
on your machine. If any diagnostics remain, send the COMPLETE fresh output.

WINDOWS / VS CODE SETUP
-----------------------
1. Extract this ZIP to a short path, for example:
   C:\Tuition_BluePink_Complete_Full
2. Open that extracted folder in VS Code (the folder containing pubspec.yaml).
3. Start the backend in Terminal 1:
   - Double-click run_backend.bat, OR
   - Run these commands:
       cd backend
       py -3.13 -m venv .venv
       .venv\Scripts\activate
       python -m pip install --upgrade pip
       pip install -r requirements.txt
       python server.py
   If Python 3.13 is unavailable, use py -3.9 for the venv command.
4. Check backend in Chrome:
   http://127.0.0.1:8000/health
   Keep the backend terminal running.
5. In VS Code Terminal 2, from the project root:
       flutter clean
       flutter pub get
       flutter analyze
6. If analyze has no errors, run Chrome:
       flutter run -d chrome

ANDROID BACKEND ADDRESS
-----------------------
- Android emulator: pass
    --dart-define=API_BASE_URL=http://10.0.2.2:8000
- Physical Android phone: use the PC's LAN IPv4 address, for example
    --dart-define=API_BASE_URL=http://192.168.1.10:8000
  The phone and PC must be on the same network and Windows Firewall must allow
  the backend port.

OCR NOTES
---------
The backend works without Tesseract, but OCR_AVAILABLE will be false. To enable
handwriting/image OCR, install the Tesseract OCR executable on Windows and make
sure tesseract.exe is on PATH. OCR accuracy depends on image quality and the
handwriting; teacher review remains necessary.

PERSISTENCE
-----------
Backend records are stored in backend/data/app_state.json. Uploaded documents
and images are stored in backend/uploads/. Back up these folders before moving
or deleting the project.

TROUBLESHOOTING
---------------
- If `py -3.13` is unavailable, use `py -3.9`.
- If `flutter pub get` reports a dependency solver conflict, share the full
  solver output; do not randomly downgrade packages.
- If `flutter analyze` reports errors, share the first 30-50 lines and the
  matching line numbers from lib/main.dart.
- Backend health check should return JSON at http://127.0.0.1:8000/health.
- Do not open backend/server.py as a Flutter project; run Flutter commands from
  the extracted project root.
