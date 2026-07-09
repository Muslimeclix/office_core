# Contributing to OfficeCore

Thanks for your interest in contributing! This guide covers the basics.

## Development Setup

1. **Install Flutter** 3.22+ and Dart 3.4+
2. **Clone the repo:**
   ```bash
   git clone https://github.com/your-org/office_core.git
   cd office_core
   ```
3. **Install dependencies:**
   ```bash
   flutter pub get
   cd example && flutter pub get && cd ..
   ```
4. **Run tests:**
   ```bash
   flutter test
   ```
5. **Run the example app:**
   ```bash
   cd example
   flutter run
   ```

## Project Structure

```
office_core/
├── lib/
│   ├── office_core.dart              ← Public exports
│   └── src/
│       ├── office_core.dart          ← Singleton + initialize()
│       ├── remote_config/
│       │   ├── models/               ← Typed Dart classes
│       │   └── office_remote_config_service.dart
│       ├── ads/                      ← Controller + widgets
│       ├── crashlytics/
│       ├── analytics/
│       ├── notifications/
│       ├── trial/
│       ├── premium/                  ← PremiumStatusProvider + adapters
│       └── util/                     ← Lifecycle, connectivity, logger, prefs
├── example/                          ← Demo app
├── test/                             ← Unit tests
└── pubspec.yaml
```

## Coding Standards

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart).
- Add dartdoc comments to all public APIs.
- Prefer `const` constructors where possible.
- Every subsystem must degrade gracefully — never throw from init.
- Run `flutter analyze` before submitting. Fix all warnings.

## Testing

- Write unit tests for all new models and services.
- Use `FakePremiumProvider` for tests that depend on premium status.
- Place tests in `test/` mirroring `lib/src/` structure.

## Pull Request Process

1. Create a feature branch from `main`.
2. Make your changes. Keep commits focused.
3. Add or update tests.
4. Update the CHANGELOG.md.
5. Run `flutter test` and `flutter analyze` — both must pass.
6. Open a PR with a clear description of what changed and why.

## Releasing

1. Bump version in `pubspec.yaml` following semver.
2. Update `CHANGELOG.md`.
3. Tag the release: `git tag v1.0.1`.
4. Publish: `flutter pub publish`.

## Questions?

Open an issue on GitHub.
