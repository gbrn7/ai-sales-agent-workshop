# Modul Pembelajaran AI Sales Agent Workshop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membuat seri modul pembelajaran terstruktur (8 dokumen markdown: 1 README roadmap navigasi + 7 modul progresif) di dalam folder `AI-Sales-Agent-Workshop/modules/` untuk membedah arsitektur, kode, dan operasional AI Sales Agent Glowria Aesthetic Clinic.

**Architecture:** Modul disusun dengan pendekatan Modular Component Journey (layer data -> layer prompt & tools -> agent loop & vision -> webhook & state debounce -> WhatsApp integration & live dashboard). Setiap modul memiliki anatomi baku: Tujuan Pembelajaran, Konsep & Mermaid Diagram, Bedah Kode Baris demi Baris, Hands-on Lab Mandiri, Pitfalls & Gotchas, dan Mini Challenge.

**Tech Stack:** Markdown (GitHub Flavored), Mermaid diagrams, Python 3.10+, FastAPI, Google GenAI SDK, SQLModel (SQLite/PostgreSQL), Evolution API.

## Global Constraints

- Semua berkas modul disimpan di dalam folder `AI-Sales-Agent-Workshop/modules/`.
- Penulisan dalam Bahasa Indonesia yang lugas, terstruktur, dan edukatif dengan istilah teknis tetap relevan.
- Setiap referensi kode harus 100% akurat dan mencerminkan kode aktual di dalam repositori `AI-Sales-Agent-Workshop`.
- Setiap modul wajib menyertakan hands-on lab mandiri yang dapat langsung diuji di terminal linux tanpa error.
- Tidak ada placeholder (TBD, TODO).

---

### Task 1: Scaffolding Folder & Hub Navigasi Belajar (`modules/README.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/README.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-09-28-ai-sales-agent-workshop-learning-modules-design.md`, `arsitektur-day1.svg`
- Produces: `modules/README.md` sebagai gerbang utama bagi pembelajar untuk menavigasi silabus modul 00 sampai 06.

- [ ] **Step 1: Buat folder `modules/` jika belum ada**

Run: `mkdir -p AI-Sales-Agent-Workshop/modules`

- [ ] **Step 2: Tulis konten `modules/README.md`**

Buat file `AI-Sales-Agent-Workshop/modules/README.md` dengan isi:
- Penjelasan umum tentang Glowria AI Sales Agent.
- Diagram alur Mermaid atau referensi ke `../arsitektur-day1.svg`.
- Tabel Roadmap Belajar (Modul 00 s/d 06, File Terkait, Peran dalam Sistem, Estimasi Waktu).
- Prasyarat pengetahuan & sistem (Python 3.10+, Gemini API Key, Git).
- Petunjuk cara menggunakan modul belajar.

- [ ] **Step 3: Verifikasi file terbuat dan tautan relatif valid**

Run: `ls -la AI-Sales-Agent-Workshop/modules/README.md`
Expected: File ada dan berukuran > 1 KB.

