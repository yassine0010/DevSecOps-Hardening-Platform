FROM 192.168.0.154:8082/node:18-bullseye-slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm config set registry http://192.168.0.154:8081/repository/npm-proxy/ && \
    npm install && \
    npm ci --production=false

COPY . .
RUN npm run build --if-present || true

FROM 192.168.0.154:8082/node:18-bullseye-slim
WORKDIR /app

COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["node", "server.js"]