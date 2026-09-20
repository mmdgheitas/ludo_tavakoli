FROM node:22-bookworm-slim AS builder
WORKDIR /workspace
RUN apt-get update && apt-get install -y --no-install-recommends openssl && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/admin/package.json apps/admin/package.json
RUN npm ci
COPY apps/api apps/api
RUN npm run prisma:generate --workspace=@manche-irani/api && npm run build --workspace=@manche-irani/api

FROM node:22-bookworm-slim AS runtime
WORKDIR /workspace
ENV NODE_ENV=production
RUN apt-get update && apt-get install -y --no-install-recommends openssl dumb-init && rm -rf /var/lib/apt/lists/*
COPY --from=builder /workspace/package.json /workspace/package-lock.json ./
COPY --from=builder /workspace/node_modules ./node_modules
COPY --from=builder /workspace/apps/api/package.json ./apps/api/package.json
COPY --from=builder /workspace/apps/api/dist ./apps/api/dist
COPY --from=builder /workspace/apps/api/prisma ./apps/api/prisma
COPY --from=builder /workspace/apps/api/prisma.config.ts ./apps/api/prisma.config.ts
USER node
EXPOSE 3001
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "apps/api/dist/main.js"]
