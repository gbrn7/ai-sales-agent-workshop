# Desain Spesifikasi: Modul Pembelajaran AI Sales Agent Workshop

- **Tanggal**: 2026-09-28
- **Topik**: Seri Modul Edukasi & Panduan Hands-on untuk Project AI Sales Agent (Glowria Aesthetic Clinic)
- **Status**: Disetujui
- **Target Direktori**: `AI-Sales-Agent-Workshop/modules/`

---

## 1. Latar Belakang & Tujuan

Project `AI-Sales-Agent-Workshop` merupakan implementasi *end-to-end* sistem AI Sales Agent untuk klinik estetika berbasis WhatsApp dengan integrasi Google Gemini, FastAPI, Evolution API, dan SQLModel. Repositori ini memiliki banyak komponen penting (prompt engineering tingkat lanjut, memory sliding window, function calling dengan multi-nurse capacity, asyncio debounce, multimodal vision, dan human takeover).

Tujuan dari modul pembelajaran ini adalah:
1. Menyediakan panduan belajar mandiri (*self-paced hands-on tutorial*) di dalam repositori agar developer atau peserta workshop dapat memahami arsitektur, kode, dan cara kerja sistem dari fondasi hingga *production-ready*.
2. Membedah setiap berkas kode secara modular tanpa loncat-loncat topik yang membingungkan.
3. Memberikan instruksi konkret cara menjalankan dan menguji (*hands-on lab*) setiap komponen secara terisolasi.

---

## 2. Struktur Direktori Modul

Semua modul diletakkan di dalam folder `AI-Sales-Agent-Workshop/modules/` dengan penomoran urut:

```
AI-Sales-Agent-Workshop/
├── modules/
│   ├── README.md                                  # Peta navigasi belajar, roadmap, dependensi
│   ├── 00-pengenalan-arsitektur-dan-lingkungan.md # Mental model, flow end-to-end, setup env
│   ├── 01-database-dan-data-modeling.md           # SQLModel, skema 7 tabel, seeding data
│   ├── 02-prompt-engineering-dan-guardrails.md    # Persona Gita, hard rules, marker [NEXT]/[WAIT]
│   ├── 03-function-calling-dan-booking-engine.md  # Tool declarations, multi-nurse capacity, atomic lock
│   ├── 04-agent-core-dan-gemini-loop.md           # GenAI SDK loop, tool execution, multimodal vision
│   ├── 05-webhook-debounce-dan-memory.md          # Sliding window memory, buffer asyncio 8 detik
│   └── 06-whatsapp-integration-dan-dashboard.md   # Evolution API, CLI testing, live takeover
```

---

## 3. Anatomi Standar Setiap Modul

Setiap file modul (`00` s/d `06`) wajib mengikuti anatomi baku berikut:

1. **🎯 Tujuan Pembelajaran**: 3–4 poin hasil belajar konkret (kompetensi apa yang diperoleh).
2. **🧩 Konsep & Mental Model**: Penjelasan analogi + diagram alur (*Mermaid flowchart*) tentang peran modul dalam sistem.
3. **🔍 Bedah Kode Mendalam (Code Walkthrough)**:
   - Tautan langsung ke file sumber (e.g. `database.py`, `agent.py`).
   - Penjelasan blok fungsi utama, parameter, tipe data, dan alasan desain teknis (*design rationale*).
4. **🧪 Hands-on Lab & Pengujian Mandiri**:
   - Kode pengujian mandiri (*standalone script* atau perintah terminal) yang dapat dijalankan tanpa dependensi eksternal yang rumit.
5. **⚠️ Pitfalls & Gotchas**:
   - Analisis potensi *bug*, kesalahan pemula, atau jebakan arsitektur (e.g. prompt caching vs dynamic context, race conditions).
6. **🚀 Tantangan Mandiri (Mini Challenge)**:
   - 1–2 studi kasus / modifikasi kode untuk menguji pemahaman sebelum melanjutkan ke modul berikutnya.

---

## 4. Rincian Silabus Modul

### `modules/README.md`
- Gambaran umum repositori & arsitektur Glowria AI Sales Agent.
- Visual diagram arsitektur sistem (`arsitektur-day1.svg`).
- Peta jalur belajar (*Learning Path Roadmap*):
  - Fase 1: Dasar & Data (`00`, `01`)
  - Fase 2: Otak AI & Logika Bisnis (`02`, `03`, `04`)
  - Fase 3: Integrasi, Resilience & Operasional (`05`, `06`)