- [ ] **Step 4: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/README.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add modules README and learning roadmap"
```

---

### Task 2: Modul 00: Pengenalan Arsitektur & Lingkungan Belajar (`modules/00-pengenalan-arsitektur-dan-lingkungan.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/00-pengenalan-arsitektur-dan-lingkungan.md`

**Interfaces:**
- Consumes: `.env.example`, `pyproject.toml`, `requirements.txt`, `arsitektur-day1.svg`
- Produces: Panduan setup lingkungan kerja, penjelasan arsitektur pesan, dan sanity test API.

- [ ] **Step 1: Tulis isi modul `00-pengenalan-arsitektur-dan-lingkungan.md`**

Mencakup:
1. Tujuan Pembelajaran (memahami alur WhatsApp ke LLM, setup virtualenv, konfigurasi `.env`).
2. Konsep & Mermaid diagram aliran pesan: WhatsApp Customer ↔ Evolution API ↔ ngrok ↔ FastAPI `/webhook` ↔ Gemini Agent ↔ DB.
3. Bedah Konfigurasi: Analisis variabel `.env.example` (`GEMINI_API_KEY`, `BUFFER_SECONDS`, `EVOLUTION_API_*`, `DASHBOARD_API_KEY`, R2).
4. Hands-on Lab:
   - Membuat virtual environment dan instalasi dependensi via `uv` atau `pip`.
   - Membuat skrip python kecil untuk sanity check: memanggil `google.genai` Client untuk memastikan API key valid.
5. Pitfalls & Gotchas: Salah format nomor WhatsApp internasional (`628...` vs `08...`), quota rate limit Gemini Free tier.
6. Mini Challenge: Menambahkan variabel custom klinik di `.env` dan membacanya lewat Python.

- [ ] **Step 2: Verifikasi file dan jalankan sanity check script jika memungkinkan**

Run: `ls -la AI-Sales-Agent-Workshop/modules/00-pengenalan-arsitektur-dan-lingkungan.md`
Expected: File terbuat lengkap dengan struktur standar.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/00-pengenalan-arsitektur-dan-lingkungan.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 00 architecture and environment setup"
```

---

### Task 3: Modul 01: Database & Data Modeling (`modules/01-database-dan-data-modeling.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/01-database-dan-data-modeling.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/database.py`
- Produces: Modul edukasi lengkap tentang SQLModel, 7 model data, inisialisasi, dan data seeding.

- [ ] **Step 1: Tulis isi modul `01-database-dan-data-modeling.md`**

Mencakup:
1. Tujuan Pembelajaran (memahami schema SQLModel, relasi data klinik, seeding data).
2. Konsep: SQLModel sebagai bridge Pydantic + SQLAlchemy ORM, SQLite (`clinic.db`) vs PostgreSQL di production.
3. Bedah Kode `database.py`:
   - `Treatment` (id, name, category, price, duration, description)
   - `Booking` (id, code, customer_name, phone, treatment_name, booking_date, booking_time, status)
   - `ClinicHours` & `SpecialSchedule` (jam buka/tutup dan libur khusus)
   - `DoctorSchedule` (jadwal praktek dokter spesialis)
   - `ConversationMessage` & `Contact` (chat log & saklar `is_ai_enabled`)
   - `init_db()` dan `seed_db()` (data catalog Glowria).
4. Hands-on Lab: Skrip Python untuk menginspeksi tabel database SQLite dan menjalankan query treatment & jam buka.
5. Pitfalls & Gotchas: Format string waktu `HH:MM` vs tipe data `time`, migrasi schema SQLite vs file database lock.
6. Mini Challenge: Menambahkan satu data paket treatment baru ke seed data dan memverifikasinya.

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/01-database-dan-data-modeling.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/01-database-dan-data-modeling.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 01 database and data modeling"
```

---

### Task 4: Modul 02: Prompt Engineering & Guardrails Percakapan (`modules/02-prompt-engineering-dan-guardrails.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/02-prompt-engineering-dan-guardrails.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/prompts/system.md`, `AI-Sales-Agent-Workshop/agent.py` (`render_system_prompt`)
- Produces: Modul rekayasa prompt tingkat lanjut, guardrails percakapan, token delimiter, dan strategi caching.

- [ ] **Step 1: Tulis isi modul `02-prompt-engineering-dan-guardrails.md`**

Mencakup:
1. Tujuan Pembelajaran (menguasai perancangan prompt sales agent, guardrails bisnis, prompt caching).
2. Konsep: Persona CS WhatsApp manusiawi vs Robot kaku, struktur prompt modular XML/Markdown tags.
3. Bedah Kode `prompts/system.md` & `agent.py`:
   - Persona & Tone: Formality level 5/10, casual Indonesian (*buat*, *kalo*, *udah*, *yaa kak*), penggunaan "saya" bukan "aku".
   - Hard Rules Guardrails: Dilarang mengaku bot, dilarang menyapa nama customer di awal sebelum recap, larangan diagnosis medis sembarangan.
   - WhatsApp Formatting Protocol: Delimiter bubble `[NEXT]`, delimiter turn-taking `[WAIT]`, delimiter eskalasi `[HANDOVER]`.
   - Prompt Caching Strategy: Mengapa `render_system_prompt()` dibuat statis (cacheable) dan waktu/customer data dinamis diinjeksi via `contents`.
4. Hands-on Lab: Skrip python memanggil `render_system_prompt()` dan menginspeksi hasil template replacement.
5. Pitfalls & Gotchas: Model lupa menyertakan `[WAIT]` sehingga terus berbicara sendiri, atau membocorkan nama internal function tool.
6. Mini Challenge: Menambahkan hard rule baru (misal aturan diskon khusus hari ulang tahun) dan menguji kepatuhan model.

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/02-prompt-engineering-dan-guardrails.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/02-prompt-engineering-dan-guardrails.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 02 prompt engineering and guardrails"
```

