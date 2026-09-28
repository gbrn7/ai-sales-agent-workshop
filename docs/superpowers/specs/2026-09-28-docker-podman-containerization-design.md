# Desain Spesifikasi: Setup Kontainerisasi Universal (Docker & Podman)

- **Tanggal**: 2026-09-28
- **Topik**: Kontainerisasi Universal untuk AI Sales Agent Workshop (Docker & Rootless Podman)
- **Status**: Disetujui
- **Target Proyek**: `AI-Sales-Agent-Workshop/`

---

## 1. Latar Belakang & Tujuan

Project `AI-Sales-Agent-Workshop` membutuhkan setup kontainerisasi yang portabel, aman, dan mudah dijalankan di berbagai lingkungan (developer laptop, server Linux, maupun cloud). 

Kebutuhan utama:
1. **Dua Runtime Utama**: Berjalan tanpa kendala baik menggunakan **Docker Engine** (Docker Desktop / Docker CE) maupun **Podman** (khususnya mode *Rootless* umum di lingkungan Linux modern).
2. **Standard OCI & Compose Modern**: Menggunakan file `compose.yaml` (spesifikasi resmi terkini) yang didukung oleh `docker compose` maupun `podman-compose` / `podman compose`.
3. **Persistensi Data**: Menjaga data SQLite (`clinic.db`) dan folder `media/` tetap tersimpan secara persisten di host mesin pengembang.
4. **Full-Stack Fleksibel**: Menyediakan opsi menjalankan service pendukung (Evolution API untuk WhatsApp lokal dan PostgreSQL untuk pengujian database production) melalui *Compose Profiles*.
5. **Kemudahan Operasional**: Menyediakan skrip pembantu `container.sh` yang otomatis mendeteksi runtime kontainer aktif di sistem.

---

## 2. Struktur File Kontainerisasi

File-file baru yang akan ditambahkan ke repositori:

```
AI-Sales-Agent-Workshop/
├── Dockerfile              # Resep build multi-stage OCI (python:3.12-slim + uv)
├── Containerfile           # Symlink ke Dockerfile (standar OCI Podman)
├── .dockerignore           # Daftar exclude untuk optimasi build context
├── compose.yaml            # Spesifikasi Compose universal (app, evolution-api, postgres)
├── container.sh            # Skrip pembantu manajemen container lintas runtime
└── docs/
    └── CONTAINER.md        # Panduan komprehensif menjalankan di Docker & Podman
```

---

## 3. Rincian Teknis Dockerfile (`Dockerfile`)

### Arsitektur Multi-Stage Build
1. **Stage 1 (`builder`)**:
   - Base image: `python:3.12-slim`
   - Mengambil binary `uv` dari image resmi `ghcr.io/astral-sh/uv:latest` (`COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv`).
   - Menyalin file dependensi: `pyproject.toml`, `requirements.txt`, `uv.lock`.
   - Menginstal seluruh dependensi ke dalam virtual environment `/app/.venv` menggunakan `uv venv` dan `uv pip install`.
2. **Stage 2 (`runner`)**:
   - Base image: `python:3.12-slim`
   - Salin virtual environment `/app/.venv` dari builder stage.
   - Buat direktori data & media:
     `/app/data` (untuk SQLite `clinic.db`) dan `/app/media` (untuk file gambar customer).
   - Pastikan path eksekusi virtualenv aktif (`ENV PATH="/app/.venv/bin:$PATH"`).
   - Set environment default:
     `PYTHONUNBUFFERED=1`, `DATABASE_URL=sqlite:///app/data/clinic.db`.
   - Salin kode aplikasi: `main.py`, `agent.py`, `database.py`, `memory.py`, `tools.py`, `whatsapp.py`, `cli.py`, `prompts/`, `templates/`, `routes/`.
   - `EXPOSE 8000`.
   - `HEALTHCHECK`: memantau `curl -f http://localhost:8000/ || exit 1`.
   - `CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]`.

---

## 4. Rincian Teknis Compose (`compose.yaml`)

### Konfigurasi Services

#### 1. Service `app` (Utama / Default)
- **Build**: Context `.`, target runner.
- **Image**: `ai-sales-agent:latest`
- **Container Name**: `glowria-sales-agent`
- **Ports**: `"8000:8000"`
- **Env File**: `.env`
- **Environment**:
  - `DATABASE_URL=sqlite:///app/data/clinic.db` (bisa di-override jika menggunakan PostgreSQL).
  - `MEDIA_DIR=/app/media`
- **Volumes**:
  - `./data:/app/data:z`
  - `./media:/app/media:z`
  *(Penanda `:z` memastikan SELinux context relabeling bekerja di rootless Podman).*
- **Restart**: `unless-stopped`

#### 2. Service `evolution-api` (Profile: `full`, `whatsapp`)
- **Image**: `atendai/evolution-api:v1.8.2`
- **Container Name**: `evolution-api`
- **Ports**: `"8080:8080"`
- **Profiles**: `["full", "whatsapp"]`
- **Environment**:
  - `SERVER_URL=http://localhost:8080`
  - `AUTHENTICATION_API_KEY=${EVOLUTION_API_KEY:-global-api-key}`
- **Volumes**:
  - `evolution_instances:/evolution/instances:z`

#### 3. Service `postgres` (Profile: `postgres`)
- **Image**: `postgres:16-alpine`
- **Container Name**: `glowria-postgres`
- **Ports**: `"5432:5432"`
- **Profiles**: `["postgres"]`
- **Environment**:
  - `POSTGRES_DB=clinic`
  - `POSTGRES_USER=postgres`
  - `POSTGRES_PASSWORD=postgres`
- **Volumes**:
  - `postgres_data:/var/lib/postgresql/data:z`

---

## 5. Skrip Pembantu (`container.sh`)

Skrip pembantu otomatis mendeteksi apakah host menggunakan `docker` atau `podman`:
```bash
# Deteksi runtime
if command -v podman >/dev/null 2>&1; then
    CONTAINER_BIN="podman"
    if podman compose version >/dev/null 2>&1; then
        COMPOSE_BIN="podman compose"
    elif command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_BIN="podman-compose"
    fi
elif command -v docker >/dev/null 2>&1; then
    CONTAINER_BIN="docker"
    COMPOSE_BIN="docker compose"
fi
```

### Perintah yang Didukung:
- `./container.sh build` — Mem-build image aplikasi secara lokal.
- `./container.sh up` — Menjalankan service `app` di background (SQLite default).
- `./container.sh up:full` — Menjalankan service `app` + `evolution-api` (Profile `full`).
- `./container.sh down` — Menghentikan seluruh container dan network.
- `./container.sh logs` — Melihat live logs container `app`.
- `./container.sh cli` — Menjalankan `python cli.py` interaktif di dalam container aktif (`exec -it`).
- `./container.sh status` — Menampilkan status container dan healthcheck.

---

## 6. Verifikasi & Kriteria Penerimaan

1. **Build Test**:
   - `podman build -t ai-sales-agent:test .` (atau `docker build`) berhasil tanpa error.
2. **Run Test**:
   - Container menyala di port 8000 dan endpoint HTTP `/` (redirect ke `/dashboard`) merespons HTTP 200/307.
3. **Volume Persistence Test**:
   - File database SQLite tersimpan di direktori host `./data/clinic.db` saat pertama kali container boot dan `seed_db()` berjalan.
4. **Interactive CLI Test**:
   - `./container.sh cli` berhasil membuka interaktif CLI customer di dalam container.
