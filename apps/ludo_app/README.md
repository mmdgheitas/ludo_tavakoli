# منچ ایرانی — Flutter client

Flutter/Flame client for the Persian online and offline Ludo product.

```bash
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3001/api/v1 \
  --dart-define=SOCKET_BASE_URL=http://10.0.2.2:3001
```

## Backend-free mock mode

Use the compile-time switch below to test authentication, lobby, shop, profile, rewards, inventory, support, and offline 2/4-player games without starting PostgreSQL, Redis, or NestJS:

```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

Mock mode is disabled by default and never comments out or replaces production API code. Online matchmaking is intentionally disabled while this switch is active.

For an Android emulator, the defaults use `10.0.2.2`. For a physical phone, replace that address with the development computer's LAN IP, ensure NestJS is running on port 3001, and allow the port through the host firewall.

Production builds must supply HTTPS API/socket URLs and release signing configuration. Android application ID: `ir.manche.game`.
