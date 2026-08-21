# Database

The canonical schema is `apps/api/prisma/schema.prisma`; the initial PostgreSQL migration is under `prisma/migrations`.

## Main aggregates

- **User / RefreshSession / PasswordResetToken**: username/email credentials, bcrypt password hash, role/status, balances, VIP expiration, revocable live sessions and single-use recovery codes.
- **Game / GameParticipant**: durable authoritative JSON snapshot plus indexed relational participants, winner and results.
- **Item / Inventory**: backend-controlled catalog and per-user quantity/equip state.
- **WalletTransaction**: append-only audit ledger with globally unique idempotency key. `User.coinBalance` is the fast materialized balance.
- **Payment / VipPurchase**: hashed receipt identity, verified provider transaction and entitlement history.
- **FattahUsage**: unique game/user usage proof in addition to snapshot state.
- **QuickChat**: the only chat content accepted by the real-time server.
- **SupportTicket**: player support requests, status and staff response history.
- **AdminAudit / AppSetting**: privileged action trail and runtime commercial configuration.
- **Game.roomCode**: unique invitation code for waiting private rooms.

## Consistency rules

Balances and entitlements mutate inside database transactions. Game updates use optimistic `version` checks in addition to a distributed lock. Winner, score, balance and wallet ledger are committed atomically. Unique constraints prevent duplicate receipt use, duplicate daily rewards, duplicate game participation and repeated Fattah use.

Do not edit a balance directly. Administrative rewards must call the wallet service so the ledger and audit trail remain complete.

## Operations

```bash
npm run db:generate
npm run db:migrate
npm run db:seed
```

Run migrations as a single deployment job before scaling new API replicas. Take a snapshot first, test downgrade/forward recovery in staging, and retain PITR logs. Seed is idempotent but requires `ADMIN_PASSWORD` (10+ characters); rotate that password after initial SSO/identity-proxy setup.
