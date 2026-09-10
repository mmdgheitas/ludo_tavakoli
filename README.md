# منچ ایرانی — Manche Irani

A production-oriented monorepo for a Persian, RTL Ludo product: Flutter/Flame mobile client, authoritative NestJS multiplayer backend, PostgreSQL/Redis data layer, and a Next.js operations dashboard.

## Repository map

```text
apps/
  mobile/   Flutter + Flame + Riverpod (Android, Bazaar/Myket-ready boundary)
  api/      NestJS + Socket.IO + Prisma + PostgreSQL + Redis
  admin/    Next.js + TailwindCSS + Recharts, fully RTL

docs/      architecture, API, database, security and deployment runbooks
```

The Flame board renderer is derived from `harsh-vardhhan/Ludo` and retained under `apps/ludo_app/lib/features/game/game_engine`. Product UI, pure game-domain rules, persistence, networking and server authority are outside the renderer. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before commercial distribution.

## Implemented foundations

- Persian RTL onboarding, lobby, offline 2/4-player launch, shop and profile UI.
- Original Flame component renderer and animations retained rather than rewritten.
- Riverpod composition, Dio refresh-token interceptor, encrypted token storage, Hive offline snapshot repository, and Socket.IO matchmaking client.
- Server-generated dice, turn/movement/capture/winner validation, optimistic game versions, Redis distributed locks, reconnectable snapshots and atomic winner rewards.
- Coalesced differential Flame synchronization with offline-parity movement animations (per-cell hops, out-of-base launch, capture walk-home, single-move auto-play), cached static board rendering and deterministic teardown to prevent animation backlogs, effect accumulation and retained game memory.
- Username/email registration, password login and SMTP recovery, plus optional guest identity; JWT access tokens, rotating refresh tokens, live-session heartbeat, device session revocation, roles and bans.
- Coin ledger, daily/admin/game rewards, inventory, backend-controlled shop, VIP reward multiplier, one-Fattah-per-game enforcement and atomic inventory decrement.
- Fail-closed Bazaar/Myket receipt verifier boundary, receipt hashing, provider transaction uniqueness and server-only entitlement fulfillment.
- Predefined quick chat with an in-match Persian picker, reactions and server cooldown; no free-text transport.
- Two/four-player matchmaking, private invitation-code rooms, turn deadlines, explicit forfeit and reconnect grace handling.
- Functional profile editing, inventory/equip, transaction history, local settings and support tickets.
- Admin APIs and functional management forms for users, rewards, products, VIP, quick chat and support, plus payments and analytics.
- Swagger, initial SQL migration, seed data, containers, CI, rate limiting, DTO validation and dependency audit.

## Local start

Prerequisites: Node 22.12+, Docker, and Flutter 3.29+.

```bash
cp apps/api/.env.example apps/api/.env
# Replace JWT secrets and ADMIN_PASSWORD in apps/api/.env.
docker compose up -d postgres redis
npm ci
npm run db:generate
npm run db:migrate
npm run db:seed
npm run dev:api
npm run dev:admin
```

- API: `http://localhost:3001/api/v1`
- Swagger: `http://localhost:3001/docs`
- Admin: `http://localhost:3000`

Run mobile:

```bash
cd apps/ludo_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001/api/v1 \
  --dart-define=SOCKET_BASE_URL=http://10.0.2.2:3001
```

For backend-free offline testing:

```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

## Verification

```bash
npm audit               # expected: 0 known vulnerabilities
npm run lint
npm test
npm run build
cd apps/ludo_app && flutter analyze && flutter test
```

Node builds and authoritative-engine tests are covered in CI. Android release signing, each marketplace's native billing SDK, production provider credentials, privacy/legal content, load testing and external security review remain release-environment responsibilities; they cannot be safely embedded in source control.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [API and real-time protocol](docs/API.md)
- [Database](docs/DATABASE.md)
- [Security model](docs/SECURITY.md)
- [Deployment and release](docs/DEPLOYMENT.md)
