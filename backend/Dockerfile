# --- Build stage ---
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# --- Runtime stage ---
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r dreamcast && useradd -r -g dreamcast dreamcast

WORKDIR /app

COPY --from=builder /root/.local /home/dreamcast/.local
COPY app ./app
COPY alembic.ini ./alembic.ini
COPY alembic ./alembic

ENV PATH=/home/dreamcast/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN chown -R dreamcast:dreamcast /app
USER dreamcast

# Cloud Run injects PORT (8080); Docker Compose / Kubernetes use the 8000 default.
ENV PORT=8000 \
    WEB_CONCURRENCY=2

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f "http://localhost:${PORT}/healthz" || exit 1

# --timeout 180: detailed dream readings can take well over a minute to write.
CMD exec gunicorn app.main:app -w "${WEB_CONCURRENCY}" -k uvicorn.workers.UvicornWorker \
    --bind "0.0.0.0:${PORT}" --timeout 180 --graceful-timeout 30 \
    --access-logfile - --error-logfile -
