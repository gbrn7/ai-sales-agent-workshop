# ==============================================================================
# Multi-stage Dockerfile for Glowria AI Sales Agent
# Compatible with Docker and Podman (Rootless)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Builder (Install dependencies via uv)
# ------------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /app

# Ambil binary uv dari image resmi astral-sh untuk instalasi cepat
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Salin manifest dependensi
COPY pyproject.toml requirements.txt uv.lock* ./

# Buat virtual environment mandiri dan install dependencies
ENV UV_COMPILE_BYTECODE=1
RUN uv venv /app/.venv && \
    uv pip install --no-cache -r requirements.txt

# ------------------------------------------------------------------------------
# Stage 2: Runner (Minimal runtime image)
# ------------------------------------------------------------------------------
FROM python:3.12-slim AS runner

WORKDIR /app

# Install curl untuk healthcheck container
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Salin virtual environment dari builder stage
COPY --from=builder /app/.venv /app/.venv

# Siapkan direktori persistensi untuk data database SQLite dan media customer
RUN mkdir -p /app/data /app/media

# Konfigurasi environment runtime
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="sqlite:///app/data/clinic.db" \
    PORT=8000

# Salin source code aplikasi
COPY database.py agent.py memory.py tools.py whatsapp.py cli.py main.py ./
COPY prompts/ ./prompts/
COPY routes/ ./routes/
COPY templates/ ./templates/

# Port FastAPI Webhook & Dashboard
EXPOSE 8000

# Pemeriksaan kesehatan container
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Perintah default menjalankan server Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
