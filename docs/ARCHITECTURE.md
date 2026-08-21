# Architecture

## Trust boundaries

The mobile app is an untrusted renderer and command issuer. It never supplies a dice result, score, reward amount, purchase price, VIP duration or entitlement. Online state transitions happen only in `LudoEngine` on the API. PostgreSQL is the durable source of truth; Redis is used for locks, queues, presence and hot snapshots.

```text
Flutter / Flame
  ├─ offline domain + Hive snapshots (local games only)
  └─ Dio / Socket.IO commands
             │ TLS
NestJS API ──┼─ Auth / DTO / rate-limit boundary
             ├─ Matchmaking queue (Redis)
             ├─ per-game distributed lock (Redis)
             ├─ authoritative pure rules engine
             ├─ optimistic version + transaction (PostgreSQL)
             └─ broadcast accepted snapshot (Socket.IO)

Next.js Admin ── httpOnly cookie BFF ── role-protected Admin API
```

## Mobile layers

- `core`: configuration, theming, auth-aware HTTP client and global providers.
- `features/*/domain`: immutable entities and rules without Flutter/Flame imports.
- `features/*/data`: API, Socket.IO, Hive and marketplace boundaries.
- `features/*/presentation`: Persian RTL screens and Riverpod controllers.
- `features/game/game_engine`: Flame visual components imported from the foundation repository. This layer animates game state; online authority stays on the server.

Offline random dice and local state are allowed only for pass-and-play. Offline saves are JSON snapshots in a Hive box. Online snapshots include monotonically increasing versions so late or duplicated messages can be ignored by the client.

## Online command lifecycle

1. Authenticated socket subscribes to `game:{uuid}`; membership is checked against PostgreSQL.
2. Matched players enter `WAITING_PLAYERS`; the turn clock starts only after every required socket subscribes. The client then sends intents (`game:roll`, `game:move`, `game:fattah`) without results.
3. API acquires `lock:game:{uuid}` using a tokenized Redis lock.
4. API reads the latest snapshot, checks actor/turn/phase and applies pure rules.
5. PostgreSQL updates only when `version = expectedVersion`; rewards and completion are in the same transaction.
6. Redis cache is replaced and the accepted snapshot is broadcast to the room.
7. On reconnect, the client discovers resumable matches through `GET /games/active/me`, calls `game:subscribe`, and replaces local online state. Duplicate device sockets are accounted for before a player is marked disconnected.
8. The Flutter state synchronizer coalesces superseded snapshots, animates only changed pieces in parallel, and continues after animation errors instead of poisoning the update queue.

Turn deadlines are indexed in a Redis sorted set, so lifecycle workers process only due matches rather than loading every active game every five seconds.

A command cannot be replayed against an old version. Purchase and wallet mutations use unique idempotency keys.

## Scale model

API instances are stateless except for active Socket.IO connections. PostgreSQL, Redis and object/CDN storage (for avatars) are external. The official Socket.IO Redis adapter now provides cross-instance rooms and broadcasts; sticky WebSocket connections are still required at the load balancer. Matchmaking ZSET operations and game locks already use Redis; at higher throughput, move match creation to a BullMQ worker and use a transactional outbox for analytics/event delivery.

Recommended initial production topology:

- 2+ API replicas across failure domains.
- Managed PostgreSQL with PITR, connection pooling and a read replica for analytics.
- Redis primary/replica with persistence and eviction disabled for lock/queue keys.
- 2 admin replicas behind SSO/VPN or an identity-aware proxy.
- CDN/object storage for signed avatar uploads; never proxy arbitrary user URLs.

## Gameplay invariants

- Token progress: `-1` base, `0..50` shared loop, `51..55` home lane, `56` finished.
- Base exit requires six; finish requires exact roll.
- Global cells use team offsets and safe-cell capture protection.
- Only current player may roll/move/use Fattah.
- Three consecutive sixes forfeit the turn.
- Fattah is limited by both snapshot flag and unique `(gameId,userId)` database constraint.
- Winner reward is 100 coins, doubled only when backend VIP expiration is in the future.
