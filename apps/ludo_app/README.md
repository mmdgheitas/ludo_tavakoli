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

Production builds must supply HTTPS API/socket URLs and release signing configuration. Android application ID: `ir.manche.game`.
