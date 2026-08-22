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

For an Android emulator, the defaults use `10.0.2.2`. For a physical phone, replace that address with the development computer's LAN IP, ensure NestJS is running on port 3001, and allow the port through the host firewall.

Production builds must supply HTTPS API/socket URLs and release signing configuration. Android application ID: `ir.manche.game`.
