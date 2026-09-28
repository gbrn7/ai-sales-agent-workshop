# Design Specification: AI Sales Agent Go & Gin Rewrite

- **Date:** 2026-09-28
- **Author:** Antigravity & User
- **Status:** Approved
- **Target Repository:** `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go`
- **Original Source Reference:** `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop`

## 1. Overview & Goals

This project is a complete rewrite of the Python/FastAPI `AI-Sales-Agent-Workshop` into idiomatic Go using the Gin framework (`github.com/gin-gonic/gin`) and GORM (`gorm.io/gorm`).

The application implements an intelligent WhatsApp-based AI sales agent (named "Gita") for a beauty clinic ("Glowria Aesthetic Clinic"), complete with:
1. Multi-turn AI conversational agent powered by Google Gemini SDK (`google.golang.org/genai`).
2. Gemini Function Calling / Tool Calling for 6 clinic operations (treatment search, schedule & capacity checking, atomic booking, order lookup, cancellation, handover).
3. Evolution API WhatsApp integration (webhook processing, debounce buffering, humanlike typing simulation, multimodal image handling).
4. Media storage proxy with Cloudflare R2 (S3-compatible) support and local disk fallback.
5. Admin dashboard with real-time conversations, human takeover switch (`ai_enabled`), manual WhatsApp messaging, booking overview & status management.
6. Interactive CLI chat mode for rapid local testing without external webhooks.

## 2. Architecture & Directory Layout

The project follows the standard Go layered layout:

```
AI-Sales-Agent-Workshop-Go/
├── cmd/
│   ├── server/main.go          # Entry point for Gin Web Server
│   └── cli/main.go             # Entry point for interactive terminal chat
├── internal/
│   ├── config/config.go        # Environment variable parsing and defaults
│   ├── model/models.go         # GORM database models
│   ├── db/db.go                # DB connection, SQLite WAL mode, AutoMigrate, seeding
│   ├── memory/memory.go        # Conversation history sliding window & takeover state
│   ├── tools/
│   │   ├── tools.go            # Clinic tools logic (search, book, schedule, cancel, etc.)
│   │   └── declarations.go     # Gemini Function Declarations schemas
│   ├── agent/agent.go          # Gemini agent core loop, system prompt rendering, multimodal
│   ├── whatsapp/
│   │   ├── client.go           # Evolution API HTTP client (presence, sendText, getBase64)
│   │   └── parser.go           # Webhook payload extractor
│   ├── buffer/buffer.go        # In-memory debounce buffer per phone number
│   ├── storage/storage.go      # Cloudflare R2 / S3 client & local file storage
│   └── handler/
│       ├── webhook.go          # POST /webhook endpoint
│       ├── media.go            # GET /media/:fname proxy endpoint
│       ├── dashboard.go        # GET /dashboard & GET /dashboard/api/* endpoints
│       └── health.go           # GET /health & GET / endpoints
├── templates/
│   └── dashboard.html          # HTML dashboard template
├── prompts/
│   └── system.md               # System prompt template
├── .env.example                # Example environment variables
├── go.mod                      # Go module definitions
├── go.sum                      # Go dependencies checksum
└── README.md                   # Setup and usage guide
```

## 3. Database & Models (GORM)

### Database Engines
- Primary: SQLite (`github.com/glebarez/sqlite`, pure Go, CGO-free).
- Production alternative: PostgreSQL (`gorm.io/driver/postgres`).
- SQLite Optimizations: Executed on connect:
  - `PRAGMA journal_mode=WAL;`
  - `PRAGMA busy_timeout=5000;`

### Models
1. **`Treatment`**
   - `ID` (uint, PK)
   - `Name` (string, index)
   - `Category` (string, index) - e.g. `konsultasi`, `acne`, `brightening`, `anti-aging`, `hair-removal`
   - `Price` (int64)
   - `Description` (string)
   - `Promo` (*string)
   - `RequiresDoctor` (bool)

2. **`Booking`**
   - `ID` (uint, PK)
   - `Code` (string, uniqueIndex) - format `GLW-YYYYMMDD-XXXX`
   - `CustomerName` (string)
   - `Phone` (string, index)
   - `TreatmentID` (uint, FK to Treatment)
   - `Treatment` (Treatment association)
   - `BookingDate` (string, `YYYY-MM-DD`, index)
   - `BookingTime` (string, `HH:MM`)
   - `DurationMinutes` (int, default 90)
   - `Status` (string, index) - `pending`, `confirmed`, `completed`, `cancelled`
   - `CreatedAt` (time.Time)

3. **`ClinicHours`**
   - `Weekday` (int, PK) - 0 = Monday ... 6 = Sunday
   - `OpenTime` (string, `HH:MM`)
   - `CloseTime` (string, `HH:MM`)

4. **`DoctorSchedule`**
   - `ID` (uint, PK)
   - `DoctorName` (string, index)
   - `Weekday` (int, index)
   - `StartTime` (string, `HH:MM`)
   - `EndTime` (string, `HH:MM`)

5. **`SpecialSchedule`**
   - `ID` (uint, PK)
   - `ScheduleDate` (string, `YYYY-MM-DD`, uniqueIndex)
   - `IsClosed` (bool)
   - `OpenTime` (*string, `HH:MM`)
   - `CloseTime` (*string, `HH:MM`)
   - `DoctorName` (*string)
   - `DoctorStart` (*string, `HH:MM`)
   - `DoctorEnd` (*string, `HH:MM`)
   - `Note` (*string)
   - `CreatedAt` (time.Time)

