# Ovok Flutter SDK Example

A native Flutter app showing Ovok authentication, profile and session widgets,
realtime updates, Bluetooth device discovery, and opt-in health data sync.

## Run

Install Flutter, connect an iOS or Android device, then run:

```sh
flutter pub get
flutter run --dart-define=OVOK_TENANT_CODE=your-sandbox-tenant
```

The app uses `https://api.sandbox.ovok.com` by default. You can set
`OVOK_BASE_URL` and `OVOK_CLIENT_ID` with additional `--dart-define` arguments.
Google sign-in can be configured with `GOOGLE_INTERNAL_ID`,
`GOOGLE_CLIENT_ID`, and `GOOGLE_SERVER_CLIENT_ID`.

## Health sync

In the Health sync tab, enable sync and grant read access to steps and heart
rate. The first sync can read up to 30 days of data for the signed-in patient.
Sync runs in the foreground and retries when connectivity returns. Use a
sandbox tenant and revoke access in device settings when finished.

HealthKit needs a physical iOS device and an Apple development team selected in
Xcode. Android needs Health Connect installed with step or heart-rate data.
