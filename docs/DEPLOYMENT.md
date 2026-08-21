# Deployment and marketplace release

## Backend/admin

1. Provision managed PostgreSQL and Redis on private networks.
2. Copy `apps/api/.env.example` into the deployment secret manager, replace every secret, and configure SMTP for password recovery. Production startup requires a separate `PASSWORD_RESET_SECRET`.
3. Build immutable API/admin images. The Dockerfiles run dependency installation, Prisma client generation and production compilation.
4. Run once: `npm run prisma:migrate --workspace=@manche-irani/api`.
5. Run seed with `ADMIN_PASSWORD` only for initial catalog/admin setup; remove the secret afterward.
6. Start API replicas, then admin. Health probe: `GET /api/v1/health`; Swagger should be private or disabled at the edge in production.
7. Configure Socket.IO WebSocket upgrade, sticky sessions and the Redis adapter before adding multiple real-time replicas.
8. Load test matchmaking, reconnect storms and per-game command contention. Test PostgreSQL/Redis failover.

`docker-compose.yml` is suitable for local/staging smoke tests. It is not a substitute for managed backups, orchestration, TLS or secret management.

## Flutter build

```bash
cd apps/ludo_app
flutter pub get
flutter test
flutter analyze
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.ir/api/v1 \
  --dart-define=SOCKET_BASE_URL=https://api.example.ir
```

Create separate Android product flavors for `play`, `bazaar` and `myket`, each with its own application ID suffix only if marketplace rules require it. The Dart `PaymentRepository` uses `ir.manche.game/billing`; each flavor must register the official marketplace SDK implementation and return only purchase token + transaction ID. Entitlement still comes from backend verification.

Never commit `key.properties`, keystores, provider secrets or signing passwords. Keep signing keys in the release system, enable obfuscation/symbol upload, and archive mapping/native symbols per version.

## Release gates

- Confirm upstream Flame foundation redistribution rights; see `THIRD_PARTY_NOTICES.md`.
- Replace placeholder privacy/terms URLs and complete Persian legal copy.
- Configure official production Bazaar/Myket verification contracts and run real sandbox purchases, cancellation, refund, replay and interrupted-fulfillment tests.
- Verify target SDK and billing library requirements current on submission date.
- Test low-memory Android devices, RTL clipping, reconnect, background/foreground, clock skew and offline save recovery.
- Run SAST/SCA, secret scan, API penetration test and authoritative-engine property/fuzz tests.
- Confirm dashboards, on-call alerts, backups, restore drill, incident response and customer support paths.
- Stage rollout, monitor crash-free sessions, payment verification rate and game completion rate, then expand gradually.