---

### Task 5: Modul 03: Function Calling & Algoritma Booking Engine (`modules/03-function-calling-dan-booking-engine.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/03-function-calling-dan-booking-engine.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/tools.py`
- Produces: Modul fungsional Gemini Tool Declarations dan algoritma multi-nurse capacity booking.

- [ ] **Step 1: Tulis isi modul `03-function-calling-dan-booking-engine.md`**

Mencakup:
1. Tujuan Pembelajaran (memahami deklarasi tools untuk GenAI SDK, eksekusi business logic, algoritma kapasitas paralel).
2. Konsep & Mermaid diagram: Flow booking (Check Hours -> Overlap Nurses -> Atomic Save / Conflict -> Next Available Slot).
3. Bedah Kode `tools.py`:
   - `TOOL_DECLARATIONS` & `TOOL_FUNCTIONS`: Format schema parameter Gemini.
   - Algoritma Multi-Nurse Capacity:
     - Durasi default `TREATMENT_DURATION_MINUTES = 90`.
     - `MAX_CONCURRENT = 3` (3 perawat simultan).
     - Perhitungan `_count_overlap()`: interval waktu $[t_{start}, t_{start} + 90)$.
     - Algoritma pencarian `_next_available_slot()` jika slot penuh.
     - Penanganan `SpecialSchedule` override (jadwal libur / cuti dokter).
   - Fungsi operasional: `search_treatments()`, `check_available_schedule()`, `book_treatment()`, `get_my_orders()`, `cancel_booking()`, `handover_to_admin()`.
4. Hands-on Lab: Skrip Python pengujian pemanggilan tool langsung:
   - Melakukan 3 booking di jam yang sama (sukses).
   - Melakukan booking ke-4 di jam yang sama (harus mendeteksi slot conflict dan menyarankan next available slot).
