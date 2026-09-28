# Panduan Kontainerisasi: Menjalankan dengan Docker & Podman

Dokumen ini menjelaskan cara menjalankan **Glowria AI Sales Agent** menggunakan container. Seluruh konfigurasi di repositori ini dirancang agar **100% kompatibel baik untuk Docker Engine maupun Podman (khususnya mode Rootless di Linux)**.

---

## 🏗️ Gambaran Arsitektur Kontainer

Sistem ini didukung oleh file spesifikasi [`compose.yaml`](../compose.yaml) yang mendukung multi-service dan *Compose Profiles*:

```
+-------------------------------------------------------------+
| Container Network: ai-sales-agent-workshop                  |
|                                                             |
|   +-----------------------+     +-----------------------+   |
|   | app (FastAPI Agent)   |     | evolution-api (WA)    |   |
|   | Port: 8000            |     | Port: 8080            |   |
|   | Volume: ./data, ./media|    | Volume: evolution_inst|   |
|   +-----------------------+     +-----------------------+   |
|               ^                             ^               |
|               |                             |               |
|       Host Port 8000                Host Port 8080          |
+-------------------------------------------------------------+
```

1. **Service `app` (Default)**: Container aplikasi FastAPI AI Sales Agent yang berisi model Gemini, engine booking, dan database SQLite lokal terisolasi di folder `./data`.
2. **Service `evolution-api` (Profile `full`)**: Gateway WhatsApp lokal jika Anda ingin menghubungkan WhatsApp fisik tanpa ketergantungan cloud.
3. **Service `postgres` (Profile `postgres`)**: Database PostgreSQL lokal jika ingin menguji transaksi database production.

---

## ⚡ Cara Cepat: Menggunakan `container.sh`

Kami menyediakan skrip pembantu [`container.sh`](../container.sh) di root repositori. Skrip ini secara otomatis mendeteksi apakah komputer Anda menggunakan **Docker** atau **Podman**.

### 1. Persiapan File `.env`
Pastikan Anda telah menyalin file konfigurasi dan mengisi API key Gemini:
```bash
cp .env.example .env
# Edit .env dan isi GEMINI_API_KEY
```

### 2. Build Image
```bash
./container.sh build
```

### 3. Menjalankan Aplikasi

* **Mode Default (Hanya Sales Agent + SQLite)**:
  ```bash
  ./container.sh up
  ```
  Buka browser di: [http://localhost:8000/dashboard](http://localhost:8000/dashboard)

* **Mode Full Stack (Sales Agent + Evolution WhatsApp lokal)**:
  ```bash
  ./container.sh up:full
  ```
  * Dashboard Agent : [http://localhost:8000/](http://localhost:8000/)
  * Evolution API   : [http://localhost:8080/](http://localhost:8080/)

### 4. Buka Simulator Chat CLI di Dalam Container
Anda bisa menguji percakapan langsung dengan Gita di dalam container tanpa browser:
```bash
./container.sh cli
```

### 5. Memantau Log & Menghentikan Container
```bash
# Pantau log
./container.sh logs

# Cek status kesehatan container
./container.sh status

# Hentikan semua container
./container.sh down
```

---

## 🐳 Menjalankan Menggunakan Docker Murni

Jika Anda lebih memilih menggunakan perintah `docker` secara langsung:

```bash
# 1. Build image
docker compose build

# 2. Jalankan service default (background)
docker compose up -d

# 3. Jalankan dengan WhatsApp Evolution API lokal
docker compose --profile full up -d

# 4. Hentikan container
docker compose down
```

---

## 🦭 Menjalankan Menggunakan Podman (Rootless Linux)

Podman menjalankan container tanpa hak akses root (*rootless*), yang jauh lebih aman untuk server dan workstation Linux.

### Catatan Penting untuk Rootless Podman:
1. **SELinux Relabeling (`:z`)**:
   - Di file `compose.yaml`, volume mount menggunakan bendera `:z` (contoh: `./data:/app/data:z`). Bendera ini memerintahkan Podman untuk melakukan relabeling konteks SELinux secara otomatis agar container tidak mengalami *Permission Denied*.
2. **Port Binding**:
   - Port `8000` dan `8080` berada di atas port istimewa (`> 1024`), sehingga dapat langsung di-bind oleh user biasa tanpa butuh akses `sudo`.

### Perintah Podman:
```bash
# Menggunakan podman-compose:
podman-compose up -d

# Atau menggunakan podman build langsung:
podman build -t ai-sales-agent:latest .
podman run -d --name glowria-agent -p 8000:8000 --env-file .env -v ./data:/app/data:z ai-sales-agent:latest
```

---

## ⚙️ Integrasi Jaringan: Menghubungkan Evolution API ke Webhook

Saat menjalankan mode Full Stack (`--profile full`), kedua container berada di jaringan yang sama (`ai-sales-agent-workshop`).

* Untuk mendaftarkan webhook WhatsApp di Evolution API, gunakan hostname container internal:
  ```
  URL Webhook: http://app:8000/webhook
  ```
  *(Tidak perlu menggunakan URL ngrok jika keduanya berada di dalam satu docker network!)*

---

## 🛠️ Troubleshooting (Pemecahan Masalah)

### 1. `Error: listen tcp 0.0.0.0:8000: bind: address already in use`
* **Penyebab**: Port 8000 sedang digunakan oleh aplikasi lain di komputer Anda.
* **Solusi**: Ubah mapping port host di file `.env` atau jalankan `lsof -i :8000` untuk mematikan proses yang sedang memakai port tersebut.

### 2. `Permission denied: /app/data/clinic.db`
* **Penyebab**: Terjadi jika folder `./data` di host dibuat oleh user berbeda (misal `root`).
* **Solusi**: Ubah kepemilikan folder host ke user Anda:
  ```bash
  sudo chown -R $USER:$USER ./data ./media
  ```

### 3. `RuntimeError: GEMINI_API_KEY belum diisi`
* **Penyebab**: File `.env` belum dibuat atau belum dimuat oleh container.
* **Solusi**: Salin `.env.example` ke `.env` di folder project dan pastikan variabel `GEMINI_API_KEY` terisi sebelum menjalankan container.
