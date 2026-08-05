/// Backend base URL (FastAPI / `tughePayrollCore`, see `main.py`:
/// `uvicorn.run(app, host='0.0.0.0', port=8081)`).
///
/// Override for a real deployment without touching source code, e.g.:
///   flutter run -d chrome --dart-define=API_BASE_URL=https://payroll.tughe.or.tz
///   flutter build web --dart-define=API_BASE_URL=https://payroll.tughe.or.tz
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8081',
);