5. Pitfalls & Gotchas: Race condition saat booking tanpa transaksi database, kesalahan perhitungan overlap waktu yang bersinggungan.
6. Mini Challenge: Menambahkan parameter catatan khusus customer pada `book_treatment`.

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/03-function-calling-dan-booking-engine.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/03-function-calling-dan-booking-engine.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 03 function calling and booking engine"
```

---

### Task 6: Modul 04: The Agent Core Loop & Multimodal Vision (`modules/04-agent-core-dan-gemini-loop.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/04-agent-core-dan-gemini-loop.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/agent.py`
- Produces: Modul mendalam tentang orkestrasi model Google GenAI, recursive tool loop, dan multimodal image vision.

- [ ] **Step 1: Tulis isi modul `04-agent-core-dan-gemini-loop.md`**

Mencakup:
1. Tujuan Pembelajaran (menguasai Google GenAI SDK, agen multi-turn tool calling, penanganan gambar/vision).
2. Konsep & Mermaid diagram: Agent Core Loop (`run_agent`): User Message -> Gemini -> Function Call? -> Execute Function -> Feed Back to Gemini -> Repeat / Final Text.
3. Bedah Kode `agent.py`:
   - `get_client()`: Lazy init pattern untuk kemudahan testing tanpa crash awal.
   - Konfigurasi: Model `gemini-3.1-flash-lite`, thinking config `minimal`, temperature `0.7`.
   - Fungsi `run_agent()`:
     - Injeksi konteks tanggal real-time dan nomor HP di awal `user` part.
     - Perulangan `for _ in range(MAX_TOOL_ITERATIONS)`: eksekusi multi-function call paralel/sekuensial dalam satu response.
     - Fallback message handling saat error atau iterasi habis.
     - Multimodal Vision: Membaca tuple `(bytes, mime)` gambar menggunakan `types.Part.from_bytes()`.
4. Hands-on Lab: Skrip Python mandiri memanggil `run_agent` dengan dummy history untuk bertanya rekomendasi treatment dan booking.
5. Pitfalls & Gotchas: Infinite tool loop jika function output membingungkan model, perbedaan format GenAI SDK baru (`google-genai`) vs SDK lama (`google-generativeai`).
6. Mini Challenge: Menguji respons agent saat diberi input gambar kondisi kulit (misal gambar jerawat).

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/04-agent-core-dan-gemini-loop.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/04-agent-core-dan-gemini-loop.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 04 agent core loop and multimodal vision"
```

---

### Task 7: Modul 05: Session State, Debounce Webhook & Media Storage (`modules/05-webhook-debounce-dan-memory.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/05-webhook-debounce-dan-memory.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/main.py`, `AI-Sales-Agent-Workshop/memory.py`
- Produces: Modul teknis penanganan state, asynchronous debounce buffer, dan storage media.

- [ ] **Step 1: Tulis isi modul `05-webhook-debounce-dan-memory.md`**

Mencakup:
1. Tujuan Pembelajaran (menguasai manajemen state sliding window, mengatasi chat cepat WhatsApp dengan debounce buffer, penyimpanan media).
2. Konsep:
   - Mengapa LLM butuh memory sliding window (limit token & biaya).
   - Masalah riil WhatsApp: User mengirim: "Halo", "kak", "mau nanya", "promo acne ada?" dalam 5 detik terpisah.
   - Solusi Debounce: Timer penampung berbasis asyncio per nomor telepon.
3. Bedah Kode `memory.py` & `main.py`:
   - `Memory` class:
     - `get_history(phone)`: `MEMORY_WINDOW = 20`, kronologis reversal, `SESSION_TTL_HOURS = 24`.
     - `add(phone, role, text)` & `is_ai_enabled(phone)`.
   - FastAPI `/webhook` & Debounce Engine:
     - Dict `buffers[phone]`, `buffer_tasks[phone]`, dan `locks[phone]`.
     - Fungsi `_process_buffer(phone)` dengan `await asyncio.sleep(BUFFER_SECONDS)`.
   - `save_media()`: Abstraksi penyimpanan lokal disk vs Cloudflare R2 / S3 bucket.
