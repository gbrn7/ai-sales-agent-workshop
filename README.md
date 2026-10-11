# 🌸 AI Sales Agent Workshop (Python & FastAPI Edition)

Repositori workshop resmi implementasi **AI Sales Agent** (Gita — *Customer Care & Sales Specialist* untuk **Glowria Aesthetic Clinic**) berbasis **Python**, framework **FastAPI**, ORM **SQLModel**, dan **Google GenAI SDK**.

Aplikasi ini menyajikan arsitektur agen percakapan kelas produksi (*production-grade conversational agent*) yang terintegrasi langsung dengan WhatsApp: otomatisasi konsultasi perawatan, kalkulasi kapasitas dan reservasi treatment, analisis gambar multimodal, hingga sistem serah terima ke CS manusia (*human handover*).

---

## 🌟 Fitur Utama

- **🧠 Otak AI Gemini dengan Multi-Turn Tool Calling**:
  - Menggunakan SDK resmi [`google-genai`](https://pypi.org/project/google-genai/) dengan model `gemini-3.1-flash-lite`.
  - Dilengkapi 6 tool bisnis klinik: `search_treatments`, `check_availability`, `book_appointment`, `cancel_booking`, `get_customer_bookings`, dan `transfer_to_human`.
  - **Multimodal Vision**: Mampu menganalisis foto kulit wajah yang dikirim customer via WhatsApp untuk memberikan rekomendasi treatment yang relevan.
- **📅 Engine Booking Berbasis Kapasitas Atomik**:
  - Algoritma slot klinik otomatis berdasarkan kapasitas 3 perawat paralel dan durasi perawatan (default 90 menit).
  - Pengecekan collision atomik untuk mencegah *double-booking*.
- **💬 Integrasi WhatsApp Realistis (Evolution API)**:
  - **Debounce Buffer (8 Detik)**: Menampung pesan beruntun dari customer yang mengetik terpotong-potong sebelum diproses ke LLM.
  - **Bubble Splitting (`[NEXT]`)**: Memecah balasan panjang menjadi gelembung pesan bertahap agar terasa seperti mengetik dengan manusia.
  - **Typing Indicator**: Simulasi penundaan mengetik proporsional dengan panjang teks balasan.
  - **Handover Otomatis (`[HANDOVER]`)**: Deteksi otomatis permintaan bantuan manusia atau komplain keras yang langsung mematikan AI untuk nomor tersebut.
- **🖥️ Dashboard Admin & Human-in-the-Loop**:
  - Live dashboard berbasis web (`/dashboard`) untuk memantau histori percakapan.
  - Saklar manual *Takeover Mode* (AI On/Off) per customer.
  - Kirim pesan manual dan pembaruan status reservasi booking.
- **🗄️ Database & Storage Fleksibel**:
  - **SQLModel** (SQLAlchemy + Pydantic) dengan database bawaan **SQLite** (mode WAL) atau **PostgreSQL**.
  - Dual storage untuk gambar: **Cloudflare R2** (S3-compatible) dengan auto fallback ke penyimpanan lokal (`media/`).
- **💻 Interactive CLI Simulator**:
  - Pengujian langsung di terminal (`python cli.py`) tanpa perlu setup WhatsApp gateway atau ngrok.
- **🐳 Multi-Container Ready (Docker & Podman)**:
  - Konfigurasi multi-service di [`compose.yaml`](./compose.yaml).
  - Helper script cerdas [`container.sh`](./container.sh) dengan auto-detection Docker Engine dan Podman (khususnya Rootless Linux).

---

## 🏗️ Gambaran Arsitektur Sistem

```
WhatsApp Customer
       │ (pesan teks / gambar)
       ▼
Evolution API ────────► POST /webhook (FastAPI)
                              │
                              ▼
                     Debounce Buffer (8s per nomor)
                              │ (setelah jeda mengetik selesai)
                              ▼
                   process_buffered_messages
                    ┌─────────┴─────────┐
                    ▼                   ▼
            Sliding Memory      Agent Core Loop (Gemini)
           (riwayat & status)           │
                                        ├─► Multimodal Vision (Analisis Foto Kulit)
                                        ├─► 6 Business Tools (SQLModel DB)
                                        ▼
                                  Respon AI
                                        │
                         Deteksi [HANDOVER] (Takeover Switch)
                                        │
                               Bubble Split ([NEXT])
                                        │
                                        ▼
WhatsApp Customer ◄──── Evolution API (SendReply)
```

Untuk diagram visual arsitektur lengkap beresolusi tinggi, lihat [arsitektur-day1.svg](./arsitektur-day1.svg).

---

## 📂 Struktur Direktori

```
AI-Sales-Agent-Workshop/
├── main.py                   # FastAPI Webhook, orchestrator debounce, & lifespan
├── agent.py                  # Gemini GenAI SDK agent loop, function calling, & vision
├── cli.py                    # Terminal simulator WhatsApp interaktif
├── database.py               # SQLModel skema 7 tabel & database seeder
├── memory.py                 # Sliding window history memory & state takeover
├── tools.py                  # 6 Tools bisnis klinik & booking engine
├── whatsapp.py               # Klien Evolution API, media downloader, & bubble sender
├── routes/
│   └── dashboard.py          # Route & API endpoints untuk web dashboard admin
├── modules/                  # 7 Modul pembelajaran workshop (00 s.d. 06)
├── prompts/
│   └── system.md             # System prompt lengkap persona Gita & SOP klinik
├── templates/                # Template HTML Jinja2 untuk Admin Dashboard
├── media/                    # Direktori penyimpanan file gambar lokal
├── container.sh              # Skrip helper container otomatis (Docker / Podman)
├── compose.yaml              # Spesifikasi multi-service compose
├── Dockerfile                # Docker container build specification
├── pyproject.toml            # Definisi dependensi Python (kompatibel uv / pip)
└── requirements.txt          # Daftar dependensi pip konvensional
```

---

## 🚀 Panduan Memulai

### 1. Prasyarat
- **Python 3.10+** (direkomendasikan 3.12).
- Paket manager modern [`uv`](https://docs.astral.sh/uv/) (sangat disarankan) atau `pip`.
- API Key Google Gemini dari [Google AI Studio](https://aistudio.google.com/).

---

### 2. Konfigurasi Lingkungan (`.env`)

Salin file `.env.example` ke `.env`:

```bash
cp .env.example .env
```

Lengkapi variabel penting di `.env`:
```dotenv
GEMINI_API_KEY=AIzaSy...                # API key Google Gemini
GEMINI_MODEL=gemini-3.1-flash-lite       # Model default
AI_NAME=Gita
COMPANY_NAME=Glowria Aesthetic Clinic
DATABASE_URL=sqlite:///data/clinic.db   # Atau PostgreSQL URI
BUFFER_SECONDS=8                        # Waktu tunggu debounce buffer
```

---

### 3. Menjalankan Secara Lokal (Native Python)

#### Menggunakan `uv` (Direkomendasikan):
```bash
# 1. Install dependensi
uv sync

# 2. Jalankan Server Web (FastAPI)
uv run uvicorn main:app --reload --port 8000
```

#### Menggunakan Virtualenv Tradisional:
```bash
# 1. Buat virtual environment
python3 -m venv .venv
source .venv/bin/activate

# 2. Install dependensi
pip install -r requirements.txt

# 3. Jalankan Server Web
uvicorn main:app --reload --port 8000
```

Akses aplikasi di browser:
- **Admin Dashboard**: [http://localhost:8000/dashboard](http://localhost:8000/dashboard)
- **Health Check**: [http://localhost:8000/health](http://localhost:8000/health)

---

### 4. Menjalankan Simulator CLI (Testing Tanpa WhatsApp)

Uji kemampuan percakapan Gita, tool calling booking, dan respons konsultasi langsung dari terminal:

```bash
# Menggunakan uv
uv run python cli.py

# Atau dengan venv aktif
python cli.py
```

---

### 5. Menjalankan via Container (Docker & Podman)

Gunakan skrip pembantu [`container.sh`](./container.sh) untuk kemudahan manajemen kontainer:

```bash
# Bantuan dan daftar perintah
./container.sh help

# 1. Build image container
./container.sh build

# 2. Jalankan Sales Agent saja (port 8000)
./container.sh up

# 3. Jalankan Full Stack (Sales Agent + Evolution WhatsApp lokal di port 8080)
./container.sh up:full

# 4. Jalankan Sales Agent + PostgreSQL lokal
./container.sh up:postgres

# 5. Jalankan SEMUA service (Sales Agent + Evolution API + PostgreSQL + Redis)
./container.sh up:all

# 6. Buka Simulator CLI di dalam container
./container.sh cli

# 7. Pantau logs container
./container.sh logs

# 8. Cek status container
./container.sh status

# 9. Hentikan container
./container.sh down
```

Untuk detail teknis kontainerisasi dan panduan Rootless Podman, baca [docs/CONTAINER.md](./docs/CONTAINER.md).

---

## 🌐 Endpoint HTTP Utama

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/` | Redirect langsung ke `/dashboard` |
| `GET` | `/dashboard` | Antarmuka web Admin Dashboard untuk monitoring chat |
| `GET` | `/health` | Pemeriksaan kesehatan aplikasi dan status buffer |
| `POST` | `/webhook` | Penerima event pesan masuk dari Evolution API |
| `GET` | `/media/{fname}` | Proxy penyajian gambar dari R2 / lokal |
| `GET` | `/dashboard/api/config` | Konfigurasi klinik & status R2 |
| `GET` | `/dashboard/api/conversations` | Daftar riwayat chat seluruh customer |
| `GET` | `/dashboard/api/bookings` | Rekapitulasi reservasi booking perawatan |
| `POST` | `/dashboard/api/conversations/{phone}/toggle` | Saklar manual aktivasi / nonaktifasi AI |
| `POST` | `/dashboard/api/send` | Pengiriman chat manual dari admin |

---

## 📚 Roadmap Modul Pembelajaran

Repositori ini dilengkapi tutorial terstruktur di direktori [`modules/`](./modules/README.md):

| Modul | Dokumen | Topik Pembahasan |
|---|---|---|
| **00** | [Pengenalan Arsitektur & Lingkungan Belajar](./modules/00-pengenalan-arsitektur-dan-lingkungan.md) | Mental model agen, instalasi, dan sanity check API Gemini |
| **01** | [Database & Data Modeling](./modules/01-database-dan-data-modeling.md) | Skema 7 entitas SQLModel, relasi, dan database seeding |
| **02** | [Prompt Engineering & Guardrails](./modules/02-prompt-engineering-dan-guardrails.md) | Persona Gita, tone suara 5/10, hard rules, dan token kontrol |
| **03** | [Function Calling & Booking Engine](./modules/03-function-calling-dan-booking-engine.md) | Deklarasi Tool Gemini, algoritma overlap booking kapasitas 3 perawat |
| **04** | [The Agent Core Loop & Multimodal Vision](./modules/04-agent-core-dan-gemini-loop.md) | Multi-turn reasoning loop, eksekusi tool berulang, input gambar foto |
| **05** | [Session State, Debounce Webhook & Storage](./modules/05-webhook-debounce-dan-memory.md) | Buffer debounce 8 detik, sliding window memory, Cloudflare R2 |
| **06** | [WhatsApp Integration, CLI & Dashboard](./modules/06-whatsapp-integration-dan-dashboard.md) | Integrasi Evolution API, simulator CLI, dan Live Admin Dashboard |

---

## 📄 Lisensi & Kontribusi

Proyek ini ditujukan untuk materi pembelajaran dan referensi arsitektur production-ready AI Sales Agent. Kontribusi, perbaikan, dan issue sangat dipersilakan!
