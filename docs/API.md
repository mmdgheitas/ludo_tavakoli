# API and real-time protocol

Base path: `/api/v1`. Interactive OpenAPI is served at `/docs`.

## HTTP summary

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/guest`, `/auth/refresh`, `/auth/admin/login`, `/auth/logout` |
| User | `GET/PATCH /users/me` |
| Games | `POST /games/rooms`, `POST /games/rooms/join`, `GET /games/active/me`, `POST /games/:id/join`, `GET /games/:id/state`, `POST /games/:id/roll`, `/move`, `/fattah`, `/forfeit` |
| Wallet | `GET /wallet/transactions`, `POST /wallet/daily-reward` |
| Shop | `GET /shop/items`, `GET /shop/inventory`, `POST /shop/purchase` |
| VIP/Fattah | `GET /vip/offer`, `/vip/status`, `/fattah/balance` |
| Payments | `POST /payments/verify`, `GET /payments` |
| Chat | `GET /chat/messages` |
| Support | `GET/POST /support/tickets` |
| Admin | `/admin/users`, `/games`, `/transactions`, `/items`, `/payments`, `/vip-purchases`, `/quick-chat` |
| Analytics | `GET /analytics/dashboard`, `/analytics/trends` |

Protected HTTP routes use `Authorization: Bearer <accessToken>`. Access tokens are short-lived. Refresh tokens rotate and are stored server-side only as SHA-256 hashes.

## Socket authentication

Connect over WebSocket transport and provide `{ auth: { token: accessToken } }`. An invalid, expired, banned or wrong-type token is disconnected. The mobile client reconnects with bounded backoff and must refresh the HTTP token before creating a new socket when needed.

## Client events

| Event | Payload | Meaning |
|---|---|---|
| `matchmaking:join` | `{ mode: "ONLINE_2P" | "ONLINE_4P" }` | Enter queue |
| `matchmaking:leave` | `{}` | Leave queue |
| `game:subscribe` | `{ gameId }` | Verify membership, join room, receive snapshot |
| `game:roll` | `{ gameId }` | Request server dice roll |
| `game:move` | `{ gameId, tokenIndex: 0..3 }` | Request legal movement |
| `game:fattah` | `{ gameId, targetUserId, targetTokenIndex }` | Request one rocket attack |
| `game:forfeit` | `{ gameId }` | Forfeit the match |
| `chat:send` | `{ gameId, messageId }` | Send an active predefined message |
| `presence:heartbeat` | `{}` | Extend online presence |

## Server events

- `matchmaking:queued`, `matchmaking:matched`, `matchmaking:error`
- `game:state`: complete authoritative snapshot/result; clients discard lower versions.
- `game:ack`, `game:error`
- `chat:message`, `chat:error`
- `presence:ack`

No event accepts dice values, balances, prices, scores or winner declarations.

## Payment contract

`POST /payments/verify` accepts provider, SKU, opaque purchase token and provider transaction ID. The API hashes tokens, looks up server-controlled catalog price/value, verifies against an HTTPS provider adapter, compares transaction IDs, enforces global uniqueness and fulfills in one database transaction. Missing provider configuration fails closed with 503. Never grant an entitlement in response to an on-device billing callback alone.
