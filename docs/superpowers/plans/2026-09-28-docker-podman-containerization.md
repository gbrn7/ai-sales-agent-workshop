# Setup Kontainerisasi Universal (Docker & Podman) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengimplementasikan setup kontainerisasi universal untuk AI Sales Agent Workshop yang dapat di-build dan dijalankan dengan mulus di runtime Docker maupun Podman (khususnya mode rootless di Linux) menggunakan spesifikasi `compose.yaml` modern, multi-stage Dockerfile, dan helper script `container.sh`.

**Architecture:** Menggunakan multi-stage Dockerfile (`python:3.12-slim` + `uv` binary) untuk build cepat dan image ramping. Konfigurasi Compose universal (`compose.yaml`) dengan profiles (`full` untuk Evolution API, `postgres` untuk DB produksi), volume flag `:z` untuk SELinux/Podman rootless compatibility, dan helper script `container.sh` untuk otomatisasi deteksi runtime aktif.

**Tech Stack:** Docker, Podman (Rootless), Docker Compose v2, Podman-Compose, Python 3.12, Uvicorn, FastAPI, SQLModel.

## Global Constraints

- Kompatibel 100% untuk Docker dan Podman (tanpa konfigurasi duplikat).
- Tidak memodifikasi logika bisnis Python yang sudah ada kecuali jika path volume database membutuhkan direktori penampung `/app/data`.
- Semua file konfigurasi diletakkan di root repositori `AI-Sales-Agent-Workshop/`.
- File panduan disimpan di `docs/CONTAINER.md`.

---

### Task 1: Membuat `.dockerignore`, `Dockerfile`, dan `Containerfile`

**Files:**
- Create: `AI-Sales-Agent-Workshop/.dockerignore`
- Create: `AI-Sales-Agent-Workshop/Dockerfile`
- Create: `AI-Sales-Agent-Workshop/Containerfile` (symlink ke `Dockerfile`)

**Interfaces:**
- Consumes: `pyproject.toml`, `requirements.txt`, `uv.lock`
- Produces: OCI image `ai-sales-agent` yang siap di-build dengan `docker build` atau `podman build`.

- [ ] **Step 1: Tulis `.dockerignore`**

Kecualikan berkas yang tidak dibutuhkan dalam image:
```gitignore
__pycache__/
*.pyc
*.pyo
*.pyd
.venv/
venv/
.git/
.gitignore
.env
.env.*
!.env.example
data/
clinic.db
media/
*.log
.pytest_cache/
tests/
modules/
docs/
```

- [ ] **Step 2: Tulis multi-stage `Dockerfile`**

```dockerfile
# Stage 1: Builder
FROM python:3.12-slim AS builder

WORKDIR /app

# Copy uv dari image resmi astral-sh
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

# Copy files dependensi
COPY pyproject.toml requirements.txt uv.lock* ./

# Install dependensi ke /app/.venv menggunakan uv
ENV UV_COMPILE_BYTECODE=1
RUN uv venv /app/.venv && \
    uv pip install --no-cache -r requirements.txt

# Stage 2: Runner
FROM python:3.12-slim AS runner

WORKDIR /app

# Install curl untuk healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy virtualenv dari builder
COPY --from=builder /app/.venv /app/.venv

# Siapkan direktori persistensi data dan media
RUN mkdir -p /app/data /app/media

# Environment variables
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DATABASE_URL="sqlite:///app/data/clinic.db" \
    PORT=8000

# Copy source code aplikasi
COPY database.py agent.py memory.py tools.py whatsapp.py cli.py main.py ./
COPY prompts/ ./prompts/
COPY routes/ ./routes/
COPY templates/ ./templates/

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 3: Buat symlink `Containerfile -> Dockerfile`**

Run: `ln -s Dockerfile AI-Sales-Agent-Workshop/Containerfile`

- [ ] **Step 4: Commit**

```bash
git -C AI-Sales-Agent-Workshop add .dockerignore Dockerfile Containerfile
git -C AI-Sales-Agent-Workshop commit -m "feat(container): add Dockerfile, Containerfile, and .dockerignore"
```

---

### Task 2: Membuat Spesifikasi `compose.yaml`

**Files:**
- Create: `AI-Sales-Agent-Workshop/compose.yaml`

**Interfaces:**
- Consumes: `Dockerfile`, `.env`
- Produces: Definisi orchestrasi multi-service yang mendukung `docker compose` dan `podman-compose`.

- [ ] **Step 1: Tulis berkas `compose.yaml`**

Mencakup:
- Service `app` (build `.`, port 8000, volume `./data:/app/data:z`, `./media:/app/media:z`, env_file `.env`).
- Service `evolution-api` (image `atendai/evolution-api:v1.8.2`, port 8080, profiles `["full", "whatsapp"]`).
- Service `postgres` (image `postgres:16-alpine`, port 5432, profiles `["postgres"]`).
- Volume deklarasi untuk persistensi instance evolution & postgres.

- [ ] **Step 2: Validasi sintaks compose**

Run: `docker compose config` atau `podman-compose config` untuk memastikan tidak ada kesalahan YAML.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add compose.yaml
git -C AI-Sales-Agent-Workshop commit -m "feat(container): add universal compose.yaml with profiles"
```