- Prasyarat: Python 3.10+, Gemini API Key, pemahaman dasar REST API.

### `modules/00-pengenalan-arsitektur-dan-lingkungan.md`
- **Fokus**: Gambaran menyeluruh sistem dan persiapan environment kerja.
- **Topik**:
  - Alur pesan inbound & outbound: Customer (WA) ↔ Evolution API ↔ ngrok ↔ FastAPI `/webhook` ↔ Gemini Agent ↔ Tools & DB.
  - Setup virtualenv (`uv` atau `venv`), instalasi dependensi (`requirements.txt` / `pyproject.toml`).
  - Bedah berkas `.env.example`: variabel kunci (`GEMINI_API_KEY`, `EVOLUTION_API_*`, `BUFFER_SECONDS`, `DASHBOARD_API_KEY`).
  - Lab: Menjalankan skrip sanity check untuk memverifikasi koneksi Python dan API Key Gemini.

### `modules/01-database-dan-data-modeling.md`
- **Fokus**: Layer persistensi data menggunakan SQLModel.
- **Topik**:
  - Bedah berkas `database.py`: Mengapa SQLModel (Pydantic schema validation + SQLAlchemy ORM).
  - Skema 7 Model:
    1. `Treatment`: Katalog perawatan, harga, durasi, kategori.
    2. `Booking`: Status booking (`confirmed`, `cancelled`), relasi tanggal/jam, kode unik.
    3. `ClinicHours`: Jam operasional reguler per hari kerja (0 = Senin, 6 = Minggu).
    4. `SpecialSchedule`: Jadwal libur khusus / klinik tutup yang meng-override jam reguler.
    5. `DoctorSchedule`: Jadwal dokter spesialis per hari kerja.
    6. `ConversationMessage`: Riwayat chat per nomor telepon untuk persistent memory.
    7. `Contact`: Profil kontak customer dan saklar status AI (`is_ai_enabled`).
  - Fungsi `init_db()` dan `seed_db()`.
  - Lab: Script query data SQLite untuk melihat data seed treatment dan jadwal klinik.

### `modules/02-prompt-engineering-dan-guardrails.md`
- **Fokus**: Rekayasa prompt tingkat lanjut untuk WhatsApp Sales Agent.
- **Topik**:
  - Bedah berkas `prompts/system.md` & `render_system_prompt()` di `agent.py`.
  - Persona Gita: Tone of Voice santai-profesional (formality 5/10), kosakata Indonesia natural (*buat*, *kalo*, *udah*, *yaa kak*).
  - Hard Rules & Guardrails ketat: Larangan mengaku AI, pantang panggil nama di awal chat (hanya "kak"), larangan diagnosis medis sembarangan, aturan libur klinik absolut.
  - WhatsApp Protocol Markers:
    - `[NEXT]`: Pemisah pesan bubble terpisah.
    - `[WAIT]`: Turn-taking marker untuk berhenti dan menunggu jawaban customer.
    - `[HANDOVER]`: Marker penyerahan percakapan ke admin manusia.
  - Strategi Prompt Caching: Memisahkan instruksi statis (system prompt) dari konteks dinamis (waktu real-time dan nomor HP diinjeksi via user content).
  - Lab: Simulasi modifikasi prompt dan pengujian respons.

### `modules/03-function-calling-dan-booking-engine.md`
- **Fokus**: Gemini Function Calling dan algoritma booking multi-kapasitas.
- **Topik**:
  - Bedah berkas `tools.py`: Skema `TOOL_DECLARATIONS` dan mapping `TOOL_FUNCTIONS`.
  - Fungsi-fungsi operasional:
    - `search_treatments(query)`
    - `check_available_schedule(booking_date)`
    - `book_treatment(customer_name, phone, treatment_name, booking_date, booking_time, ...)`
    - `get_my_orders(phone)`, `cancel_booking(booking_code)`, `handover_to_admin(phone, reason)`.
  - **Algoritma Multi-Nurse Capacity Booking**:
    - Durasi standar 90 menit per treatment (`TREATMENT_DURATION_MINUTES = 90`).
    - Kapasitas paralel: `MAX_CONCURRENT = 3` perawat (slot baru penuh jika overlap $\ge 3$).
    - Logika `_count_overlap()` dan algoritma penemuan slot alternatif terdekat `_next_available_slot()`.
    - Hirarki override `SpecialSchedule` terhadap jam reguler dan jadwal dokter.
  - Lab: Test script skenario booking paralel hingga mendeteksi slot bentrok (slot conflict).

