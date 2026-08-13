#!/bin/bash

# Start Database via Docker (Assumes docker-compose is installed or uses docker compose)
echo "Starting Database via Docker..."
if command -v docker-compose &> /dev/null; then
    docker-compose up -d
else
    docker compose up -d
fi

echo "Waiting for database to initialize (15s)..."
sleep 15

# Auth Service
echo "Starting Auth Service (Port 3001)..."
cd auth-service
npm install
npm start &
cd ..

# Leaderboard Service
echo "Starting Leaderboard Service (Port 3003)..."
cd leaderboard-service
npm install
npm start &
cd ..

# Puzzle Service
echo "Starting Puzzle Service (Port 3002)..."
cd puzzle-service
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
python app.py &
deactivate
cd ..

# Frontend
echo "Starting Frontend (Port 5173)..."
cd frontend
npm install
npm run dev &
cd ..

echo "All services have been started locally!"
echo "To stop them, press Ctrl+C, then you can run 'pkill node' and 'pkill python' if needed."
wait
