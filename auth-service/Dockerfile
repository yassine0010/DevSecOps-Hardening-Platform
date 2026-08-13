# Auth Service Dockerfile (multi-stage, optimized)
FROM node:18-bullseye-slim AS builder
WORKDIR /app

# Install build dependencies for native modules, then remove lists to keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install dependencies based on package manifest first for caching
COPY package*.json ./
RUN npm install
RUN npm ci --production=false

# Copy source and run optional build (if present)
COPY . .
RUN npm run build --if-present || true

FROM node:18-bullseye-slim
WORKDIR /app

# Copy only the production-relevant files from builder (no double-copy)
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["node", "server.js"]