6. **`ConversationMessage`**
   - `ID` (uint, PK)
   - `Phone` (string, index)
   - `Role` (string) - `user` or `model`
   - `Text` (string)
   - `CreatedAt` (time.Time, index)

7. **`Contact`**
   - `Phone` (string, PK)
   - `Name` (*string)
   - `AiEnabled` (bool, default true)
   - `IsReturning` (bool, default false)
   - `CreatedAt` (time.Time)

### Seeding
Upon initialization, if the `Treatment` table is empty, auto-seed:
- 10 standard treatments (Konsultasi, Acne, Brightening, Anti-aging, Hair removal).
- Regular clinic hours (Monday-Saturday 10:00-18:00, Sunday 10:00-16:00).
- Regular doctor schedules (Dr. Amara, Dr. Sinta).
- Special schedules (2026-06-22 doctor shift, 2026-06-24 to 2026-06-26 closed, 2026-06-27 doctor shift).

## 4. Business Logic & Clinic Tools

### Schedule & Capacity Engine Rules
- Treatment duration: fixed 90 minutes.
- Maximum concurrent capacity: 3 nurses (`MAX_CONCURRENT = 3`).
- Overlap algorithm: Two intervals $[s_1, e_1)$ and $[s_2, e_2)$ overlap if $s_1 < e_2$ and $s_2 < e_1$.
- SpecialSchedule takes absolute precedence over regular hours and doctor shifts.
- Nearest available slot search: 30-minute step search, bounded by `start + 90 <= close_time`.

### Tools
1. `search_treatments(query string) map[string]any`
2. `check_available_schedule(booking_date string) map[string]any`
3. `book_treatment(customer_name, phone, treatment_name, booking_date, booking_time string) map[string]any`
4. `get_my_orders(phone string) map[string]any`
5. `cancel_booking(booking_code, reason string) map[string]any`
6. `handover_to_admin(phone, reason string) map[string]any`

## 5. Gemini Agent Loop

- **Client**: `google.golang.org/genai`.
- **System Prompt**: Loaded from `prompts/system.md` with template placeholders replaced at startup/per request. Static prompt ensures context caching.
- **Dynamic Context**: Prepend `[Konteks: Hari ini <Hari>, <Tgl> <Bulan> <Tahun> (<YYYY-MM-DD>), pukul <HH:MM>. Nomor WhatsApp customer: <Phone>]` to each user message.
- **Multimodal Support**: Pass base64/bytes image parts when customer sends photos.
- **Tool Calling**:
  - Max 5 iterations.
  - Execute matching Go function for each `FunctionCall`.
  - Append `FunctionResponse` to contents.
  - Return final text reply.
- **Fallback**: Graceful Indonesian apology with `[HANDOVER]` tag if Gemini errors or loops out.

## 6. Debounce Buffer & WhatsApp Integration

- **Debounce Buffer**:
  - Buffer duration: `BUFFER_SECONDS` (default 8s).
  - Webhook returns immediate `{"status": "buffered", "pending": N}`.
  - An in-memory struct tracks pending messages and active `time.Timer` per phone.
  - When timer triggers, aggregate texts, fetch images via Evolution API `/chat/getBase64FromMediaMessage`, and run agent.
- **Humanlike Typing & Bubble Splitting**:
  - Remove internal markers `[WAIT]` and `[HANDOVER]`.
  - Split response on `[NEXT]` or `\n\n`.
  - Calculate typing duration: `min(max(len(bubble) * 0.03, 1.0), 5.0)`.
  - Trigger `sendPresence(composing)` via Evolution API, sleep duration, then `sendText`.

## 7. Media Storage & Proxy

- Mode 1: Cloudflare R2 / S3 (activated when all 5 env vars are set).
- Mode 2: Local filesystem `media/` directory.
- Proxy route `GET /media/:fname`: Sanitizes filename with `filepath.Base(fname)` to prevent directory traversal. Serves media content with `Cache-Control: public, max-age=86400`.

## 8. Dashboard Web & API

- `GET /dashboard`: Serves `templates/dashboard.html`.
- Protected by middleware `X-API-Key: DASHBOARD_API_KEY`:
  - `GET /dashboard/api/config`
  - `GET /dashboard/api/conversations`
  - `GET /dashboard/api/conversations/:phone`
  - `POST /dashboard/api/conversations/:phone/ai`
  - `POST /dashboard/api/conversations/:phone/send`
  - `GET /dashboard/api/bookings`
  - `POST /dashboard/api/bookings/:code/status`

## 9. CLI Interactive Mode

- `cmd/cli/main.go` provides an interactive terminal REPL using a dummy customer phone (`6281234567890`), maintaining in-memory history and outputting simulated WhatsApp bubbles.

## 10. Verification Plan

1. **Compilation**: `go build ./...` across both `cmd/server` and `cmd/cli`.
2. **Unit Tests**:
   - `internal/tools`: Test treatment search, schedule overlap capacity, special schedule overrides, booking creation, cancellation.
   - `internal/memory`: Test sliding window and session TTL.
   - `internal/whatsapp`: Test incoming webhook extractor and bubble split logic.
3. **End-to-End Test**:
   - Run CLI and check treatment inquiry and booking flow.
   - Run server and verify `/health`, `/dashboard`, and `/webhook`.