### `modules/04-agent-core-dan-gemini-loop.md`
- **Fokus**: Loop orkestrasi model AI, eksekusi tools iteratif, dan multimodal vision.
- **Topik**:
  - Bedah berkas `agent.py`: Google GenAI SDK (`google.genai`).
  - Model `gemini-3.1-flash-lite`, thinking config `minimal` untuk efisiensi latensi dan biaya token.
  - Arsitektur Core Loop `run_agent()`:
    - Injeksi konteks tanggal & nomor HP via `types.Content`.
    - Iterative tool execution loop (`MAX_TOOL_ITERATIONS = 5`).
    - Penanganan function call ganda dalam satu turn.
  - Multimodal Vision: Memproses input gambar/foto keluhan kulit (`types.Part.from_bytes`).
  - Error recovery & Fallback message saat Gemini API mengalami gangguan atau limit.
  - Lab: Menjalankan skrip `agent.py` mandiri untuk konsultasi jerawat berbasis teks & gambar.

### `modules/05-webhook-debounce-dan-memory.md`
- **Fokus**: Penanganan state percakapan, resilience webhook, dan debounce buffer.
- **Topik**:
  - Bedah berkas `memory.py`:
    - Sliding window memory (`MEMORY_WINDOW = 20`) agar ukuran prompt tetap terkontrol.
    - Session TTL (`SESSION_TTL_HOURS = 24`) untuk mereset riwayat basi tanpa menghapus histori di database.
  - Bedah berkas `main.py`:
    - Mengapa butuh buffer debounce? Perilaku pengguna WhatsApp mengirim banyak chat pendek terpisah dalam hitungan detik.
    - Implementasi `asyncio.sleep(BUFFER_SECONDS)` dan `asyncio.Lock` per nomor customer untuk mencegah *race condition* agent execution.
  - Manajemen media: Penyimpanan lokal vs Cloudflare R2 / S3 bucket.
  - Lab: Simulasi request webhook beruntun (*concurrent incoming webhook messages*) untuk membuktikan buffer debounce menggabungkan pesan dengan aman.

### `modules/06-whatsapp-integration-dan-dashboard.md`
- **Fokus**: Integrasi kurir pesan, pengujian CLI lokal, dan operasional human takeover.
- **Topik**:
  - Bedah berkas `whatsapp.py`:
    - Integrasi REST API Evolution API (`/message/sendText`, `/chat/sendPresence`).
    - Simulasi human typing latency (`_typing_duration`) berdasarkan panjang karakter pesan.
    - Pemecahan bubble chat berdasarkan delimiter `[NEXT]`.
  - Bedah berkas `cli.py`:
    - Simulator WhatsApp di command line untuk testing cepat alur percakapan tanpa kartu SIM / webhook eksternal.
  - Bedah berkas `routes/dashboard.py` & `templates/dashboard.html`:
    - Live monitoring chat WhatsApp.
    - Mekanisme **Human Takeover** (`is_ai_enabled` toggle di tabel `Contact`): Mematikan respon otomatis AI saat CS manusia mengambil alih.
    - Manajemen daftar booking dan update status.
  - Catatan deployment ke production: `Procfile`, Railway, Zeabur.
  - Lab: Simulasi lengkap menggunakan CLI dari menyapa Gita, tanya rekomendasi jerawat, booking slot, hingga melihat data masuk di database.

---

## 5. Kriteria Verifikasi & Kualitas

Setiap modul yang ditulis harus memenuhi kriteria berikut:
- **Akurasi Kode**: Setiap potongan kode yang dikutip harus 100% cocok dengan implementasi aktual di repositori `AI-Sales-Agent-Workshop`.
- **Dapat Dijalankan (Actionable Labs)**: Setiap perintah dan skrip pengujian di section Lab harus valid dan dapat dieksekusi di terminal Linux.
- **Format Konsisten**: Menggunakan Markdown standar, sintaks blok kode dengan penanda bahasa (`python`, `bash`, `mermaid`), dan tautan relatif ke berkas terkait.
