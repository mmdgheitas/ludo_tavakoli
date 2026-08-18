FROM node:22-alpine AS builder
WORKDIR /workspace
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/admin/package.json apps/admin/package.json
RUN npm ci
COPY apps/admin apps/admin
RUN npm run build --workspace=@manche-irani/admin

FROM node:22-alpine AS runtime
WORKDIR /workspace
ENV NODE_ENV=production
COPY --from=builder /workspace/package.json /workspace/package-lock.json ./
COPY --from=builder /workspace/node_modules ./node_modules
COPY --from=builder /workspace/apps/admin/package.json ./apps/admin/package.json
COPY --from=builder /workspace/apps/admin/.next ./apps/admin/.next
COPY --from=builder /workspace/apps/admin/public ./apps/admin/public
USER node
EXPOSE 3000
CMD ["npm", "run", "start", "--workspace=@manche-irani/admin"]
