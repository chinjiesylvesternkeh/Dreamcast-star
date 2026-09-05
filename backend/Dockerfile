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

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8000/healthz || exit 1

CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-", \
     "--timeout", "60"]