---

### Task 3: Membuat Helper Management CLI (`container.sh`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/container.sh`

**Interfaces:**
- Consumes: `compose.yaml`, `Dockerfile`
- Produces: Executable script `./container.sh` dengan subcommands `build`, `up`, `up:full`, `down`, `logs`, `cli`, `status`.

- [ ] **Step 1: Tulis skrip `container.sh`**

Logika:
- Deteksi runtime otomatis: cek `podman` vs `docker`.
- Deteksi compose tool: cek `podman compose`, `podman-compose`, `docker compose`, `docker-compose`.
- Handling subcommand:
  - `build`: build image
  - `up`: compose up -d (service app)
  - `up:full`: compose --profile full up -d (app + evolution-api)
  - `down`: compose down
  - `logs`: compose logs -f app
  - `cli`: jalankan `python cli.py` interaktif di dalam container
  - `status`: compose ps
  - `help`: petunjuk penggunaan

- [ ] **Step 2: Berikan permission executable (`chmod +x`)**

Run: `chmod +x AI-Sales-Agent-Workshop/container.sh`

- [ ] **Step 3: Uji help output skrip**

Run: `AI-Sales-Agent-Workshop/container.sh help`
Expected: Menampilkan daftar perintah yang tersedia.

- [ ] **Step 4: Commit**

```bash
git -C AI-Sales-Agent-Workshop add container.sh
git -C AI-Sales-Agent-Workshop commit -m "feat(container): add unified container.sh management script"
```

---

### Task 4: Menulis Dokumentasi Panduan (`docs/CONTAINER.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/docs/CONTAINER.md`

**Interfaces:**
- Consumes: `compose.yaml`, `Dockerfile`, `container.sh`
- Produces: Dokumentasi petunjuk lengkap menjalankan aplikasi dengan Docker dan Podman.

- [ ] **Step 1: Tulis isi `docs/CONTAINER.md`**

Mencakup:
1. Ringkasan arsitektur kontainer.
2. Persiapan: salin `.env.example` ke `.env` dan isi `GEMINI_API_KEY`.
3. Menjalankan dengan `container.sh` (jalan pintas termudah).
4. Menjalankan dengan `docker compose` murni.
5. Menjalankan dengan `podman` / `podman-compose` murni (catatan khusus rootless mode & SELinux).
6. Menggunakan Profiles (Full Stack vs Database PostgreSQL).
7. Troubleshooting umum: Permission denied pada host volume mount, port 8000/8080 sudah digunakan.

- [ ] **Step 2: Commit**

```bash
git -C AI-Sales-Agent-Workshop add docs/CONTAINER.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add container usage guide for Docker and Podman"
```

---

### Task 5: Build Image & Verifikasi Runtime

**Files:**
- Verify: Container image `ai-sales-agent:latest`, container healthcheck, volume persistence.

- [ ] **Step 1: Build image menggunakan container.sh / podman**

Run: `AI-Sales-Agent-Workshop/container.sh build`
Expected: Image berhasil di-build tanpa error.

- [ ] **Step 2: Jalankan container di background**

Run: `AI-Sales-Agent-Workshop/container.sh up`
Expected: Service `app` menyala di port 8000.

- [ ] **Step 3: Uji healthcheck & HTTP endpoint**

Run: `curl -I http://localhost:8000/`
Expected: HTTP 307 Temporary Redirect ke `/dashboard` atau HTTP 200.

- [ ] **Step 4: Verifikasi volume persistensi data**

Run: `ls -la AI-Sales-Agent-Workshop/data/`
Expected: File `clinic.db` dibuat dan diisi data seed oleh container.

- [ ] **Step 5: Hentikan container setelah pengujian**

Run: `AI-Sales-Agent-Workshop/container.sh down`
Expected: Container berhasil dihentikan.