4. Hands-on Lab: Skrip Python pengujian asynchronous debounce simulation (mengirim 3 pesan berturut-turut dalam interval 1 detik dan melihat hanya 1 proses agent yang dijalankan).
5. Pitfalls & Gotchas: Memory leak pada dictionary buffer tanpa pembersihan, race condition pemanggilan webhook paralel tanpa asyncio Lock.
6. Mini Challenge: Mengubah durasi `BUFFER_SECONDS` dan menganalisis dampaknya terhadap responsivitas vs penghematan token.

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/05-webhook-debounce-dan-memory.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/05-webhook-debounce-dan-memory.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 05 webhook debounce and memory"
```

---

### Task 8: Modul 06: WhatsApp Integration, Live Dashboard & Human Takeover (`modules/06-whatsapp-integration-dan-dashboard.md`)

**Files:**
- Create: `AI-Sales-Agent-Workshop/modules/06-whatsapp-integration-dan-dashboard.md`

**Interfaces:**
- Consumes: `AI-Sales-Agent-Workshop/whatsapp.py`, `AI-Sales-Agent-Workshop/cli.py`, `AI-Sales-Agent-Workshop/routes/dashboard.py`, `AI-Sales-Agent-Workshop/templates/dashboard.html`
- Produces: Modul pengiriman pesan manusiawi ke WhatsApp, testing interaktif CLI, monitoring dashboard, dan mekanisme takeover.

- [ ] **Step 1: Tulis isi modul `06-whatsapp-integration-dan-dashboard.md`**

Mencakup:
1. Tujuan Pembelajaran (mengintegrasikan Evolution API, menjalankan simulasi chat CLI, mengoperasikan live dashboard & human takeover).
2. Konsep:
   - Evolution API sebagai gateway WhatsApp non-official / Baileys.
   - Pola Human-in-the-Loop (kapan AI boleh menjawab vs kapan CS manusia mengambil alih).
3. Bedah Kode:
   - `whatsapp.py`:
     - `_typing_duration(text)`: Simulasi natural typing speed (0.03 detik per karakter, min 1s, max 5s).
     - `send_reply()`: Parsing delimiter `[NEXT]`, pembersihan marker `[WAIT]` dan `[HANDOVER]`, pengiriman beruntun dengan delay.
   - `cli.py`:
     - Simulator terminal untuk development offline tanpa perlu WhatsApp scanner.
   - `routes/dashboard.py` & `templates/dashboard.html`:
     - Endpoint API percakapan & booking, autentikasi header `X-API-Key`.
     - Fitur toggle saklar AI (`is_ai_enabled`) untuk takeover dan balas chat manual dari web UI.
   - Production Deployment: File `Procfile`, deployment di Railway / Zeabur, webhook ngrok.
4. Hands-on Lab: Menjalankan `python cli.py` dan mempraktikkan alur konsultasi hingga booking selesai.
5. Pitfalls & Gotchas: Nomor diblokir WhatsApp jika mengirim pesan terlalu cepat tanpa delay typing, CORS dan proteksi API key dashboard.
6. Mini Challenge: Menambahkan tombol filter booking berdasarkan status di dashboard API.

- [ ] **Step 2: Verifikasi file**

Run: `ls -la AI-Sales-Agent-Workshop/modules/06-whatsapp-integration-dan-dashboard.md`
Expected: File terbuat dan konten lengkap.

- [ ] **Step 3: Commit**

```bash
git -C AI-Sales-Agent-Workshop add modules/06-whatsapp-integration-dan-dashboard.md
git -C AI-Sales-Agent-Workshop commit -m "docs: add module 06 whatsapp integration and dashboard"
```

---

### Task 9: Verifikasi Konsistensi & Validasi Navigasi End-to-End

**Files:**
- Verify: Semua berkas di `AI-Sales-Agent-Workshop/modules/`

**Interfaces:**
- Consumes: Semua file modul yang telah dibuat di Tasks 1–8.
- Produces: Seluruh rangkaian modul terverifikasi tanpa dead links, sintaks markdown rapi, dan siap dipelajari.

- [ ] **Step 1: Validasi struktur dan keberadaan semua berkas modul**

Run:
```bash
ls -la AI-Sales-Agent-Workshop/modules/
```
Expected: Terdapat 8 berkas (`README.md`, `00-*.md`, `01-*.md`, `02-*.md`, `03-*.md`, `04-*.md`, `05-*.md`, `06-*.md`).

- [ ] **Step 2: Validasi kelengkapan link dan heading**

Periksa apakah semua tautan antar modul di `README.md` dan di header/footer tiap modul mengarah ke berkas yang valid.

- [ ] **Step 3: Uji eksekusi lab script sederhana dari salah satu modul**

Pastikan contoh kode yang diberikan di modul berjalan dengan lancar saat diuji.

- [ ] **Step 4: Final commit dan rangkuman**

```bash
git -C AI-Sales-Agent-Workshop status
```
Expected: Clean working tree.
