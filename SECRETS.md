# Secrets Management

This document lists all the required secrets and environment variables for the MindGrid DevSecOps demo project.

**Note:** No actual values are stored here. In a real deployment, these should be securely managed via a secrets manager (e.g., AWS Secrets Manager, HashiCorp Vault) or CI/CD injected environment variables.

## auth-service
| Environment Variable | Purpose |
|----------------------|---------|
| `PORT` | The port the service runs on (e.g., 3001). |
| `DB_HOST` | Hostname of the MySQL database. |
| `DB_USER` | MySQL database username. |
| `DB_PASSWORD` | MySQL database password. |
| `DB_NAME` | MySQL database name. |
| `JWT_SECRET` | Secret key used to sign and verify JSON Web Tokens. |
| `SHARED_SERVICE_KEY` | Static secret used for service-to-service authentication (header `X-Service-Key`). |

## puzzle-service
| Environment Variable | Purpose |
|----------------------|---------|
| `PORT` | The port the service runs on (e.g., 3002). |
| `DB_HOST` | Hostname of the MySQL database. |
| `DB_USER` | MySQL database username. |
| `DB_PASSWORD` | MySQL database password. |
| `DB_NAME` | MySQL database name. |
| `JWT_SECRET` | Secret key used to verify JSON Web Tokens for authentication. |
| `SHARED_SERVICE_KEY` | Static secret used for service-to-service authentication (header `X-Service-Key`). |

## leaderboard-service
| Environment Variable | Purpose |
|----------------------|---------|
| `PORT` | The port the service runs on (e.g., 3003). |
| `DB_HOST` | Hostname of the MySQL database. |
| `DB_USER` | MySQL database username. |
| `DB_PASSWORD` | MySQL database password. |
| `DB_NAME` | MySQL database name. |
| `JWT_SECRET` | Secret key used to verify JSON Web Tokens for authentication. |
| `SHARED_SERVICE_KEY` | Static secret used for service-to-service authentication (header `X-Service-Key`). |

## frontend
| Environment Variable | Purpose |
|----------------------|---------|
| `FRONTEND_API_PREFIX` | Frontend uses a single-origin API prefix (default `/api`). The edge/proxy should route `/api/auth`, `/api/puzzle`, `/api/leaderboard` to their services. |
