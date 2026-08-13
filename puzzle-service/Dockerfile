# Puzzle Service Dockerfile (multi-stage, optimized)
FROM python:3.11-slim AS builder
WORKDIR /app

# Install system deps required for some Python packages (kept minimal)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./

# Create virtual environment and install dependencies into it
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

FROM python:3.11-slim
WORKDIR /app

# Copy virtualenv from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --from=builder /app /app


ENV PORT=3002

EXPOSE 3002

# Use gunicorn for production-grade serving
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:3002", "app:app"]
