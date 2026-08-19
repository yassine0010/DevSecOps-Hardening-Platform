FROM 192.168.0.154:8082/node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm config set registry http://192.168.0.154:8081/repository/npm-proxy/ && \
    npm install
COPY . .
RUN npm run build

FROM 192.168.0.154:8082/nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]