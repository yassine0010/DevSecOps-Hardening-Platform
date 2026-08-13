# MindGrid (DevSecOps Project)

## Project Overview

MindGrid is a small microservices web application composed of a React frontend and three backend services (Auth, Leaderboard, Puzzle) backed by a MySQL database. Services are implemented in Node.js (Express) and Python (Flask) and are orchestrated for development using Docker Compose.

## Components

- **Frontend**: React (v19) app built with Vite. Key libs: `axios`, `react-router-dom`.
  - Location: `frontend/`

- **Auth Service**: Node.js + Express handling user registration, login, and JWT authentication. Uses `bcrypt`, `jsonwebtoken`, and `mysql2`.
  - Location: `auth-service/` (`server.js`, `package.json`)

- **Leaderboard Service**: Node.js + Express exposing leaderboard-related APIs and interacting with the same MySQL DB.
  - Location: `leaderboard-service/` (`server.js`, `package.json`)

- **Puzzle Service**: Python Flask API serving puzzle data and submission endpoints. Uses `PyJWT`, `Flask-Cors`, and `mysql-connector-python`.
  - Location: `puzzle-service/` (`app.py`, `requirements.txt`)

- **Database**: MySQL 8.0 container started via `docker-compose.yml`. Init SQL scripts in `db/schema.sql` and `db/seed.sql`.

## Architecture (high level)

- The frontend is a single-page React app that calls backend services over HTTP.
- The Auth service issues and verifies JWTs; other services expect JWTs for protected endpoints.
- All services use the MySQL database for persistence.
- Docker Compose provides a local MySQL instance with initialization SQL mounted from `./db`.

Simplified flow:

Frontend -> Auth Service (login/register, get JWT) -> Puzzle/Leaderboard Services (JWT-protected API) -> MySQL

## Run Locally (developer quickstart)

Prerequisites:
- Docker & Docker Compose
- Node.js & npm (for frontend and Node services)
- Python 3.11+ and `pip` (for puzzle service)

Commands (example):

```zsh
# Start database container
docker-compose up -d

# Frontend
cd frontend
npm install
npm run dev

# Auth and Leaderboard (Node services)
cd ../auth-service
npm install
npm start

cd ../leaderboard-service
npm install
npm start

# Puzzle service (Python)
cd ../puzzle-service
python -m pip install -r requirements.txt
python app.py
```

Notes:
- The DB in `docker-compose.yml` maps host port `3307` to container `3306`.
- If you change DB credentials or ports, update service `.env` files or the `SECRETS.md` as appropriate.

## Important Environment Variables

- For Node services (`auth-service`, `leaderboard-service`):
  - `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — MySQL connection
  - `JWT_SECRET` — secret key for signing tokens

- For Puzzle service (Flask):
  - analogous `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB`
  - `JWT_SECRET` or `PYJWT_SECRET`
  - `SHARED_SERVICE_KEY` — static secret shared between services for service-to-service authentication (header `X-Service-Key`).

See `SECRETS.md` for where secrets should be stored locally (do not commit secrets).

## Ports (defaults used in repo)

- Frontend dev server: typically `vite` default port (see `frontend/package.json` scripts)
- MySQL container: host `3307` -> container `3306` (see `docker-compose.yml`)
- Node/Flask services: ports are defined in each `server.js` / `app.py` file; check those files for exact ports.

## Security & Secrets

- Secrets should never be committed. Use the provided `SECRETS.md` to store local env values and add it to `.gitignore` if appropriate.
- JWTs are used for auth; ensure `JWT_SECRET` is strong and rotated when needed.
- Dependencies should be periodically scanned for vulnerabilities (`npm audit`, `safety`, or SCA tools).

## Project Structure (top-level)

```
docker-compose.yml
SECRETS.md
start_services.sh
VULNERABILITIES.md
auth-service/
leaderboard-service/
puzzle-service/
frontend/
db/
```

## Where to look for endpoints

- `auth-service/server.js` — auth endpoints (login/register, token endpoints)
- `leaderboard-service/server.js` — leaderboard endpoints
- `puzzle-service/app.py` — puzzle endpoints
- `frontend/src/pages/*` — React pages and how frontend calls backend

## Next steps / Suggestions

- Run the services and verify endpoints with Postman or curl.
- Add a `docker-compose` service for each backend to standardize local orchestration.
- Add a small README in each service describing its env vars and ports.

If you want, I can open each service file and extract the exact endpoints and env var names to include here.
