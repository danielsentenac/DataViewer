# DataViewer

Mobile frontend for browsing and plotting Virgo channel data.

## Scope

This repository is for the new frontend app only. The existing Tomcat backend remains the system of record for:

- channel catalog lookup
- historical archive queries
- online channel values

The frontend decision for this project is:

- `Flutter` for the mobile app
- `Riverpod` for state management
- JSON over HTTP between the app and Tomcat

The app stays intentionally simple:

- one view for channel selection
- one view for plots

## Documents

- [docs/frontend_architecture.md](docs/frontend_architecture.md)
- [docs/api_contracts.md](docs/api_contracts.md)
- [docs/build_android_apk.md](docs/build_android_apk.md)

## Repository layout

- `tomcat-json-adapter/`: Java DTOs for the compact JSON contract used by Tomcat
- `flutter_app/`: Flutter scaffold with compact payload models and HTTP repositories
- `scripts/`: local wrappers for the repo-managed Flutter SDK

## Build APK

See [docs/build_android_apk.md](docs/build_android_apk.md).
The backend URL is supplied at build/run time with
`--dart-define=DATAVIEWER_BASE_URL=...`.

## Important integration rule

The existing `VACUUM_SUPERVISOR` client talks to `jchv` using Java object serialization. The new Flutter app should not depend on that transport directly. A thin JSON adapter on the Tomcat side should expose mobile-friendly endpoints and call the legacy servlets internally when needed.

## Next step

Use the architecture and contracts in `docs/` to scaffold the Flutter app and the matching Tomcat JSON endpoints.
