# Go Gin AI Sales Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the AI Sales Agent Workshop application into idiomatic Go using the Gin framework, GORM, and Google Gemini SDK.

**Architecture:** Standard Go layered architecture (`cmd/server`, `cmd/cli`, `internal/...`). Decoupled components for Agent (Gemini function calling), Tools (capacity-based scheduling & booking), Debounce Buffer, WhatsApp (Evolution API), Memory (sliding window), Storage (R2/local fallback), and Gin HTTP Handlers.

**Tech Stack:** Go 1.25+, Gin (`github.com/gin-gonic/gin`), GORM (`gorm.io/gorm`), pure-Go SQLite (`github.com/glebarez/sqlite`), PostgreSQL driver (`gorm.io/driver/postgres`), Google GenAI Go SDK (`google.golang.org/genai`), AWS SDK v2 for S3/R2 (`github.com/aws/aws-sdk-go-v2`), godotenv (`github.com/joho/godotenv`).

## Global Constraints

- Target directory: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go`
- Source reference directory: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop`
- Go version: `go1.25.1`
- Pure Go SQLite (CGO-free via `github.com/glebarez/sqlite`)
- All database operations atomic where concurrency is checked (booking slot overlap check)
- WhatsApp reply splitting at `[NEXT]` or `\n\n`, removing `[WAIT]` and `[HANDOVER]`

---

### Task 1: Project Scaffolding, Go Module & Dependencies, Config Loader, and Assets

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/go.mod`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/.env.example`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/config/config.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/config/config_test.go`
- Copy: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/prompts/system.md`
- Copy: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/templates/dashboard.html`

**Interfaces:**
- Produces: `config.Config`, `config.Load() (*Config, error)`

- [ ] **Step 1: Create target directory and initialize git repository**

```bash
mkdir -p /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git init
```

- [ ] **Step 2: Initialize go.mod and install dependencies**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go mod init github.com/raygbrn/ai-sales-agent-go
go get github.com/gin-gonic/gin@v1.10.0
go get gorm.io/gorm@v1.25.12
go get github.com/glebarez/sqlite@v1.11.0
go get gorm.io/driver/postgres@v1.5.11
go get google.golang.org/genai@v0.1.0
go get github.com/joho/godotenv@v1.5.1
go get github.com/aws/aws-sdk-go-v2@v1.36.1
go get github.com/aws/aws-sdk-go-v2/config@v1.29.6
go get github.com/aws/aws-sdk-go-v2/credentials@v1.17.59
go get github.com/aws/aws-sdk-go-v2/service/s3@v1.76.0
```

- [ ] **Step 3: Copy static assets and templates from reference repo**

```bash
mkdir -p /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/prompts
mkdir -p /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/templates
mkdir -p /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/media
cp /home/raygbrn/project/ai/AI-Sales-Agent-Workshop/prompts/system.md /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/prompts/system.md
cp /home/raygbrn/project/ai/AI-Sales-Agent-Workshop/templates/dashboard.html /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/templates/dashboard.html
cp /home/raygbrn/project/ai/AI-Sales-Agent-Workshop/.env.example /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/.env.example
```

- [ ] **Step 4: Write failing unit test for config loader**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/config/config_test.go`
```go
package config

import (
	"os"
	"testing"
)

func TestConfigLoadDefaults(t *testing.T) {
	os.Clearenv()
	cfg := Load()
	if cfg.Port != "8000" {
		t.Errorf("expected default Port 8000, got %s", cfg.Port)
	}
	if cfg.BufferSeconds != 8 {
		t.Errorf("expected default BufferSeconds 8, got %d", cfg.BufferSeconds)
	}
	if cfg.MemoryWindow != 20 {
		t.Errorf("expected default MemoryWindow 20, got %d", cfg.MemoryWindow)
	}
	if cfg.AIName != "Gita" {
		t.Errorf("expected default AIName Gita, got %s", cfg.AIName)
	}
}
```

- [ ] **Step 5: Verify test fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/config/...
```
Expected: FAIL (package/function not found).

- [ ] **Step 6: Write config implementation**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/config/config.go`
```go
package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port               string
	GeminiAPIKey       string
	GeminiModel        string
	GeminiThinking     string
	EvolutionAPIURL    string
	EvolutionAPIKey    string
	EvolutionInstance  string
	DatabaseURL        string
	AIName             string
	CompanyName        string
	BufferSeconds      int
	MemoryWindow       int
	SessionTTLHours    int
	DashboardAPIKey    string
	R2Endpoint         string
	R2AccessKeyID      string
	R2SecretAccessKey  string
	R2Bucket           string
	R2PublicURL        string
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if val := os.Getenv(key); val != "" {
		if i, err := strconv.Atoi(val); err == nil {
			return i
		}
	}
	return fallback
}

func Load() *Config {
	_ = godotenv.Load()

	return &Config{
		Port:              getEnv("PORT", "8000"),
		GeminiAPIKey:      os.Getenv("GEMINI_API_KEY"),
		GeminiModel:       getEnv("GEMINI_MODEL", "gemini-2.5-flash"),
		GeminiThinking:    getEnv("GEMINI_THINKING_LEVEL", "low"),
		EvolutionAPIURL:   getEnv("EVOLUTION_API_URL", "http://localhost:8080"),
		EvolutionAPIKey:   os.Getenv("EVOLUTION_API_KEY"),
		EvolutionInstance: getEnv("EVOLUTION_INSTANCE", "glowria"),
		DatabaseURL:       getEnv("DATABASE_URL", "sqlite://clinic.db"),
		AIName:            getEnv("AI_NAME", "Gita"),
		CompanyName:       getEnv("COMPANY_NAME", "Glowria Aesthetic Clinic"),
		BufferSeconds:     getEnvInt("BUFFER_SECONDS", 8),
		MemoryWindow:      getEnvInt("MEMORY_WINDOW", 20),
		SessionTTLHours:   getEnvInt("SESSION_TTL_HOURS", 24),
		DashboardAPIKey:   getEnv("DASHBOARD_API_KEY", "ganti-dengan-string-acak-panjang"),
		R2Endpoint:        os.Getenv("R2_ENDPOINT"),
		R2AccessKeyID:     os.Getenv("R2_ACCESS_KEY_ID"),
		R2SecretAccessKey: os.Getenv("R2_SECRET_ACCESS_KEY"),
		R2Bucket:          os.Getenv("R2_BUCKET"),
		R2PublicURL:       os.Getenv("R2_PUBLIC_URL"),
	}
}

func (c *Config) IsR2Enabled() bool {
	return c.R2Endpoint != "" && c.R2AccessKeyID != "" &&
		c.R2SecretAccessKey != "" && c.R2Bucket != "" && c.R2PublicURL != ""
}
```

- [ ] **Step 7: Run test to verify it passes**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/config/...
```
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add .
git commit -m "feat: setup project scaffolding, dependencies, assets, and config loader"
```

---

### Task 2: GORM Database Layer, Models, Auto-Migration, and Seeding

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/model/models.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/db.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/seed.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/db_test.go`

**Interfaces:**
- Produces: `db.InitDB(databaseURL string) (*gorm.DB, error)`, `db.SeedDB(db *gorm.DB) error`
- Models: `model.Treatment`, `model.Booking`, `model.ClinicHours`, `model.DoctorSchedule`, `model.SpecialSchedule`, `model.ConversationMessage`, `model.Contact`

- [ ] **Step 1: Write model definitions**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/model/models.go`
```go
package model

import "time"

const (
	TreatmentDurationMinutes = 90
	MaxConcurrent            = 3
)

type Treatment struct {
	ID             uint    `gorm:"primaryKey" json:"id"`
	Name           string  `gorm:"index;not null" json:"name"`
	Category       string  `gorm:"index;not null" json:"category"`
	Price          int64   `gorm:"not null" json:"price"`
	Description    string  `gorm:"not null" json:"description"`
	Promo          *string `json:"promo"`
	RequiresDoctor bool    `gorm:"default:false;not null" json:"requires_doctor"`
}

type Booking struct {
	ID              uint      `gorm:"primaryKey" json:"id"`
	Code            string    `gorm:"uniqueIndex;not null" json:"code"`
	CustomerName    string    `gorm:"not null" json:"customer_name"`
	Phone           string    `gorm:"index;not null" json:"phone"`
	TreatmentID     uint      `gorm:"index;not null" json:"treatment_id"`
	Treatment       Treatment `gorm:"foreignKey:TreatmentID" json:"treatment"`
	BookingDate     string    `gorm:"index;not null" json:"booking_date"` // YYYY-MM-DD
	BookingTime     string    `gorm:"not null" json:"booking_time"`       // HH:MM
	DurationMinutes int       `gorm:"default:90;not null" json:"duration_minutes"`
	Status          string    `gorm:"index;default:pending;not null" json:"status"` // pending | confirmed | completed | cancelled
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"created_at"`
}

type ClinicHours struct {
	Weekday   int    `gorm:"primaryKey" json:"weekday"` // 0=Senin ... 6=Minggu
	OpenTime  string `gorm:"not null" json:"open_time"`  // HH:MM
	CloseTime string `gorm:"not null" json:"close_time"` // HH:MM
}

type DoctorSchedule struct {
	ID         uint   `gorm:"primaryKey" json:"id"`
	DoctorName string `gorm:"index;not null" json:"doctor_name"`
	Weekday    int    `gorm:"index;not null" json:"weekday"`
	StartTime  string `gorm:"not null" json:"start_time"` // HH:MM
	EndTime    string `gorm:"not null" json:"end_time"`   // HH:MM
}

type SpecialSchedule struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	ScheduleDate string    `gorm:"uniqueIndex;not null" json:"schedule_date"` // YYYY-MM-DD
	IsClosed     bool      `gorm:"default:false;not null" json:"is_closed"`
	OpenTime     *string   `json:"open_time"`
	CloseTime    *string   `json:"close_time"`
	DoctorName   *string   `json:"doctor_name"`
	DoctorStart  *string   `json:"doctor_start"`
	DoctorEnd    *string   `json:"doctor_end"`
	Note         *string   `json:"note"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"created_at"`
}

type ConversationMessage struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	Phone     string    `gorm:"index;not null" json:"phone"`
	Role      string    `gorm:"not null" json:"role"` // "user" | "model"
	Text      string    `gorm:"not null" json:"text"`
	CreatedAt time.Time `gorm:"index;autoCreateTime" json:"created_at"`
}

type Contact struct {
	Phone       string    `gorm:"primaryKey" json:"phone"`
	Name        *string   `json:"name"`
	AiEnabled   bool      `gorm:"default:true;not null" json:"ai_enabled"`
	IsReturning bool      `gorm:"default:false;not null" json:"is_returning"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"created_at"`
}
```

- [ ] **Step 2: Write failing unit test for DB initialization and seeding**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/db_test.go`
```go
package db

import (
	"testing"

	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

func TestInitDBAndSeed(t *testing.T) {
	database, err := InitDB("sqlite://file::memory:?cache=shared")
	if err != nil {
		t.Fatalf("failed to init db: %v", err)
	}

	if err := SeedDB(database); err != nil {
		t.Fatalf("failed to seed db: %v", err)
	}

	var count int64
	database.Model(&model.Treatment{}).Count(&count)
	if count != 10 {
		t.Errorf("expected 10 treatments seeded, got %d", count)
	}

	var hoursCount int64
	database.Model(&model.ClinicHours{}).Count(&hoursCount)
	if hoursCount != 7 {
		t.Errorf("expected 7 days clinic hours seeded, got %d", hoursCount)
	}

	var doctorCount int64
	database.Model(&model.DoctorSchedule{}).Count(&doctorCount)
	if doctorCount != 7 {
		t.Errorf("expected 7 doctor schedule entries, got %d", doctorCount)
	}

	var specialCount int64
	database.Model(&model.SpecialSchedule{}).Count(&specialCount)
	if specialCount != 5 {
		t.Errorf("expected 5 special schedule entries, got %d", specialCount)
	}
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/db/...
```
Expected: FAIL.

- [ ] **Step 4: Implement DB connection and seeding**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/db.go`
```go
package db

import (
	"strings"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

func InitDB(databaseURL string) (*gorm.DB, error) {
	var dialector gorm.Dialector

	if strings.HasPrefix(databaseURL, "postgres://") || strings.HasPrefix(databaseURL, "postgresql://") {
		dialector = postgres.Open(databaseURL)
	} else {
		sqlitePath := strings.TrimPrefix(databaseURL, "sqlite://")
		if sqlitePath == "" {
			sqlitePath = "clinic.db"
		}
		dialector = sqlite.Open(sqlitePath)
	}

	gormDB, err := gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, err
	}

	if !strings.HasPrefix(databaseURL, "postgres://") && !strings.HasPrefix(databaseURL, "postgresql://") {
		sqlDB, err := gormDB.DB()
		if err == nil {
			_, _ = sqlDB.Exec("PRAGMA journal_mode=WAL;")
			_, _ = sqlDB.Exec("PRAGMA busy_timeout=5000;")
		}
	}

	err = gormDB.AutoMigrate(
		&model.Treatment{},
		&model.Booking{},
		&model.ClinicHours{},
		&model.DoctorSchedule{},
		&model.SpecialSchedule{},
		&model.ConversationMessage{},
		&model.Contact{},
	)
	if err != nil {
		return nil, err
	}

	return gormDB, nil
}
```

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/db/seed.go`
```go
package db

import (
	"gorm.io/gorm"

	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

func strPtr(s string) *string {
	return &s
}

func SeedDB(db *gorm.DB) error {
	var count int64
	db.Model(&model.Treatment{}).Count(&count)
	if count > 0 {
		return nil
	}

	treatments := []model.Treatment{
		{Name: "Konsultasi Treatment", Category: "konsultasi", Price: 0,
			Description: "Konsultasi GRATIS untuk memilih treatment kecantikan yang tepat.", RequiresDoctor: true},
		{Name: "Konsultasi Penyakit Kulit & Kelamin", Category: "konsultasi", Price: 125000,
			Description: "Konsultasi kondisi medis, penyakit kulit, dan prosedur dokter spesialis.", RequiresDoctor: true},
		{Name: "Facial Acne", Category: "acne", Price: 100000,
			Description: "Pembersihan mendalam untuk kulit berjerawat.", Promo: strPtr("Promo Pelajar Rp 100.000 (tunjukkan kartu pelajar)")},
		{Name: "Paket Acne A (Peeling Acne + Meso Purifying)", Category: "acne", Price: 275000,
			Description: "Kombinasi peeling dan meso untuk jerawat aktif.", Promo: strPtr("Diskon 50% s/d 30 Juni")},
		{Name: "Paket Acne B (IPL Acne + Meso Purifying)", Category: "acne", Price: 425000,
			Description: "IPL untuk peradangan jerawat plus meso purifying.", Promo: strPtr("Diskon 50% s/d 30 Juni")},
		{Name: "Paket Brightening A (Facial Whitening Premium + Infus Brightening)", Category: "brightening", Price: 495000,
			Description: "Mencerahkan kulit dari luar dan dalam.", Promo: strPtr("Diskon 40% s/d 30 Juni")},
		{Name: "Infus Brightening 2x", Category: "brightening", Price: 695000,
			Description: "Paket dua sesi infus vitamin untuk mencerahkan kulit.", Promo: strPtr("Diskon 40% s/d 30 Juni")},
		{Name: "Glowtox (Skinbooster + Botox)", Category: "anti-aging", Price: 1250000,
			Description: "Treatment baru: skinbooster + botox untuk pori dan minyak.", Promo: strPtr("Hemat 50% (normal Rp 2.500.000)"), RequiresDoctor: true},
		{Name: "Botox Allergan Full Face", Category: "anti-aging", Price: 4800000,
			Description: "Botox full face dengan produk Allergan.", Promo: strPtr("Hemat 38% (normal Rp 7.800.000)"), RequiresDoctor: true},
		{Name: "IPL Hair Removal Underarm 4x", Category: "hair-removal", Price: 475000,
			Description: "Paket 4 sesi hair removal area ketiak.", Promo: strPtr("Diskon 50% s/d 30 Juni")},
	}
	if err := db.Create(&treatments).Error; err != nil {
		return err
	}

	hours := []model.ClinicHours{
		{Weekday: 0, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 1, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 2, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 3, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 4, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 5, OpenTime: "10:00", CloseTime: "18:00"},
		{Weekday: 6, OpenTime: "10:00", CloseTime: "16:00"},
	}
	if err := db.Create(&hours).Error; err != nil {
		return err
	}

	doctors := []model.DoctorSchedule{
		{DoctorName: "Dr. Amara, SpDVE", Weekday: 0, StartTime: "12:00", EndTime: "16:00"},
		{DoctorName: "Dr. Sinta", Weekday: 1, StartTime: "11:00", EndTime: "17:00"},
		{DoctorName: "Dr. Amara, SpDVE", Weekday: 2, StartTime: "12:00", EndTime: "16:00"},
		{DoctorName: "Dr. Sinta", Weekday: 3, StartTime: "11:00", EndTime: "17:00"},
		{DoctorName: "Dr. Amara, SpDVE", Weekday: 4, StartTime: "12:00", EndTime: "16:00"},
		{DoctorName: "Dr. Sinta", Weekday: 5, StartTime: "11:00", EndTime: "17:00"},
		{DoctorName: "Dr. Sinta", Weekday: 6, StartTime: "11:00", EndTime: "15:00"},
	}
	if err := db.Create(&doctors).Error; err != nil {
		return err
	}

	specials := []model.SpecialSchedule{
		{ScheduleDate: "2026-06-22", DoctorName: strPtr("Dr. Amara, SpDVE"), DoctorStart: strPtr("14:30"), DoctorEnd: strPtr("16:00"),
			Note: strPtr("Dokter hanya praktek 1,5 jam. Sarankan jam 14:30 ke atas untuk treatment dokter.")},
		{ScheduleDate: "2026-06-24", IsClosed: true, Note: strPtr("KLINIK TUTUP TOTAL")},
		{ScheduleDate: "2026-06-25", IsClosed: true, Note: strPtr("KLINIK TUTUP TOTAL")},
		{ScheduleDate: "2026-06-26", IsClosed: true, Note: strPtr("KLINIK TUTUP TOTAL")},
		{ScheduleDate: "2026-06-27", DoctorName: strPtr("Dr. Sinta"), DoctorStart: strPtr("12:00"), DoctorEnd: strPtr("17:00"),
			Note: strPtr("Dokter mulai lebih siang. Treatment butuh dokter: sarankan jam 12:00 ke atas.")},
	}
	return db.Create(&specials).Error
}
```

- [ ] **Step 5: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/db/...
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/model internal/db
git commit -m "feat: implement database models, migrations, and default clinic seed"
```

---

### Task 3: Clinic Tools Logic & Gemini Function Declarations

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/tools.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/declarations.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/tools_test.go`

**Interfaces:**
- Consumes: `gorm.DB`, `model.*`
- Produces: `tools.NewToolService(db *gorm.DB) *ToolService` with methods:
  - `SearchTreatments(query string) map[string]any`
  - `CheckAvailableSchedule(bookingDate string) map[string]any`
  - `BookTreatment(customerName, phone, treatmentName, bookingDate, bookingTime string) map[string]any`
  - `GetMyOrders(phone string) map[string]any`
  - `CancelBooking(bookingCode, reason string) map[string]any`
  - `HandoverToAdmin(phone, reason string) map[string]any`
  - `GetFunctionDeclarations() []*genai.FunctionDeclaration`

- [ ] **Step 1: Write failing unit test covering all tool checkpoint scenarios**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/tools_test.go`
```go
package tools

import (
	"testing"

	"github.com/raygbrn/ai-sales-agent-go/internal/db"
)

func setupTestDB(t *testing.T) *ToolService {
	database, err := db.InitDB("sqlite://file::memory:?cache=shared")
	if err != nil {
		t.Fatalf("db init failed: %v", err)
	}
	if err := db.SeedDB(database); err != nil {
		t.Fatalf("seed failed: %v", err)
	}
	return NewToolService(database)
}

func TestSearchTreatments(t *testing.T) {
	ts := setupTestDB(t)
	res := ts.SearchTreatments("acne")
	if found, ok := res["found"].(bool); !ok || !found {
		t.Errorf("expected acne treatments found, got %v", res)
	}
}

func TestBookingCapacityAndConflict(t *testing.T) {
	ts := setupTestDB(t)

	// Book 3 slots on 2026-06-15 at 14:00 (capacity 3)
	for _, name := range []string{"Rani", "Sari", "Dewi"} {
		res := ts.BookTreatment(name, "62812000"+name, "Facial Acne", "2026-06-15", "14:00")
		if success, _ := res["success"].(bool); !success {
			t.Fatalf("booking failed for %s: %v", name, res)
		}
	}

	// 4th booking at same time must return SLOT_CONFLICT
	res4 := ts.BookTreatment("Putu", "62812000Putu", "Facial Acne", "2026-06-15", "14:00")
	if success, _ := res4["success"].(bool); success {
		t.Errorf("expected 4th booking to fail, but succeeded")
	}
	if errCode, _ := res4["error"].(string); errCode != "SLOT_CONFLICT" {
		t.Errorf("expected error SLOT_CONFLICT, got %s", errCode)
	}
	if nextSlot, _ := res4["next_available_slot"].(string); nextSlot != "15:30" {
		t.Errorf("expected next_available_slot 15:30, got %s", nextSlot)
	}
}

func TestSpecialScheduleClosed(t *testing.T) {
	ts := setupTestDB(t)
	// 2026-06-25 is marked as closed in special schedule
	res := ts.BookTreatment("Putu", "62812000Putu", "Facial Acne", "2026-06-25", "14:00")
	if success, _ := res["success"].(bool); success {
		t.Errorf("expected booking on closed clinic date to fail")
	}
	if errCode, _ := res["error"].(string); errCode != "CLINIC_CLOSED" {
		t.Errorf("expected CLINIC_CLOSED, got %s", errCode)
	}
}

func TestCancelBookingAndReopen(t *testing.T) {
	ts := setupTestDB(t)
	// Book 3 slots
	var codeToCancel string
	for i, name := range []string{"Rani", "Sari", "Dewi"} {
		res := ts.BookTreatment(name, "62812000"+name, "Facial Acne", "2026-06-15", "14:00")
		if i == 0 {
			codeToCancel = res["booking_code"].(string)
		}
	}

	// Cancel Rani
	cancelRes := ts.CancelBooking(codeToCancel, "berhalangan")
	if success, _ := cancelRes["success"].(bool); !success {
		t.Fatalf("failed to cancel: %v", cancelRes)
	}

	// Now Putu can book at 14:00
	res := ts.BookTreatment("Putu", "62812000Putu", "Facial Acne", "2026-06-15", "14:00")
	if success, _ := res["success"].(bool); !success {
		t.Errorf("expected booking to succeed after cancellation, got %v", res)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/tools/...
```
Expected: FAIL.

- [ ] **Step 3: Implement ToolService and schedule calculation logic**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/tools.go`
```go
package tools

import (
	"fmt"
	"math/rand"
	"strings"
	"time"

	"gorm.io/gorm"

	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

var Hari = []string{"Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"}

type ToolService struct {
	db *gorm.DB
}

func NewToolService(database *gorm.DB) *ToolService {
	return &ToolService{db: database}
}

func parseTimeMinutes(s string) int {
	var h, m int
	_, _ = fmt.Sscanf(s, "%d:%d", &h, &m)
	return h*60 + m
}

func formatMinutes(m int) string {
	return fmt.Sprintf("%02d:%02d", m/60, m%60)
}

type dayRules struct {
	IsClosed    bool
	Open        string
	Close       string
	DoctorName  *string
	DoctorStart *string
	DoctorEnd   *string
	Note        *string
}

func (ts *ToolService) getDayRules(d time.Time, dateStr string) dayRules {
	weekday := int(d.Weekday()) - 1
	if weekday < 0 {
		weekday = 6 // Minggu = 6
	}

	var hours model.ClinicHours
	err := ts.db.Where("weekday = ?", weekday).First(&hours).Error

	rules := dayRules{
		IsClosed: err != nil,
		Open:     hours.OpenTime,
		Close:    hours.CloseTime,
	}

	var doc model.DoctorSchedule
	if err := ts.db.Where("weekday = ?", weekday).First(&doc).Error; err == nil {
		rules.DoctorName = &doc.DoctorName
		rules.DoctorStart = &doc.StartTime
		rules.DoctorEnd = &doc.EndTime
	}

	var special model.SpecialSchedule
	if err := ts.db.Where("schedule_date = ?", dateStr).First(&special).Error; err == nil {
		rules.Note = special.Note
		if special.IsClosed {
			rules.IsClosed = true
		}
		if special.OpenTime != nil {
			rules.Open = *special.OpenTime
		}
		if special.CloseTime != nil {
			rules.Close = *special.CloseTime
		}
		if special.DoctorName != nil {
			rules.DoctorName = special.DoctorName
			rules.DoctorStart = special.DoctorStart
			rules.DoctorEnd = special.DoctorEnd
		}
	}

	return rules
}

func (ts *ToolService) countOverlap(dateStr, start string, duration int) int {
	s1 := parseTimeMinutes(start)
	e1 := s1 + duration

	var bookings []model.Booking
	ts.db.Where("booking_date = ? AND status != ?", dateStr, "cancelled").Find(&bookings)

	count := 0
	for _, b := range bookings {
		s2 := parseTimeMinutes(b.BookingTime)
		e2 := s2 + b.DurationMinutes
		if s1 < e2 && s2 < e1 {
			count++
		}
	}
	return count
}

func (ts *ToolService) nextAvailableSlot(d time.Time, dateStr, after string, rules dayRules) *string {
	lastValid := parseTimeMinutes(rules.Close) - model.TreatmentDurationMinutes
	m := parseTimeMinutes(after) + 30
	m += (30 - m%30) % 30

	for m <= lastValid {
		slotTime := formatMinutes(m)
		if ts.countOverlap(dateStr, slotTime, model.TreatmentDurationMinutes) < model.MaxConcurrent {
			return &slotTime
		}
		m += 30
	}
	return nil
}

func generateBookingCode() string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	suffix := make([]byte, 4)
	for i := range suffix {
		suffix[i] = charset[rand.Intn(len(charset))]
	}
	return fmt.Sprintf("GLW-%s-%s", time.Now().Format("20060102"), string(suffix))
}

func (ts *ToolService) SearchTreatments(query string) map[string]any {
	q := "%" + strings.ToLower(query) + "%"
	var treatments []model.Treatment
	ts.db.Where("LOWER(name) LIKE ? OR LOWER(category) LIKE ? OR LOWER(description) LIKE ?", q, q, q).Find(&treatments)

	if len(treatments) == 0 {
		return map[string]any{
			"found":   false,
			"message": fmt.Sprintf("Tidak ada treatment yang cocok dengan '%s'.", query),
		}
	}

	var results []map[string]any
	for _, t := range treatments {
		results = append(results, map[string]any{
			"id":               t.ID,
			"name":             t.Name,
			"price":            t.Price,
			"duration_minutes": model.TreatmentDurationMinutes,
			"description":      t.Description,
			"promo":            t.Promo,
			"requires_doctor":  t.RequiresDoctor,
		})
	}
	return map[string]any{"found": true, "treatments": results}
}

func (ts *ToolService) CheckAvailableSchedule(bookingDate string) map[string]any {
	d, err := time.Parse("2006-01-02", bookingDate)
	if err != nil {
		return map[string]any{"status": "ERROR", "message": "Format tanggal salah. Gunakan YYYY-MM-DD"}
	}

	weekday := int(d.Weekday()) - 1
	if weekday < 0 {
		weekday = 6
	}
	dayName := Hari[weekday]

	rules := ts.getDayRules(d, bookingDate)
	if rules.IsClosed {
		return map[string]any{
			"status": "CLINIC_CLOSED",
			"date":   bookingDate,
			"day":    dayName,
			"note":   rules.Note,
		}
	}

	lastValid := parseTimeMinutes(rules.Close) - model.TreatmentDurationMinutes
	m := parseTimeMinutes(rules.Open)

	now := time.Now()
	if bookingDate == now.Format("2006-01-02") {
		nowM := now.Hour()*60 + now.Minute()
		if m < nowM {
			m = nowM + (30-nowM%30)%30
		}
	}

	var slots []map[string]any
	for m <= lastValid {
		slotTime := formatMinutes(m)
		used := ts.countOverlap(bookingDate, slotTime, model.TreatmentDurationMinutes)
		if used < model.MaxConcurrent {
			slots = append(slots, map[string]any{
				"start":              slotTime,
				"end":                formatMinutes(m + model.TreatmentDurationMinutes),
				"remaining_capacity": model.MaxConcurrent - used,
			})
		}
		m += 30
	}

	var doctorInfo any = nil
	if rules.DoctorName != nil {
		doctorInfo = map[string]any{
			"name":  *rules.DoctorName,
			"start": *rules.DoctorStart,
			"end":   *rules.DoctorEnd,
		}
	}

	return map[string]any{
		"status":          "OK",
		"date":            bookingDate,
		"day":             dayName,
		"open":            rules.Open,
		"close":           rules.Close,
		"last_valid_slot": formatMinutes(lastValid),
		"doctor_on_duty":  doctorInfo,
		"available_slots": slots,
		"all_full":        len(slots) == 0,
		"max_concurrent":  model.MaxConcurrent,
		"note":            rules.Note,
	}
}

func (ts *ToolService) BookTreatment(customerName, phone, treatmentName, bookingDate, bookingTime string) map[string]any {
	d, err := time.Parse("2006-01-02", bookingDate)
	if err != nil {
		return map[string]any{"success": false, "error": "INVALID_DATE", "message": "Format tanggal salah. Gunakan YYYY-MM-DD"}
	}

	weekday := int(d.Weekday()) - 1
	if weekday < 0 {
		weekday = 6
	}
	dayName := Hari[weekday]

	rules := ts.getDayRules(d, bookingDate)
	if rules.IsClosed {
		msg := fmt.Sprintf("Klinik tutup pada %s, %s.", dayName, bookingDate)
		if rules.Note != nil {
			msg += " Catatan: " + *rules.Note
		}
		return map[string]any{"success": false, "error": "CLINIC_CLOSED", "message": msg}
	}

	startM := parseTimeMinutes(bookingTime)
	now := time.Now()
	todayStr := now.Format("2006-01-02")
	nowM := now.Hour()*60 + now.Minute()

	if bookingDate < todayStr || (bookingDate == todayStr && startM <= nowM) {
		var nextSlot *string
		if bookingDate == todayStr {
			nextSlot = ts.nextAvailableSlot(d, bookingDate, formatMinutes(nowM), rules)
		}
		return map[string]any{
			"success":             false,
			"error":               "PAST_TIME",
			"message":             fmt.Sprintf("Jam %s pada %s sudah lewat. Tidak bisa booking untuk waktu yang sudah berlalu.", bookingTime, bookingDate),
			"next_available_slot": nextSlot,
		}
	}

	lastValid := parseTimeMinutes(rules.Close) - model.TreatmentDurationMinutes
	if startM < parseTimeMinutes(rules.Open) || startM > lastValid {
		return map[string]any{
			"success": false,
			"error":   "OUTSIDE_HOURS",
			"message": fmt.Sprintf("Jam %s tidak valid. Klinik buka %s-%s, slot terakhir %s (treatment %d menit harus selesai sebelum tutup).",
				bookingTime, rules.Open, rules.Close, formatMinutes(lastValid), model.TreatmentDurationMinutes),
		}
	}

	var treatment model.Treatment
	if err := ts.db.Where("LOWER(name) LIKE ?", "%"+strings.ToLower(treatmentName)+"%").First(&treatment).Error; err != nil {
		return map[string]any{
			"success": false,
			"error":   "TREATMENT_NOT_FOUND",
			"message": fmt.Sprintf("Treatment '%s' tidak ditemukan. Gunakan search_treatments untuk daftar yang tersedia.", treatmentName),
		}
	}

	// Transaction to protect capacity race
	var booking model.Booking
	var nextSlot *string
	err = ts.db.Transaction(func(tx *gorm.DB) error {
		used := 0
		var existingBookings []model.Booking
		tx.Where("booking_date = ? AND status != ?", bookingDate, "cancelled").Find(&existingBookings)
		e1 := startM + model.TreatmentDurationMinutes
		for _, b := range existingBookings {
			s2 := parseTimeMinutes(b.BookingTime)
			e2 := s2 + b.DurationMinutes
			if startM < e2 && s2 < e1 {
				used++
			}
		}

		if used >= model.MaxConcurrent {
			nextSlot = ts.nextAvailableSlot(d, bookingDate, bookingTime, rules)
			return fmt.Errorf("SLOT_CONFLICT")
		}

		booking = model.Booking{
			Code:            generateBookingCode(),
			CustomerName:    customerName,
			Phone:           phone,
			TreatmentID:     treatment.ID,
			BookingDate:     bookingDate,
			BookingTime:     bookingTime,
			DurationMinutes: model.TreatmentDurationMinutes,
			Status:          "pending",
		}
		if err := tx.Create(&booking).Error; err != nil {
			return err
		}

		var contact model.Contact
		if err := tx.Where("phone = ?", phone).First(&contact).Error; err == nil {
			if contact.Name == nil || *contact.Name == "" {
				contact.Name = &customerName
			}
			contact.IsReturning = true
			tx.Save(&contact)
		} else {
			tx.Create(&model.Contact{
				Phone:       phone,
				Name:        &customerName,
				AiEnabled:   true,
				IsReturning: true,
			})
		}
		return nil
	})

	if err != nil {
		if err.Error() == "SLOT_CONFLICT" {
			return map[string]any{
				"success":             false,
				"error":               "SLOT_CONFLICT",
				"message":             fmt.Sprintf("Jam %s sudah penuh.", bookingTime),
				"next_available_slot": nextSlot,
			}
		}
		return map[string]any{"success": false, "error": "DB_ERROR", "message": err.Error()}
	}

	var doctorInfo any = nil
	if rules.DoctorName != nil {
		ds := parseTimeMinutes(*rules.DoctorStart)
		de := parseTimeMinutes(*rules.DoctorEnd)
		onDuty := ds <= startM && startM < de
		doctorInfo = map[string]any{
			"name":                    *rules.DoctorName,
			"on_duty_at_booking_time": onDuty,
			"hours":                   fmt.Sprintf("%s-%s", *rules.DoctorStart, *rules.DoctorEnd),
		}
	}

	return map[string]any{
		"success":       true,
		"booking_code":  booking.Code,
		"customer_name": customerName,
		"treatment":     treatment.Name,
		"price":         treatment.Price,
		"date":          bookingDate,
		"day":           dayName,
		"time":          bookingTime,
		"end_time":      formatMinutes(startM + model.TreatmentDurationMinutes),
		"doctor":        doctorInfo,
		"status":        "pending",
	}
}

func (ts *ToolService) GetMyOrders(phone string) map[string]any {
	var bookings []model.Booking
	ts.db.Preload("Treatment").Where("phone = ?", phone).Order("booking_date DESC").Find(&bookings)

	if len(bookings) == 0 {
		return map[string]any{"found": false, "message": "Tidak ada riwayat booking untuk nomor ini."}
	}

	var list []map[string]any
	for _, b := range bookings {
		list = append(list, map[string]any{
			"booking_code": b.Code,
			"treatment":    b.Treatment.Name,
			"date":         b.BookingDate,
			"time":         b.BookingTime,
			"status":       b.Status,
		})
	}
	return map[string]any{"found": true, "bookings": list}
}

func (ts *ToolService) CancelBooking(bookingCode, reason string) map[string]any {
	var booking model.Booking
	if err := ts.db.Where("code = ?", bookingCode).First(&booking).Error; err != nil {
		return map[string]any{"success": false, "error": "NOT_FOUND", "message": fmt.Sprintf("Booking %s tidak ditemukan.", bookingCode)}
	}
	if booking.Status == "cancelled" {
		return map[string]any{"success": false, "error": "ALREADY_CANCELLED", "message": "Booking ini sudah dibatalkan sebelumnya."}
	}

	booking.Status = "cancelled"
	ts.db.Save(&booking)
	return map[string]any{
		"success":      true,
		"booking_code": bookingCode,
		"message":      "Booking berhasil dibatalkan.",
		"reason":       reason,
	}
}

func (ts *ToolService) HandoverToAdmin(phone, reason string) map[string]any {
	var contact model.Contact
	if err := ts.db.Where("phone = ?", phone).First(&contact).Error; err == nil {
		contact.AiEnabled = false
		ts.db.Save(&contact)
	} else {
		ts.db.Create(&model.Contact{
			Phone:     phone,
			AiEnabled: false,
		})
	}
	return map[string]any{
		"success":            true,
		"ai_disabled_for":    phone,
		"reason":             reason,
		"message":            "AI dinonaktifkan untuk nomor ini. Admin telah dinotifikasi.",
	}
}
```

- [ ] **Step 4: Implement Gemini Function Declarations**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/tools/declarations.go`
```go
package tools

import "google.golang.org/genai"

func (ts *ToolService) GetFunctionDeclarations() []*genai.FunctionDeclaration {
	return []*genai.FunctionDeclaration{
		{
			Name: "search_treatments",
			Description: "Cari treatment, paket, atau layanan konsultasi yang tersedia di klinik " +
				"berdasarkan kata kunci (nama, kategori seperti 'acne'/'brightening', atau keluhan). " +
				"WAJIB dipanggil sebelum menyebut nama/harga treatment apapun ke customer. Jangan pernah mengarang treatment dari ingatan.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"query": {
						Type:        genai.TypeString,
						Description: "Kata kunci, contoh: 'acne', 'botox', 'konsultasi', 'brightening'",
					},
				},
				Required: []string{"query"},
			},
		},
		{
			Name: "check_available_schedule",
			Description: "Cek slot tersedia untuk satu tanggal (MODE B: HANYA saat customer belum " +
				"menyebut jam spesifik, atau saat butuh next_available_slot). Mengembalikan jam buka/tutup, " +
				"dokter yang bertugas, daftar slot dengan sisa kapasitas, dan catatan jadwal khusus.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"booking_date": {
						Type:        genai.TypeString,
						Description: "Tanggal format YYYY-MM-DD, contoh: 2026-06-15",
					},
				},
				Required: []string{"booking_date"},
			},
		},
		{
			Name: "book_treatment",
			Description: "Buat booking treatment/konsultasi. Ini SATU-SATUNYA konfirmasi final " +
				"ketersediaan slot (atomic check). Panggil HANYA setelah semua data lengkap dan " +
				"customer konfirmasi recap. Jika hasilnya SLOT_CONFLICT, tawarkan next_available_slot dari hasil tool, JANGAN mengarang jam.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"customer_name":  {Type: genai.TypeString, Description: "Nama customer"},
					"phone":          {Type: genai.TypeString, Description: "Nomor WhatsApp customer (otomatis dari konteks, jangan tanya)"},
					"treatment_name": {Type: genai.TypeString, Description: "Nama treatment persis dari hasil search_treatments"},
					"booking_date":   {Type: genai.TypeString, Description: "Format YYYY-MM-DD"},
					"booking_time":   {Type: genai.TypeString, Description: "Format HH:MM, contoh: 14:00"},
				},
				Required: []string{"customer_name", "phone", "treatment_name", "booking_date", "booking_time"},
			},
		},
		{
			Name: "get_my_orders",
			Description: "Ambil riwayat booking customer berdasarkan nomor WhatsApp. Dipakai saat " +
				"customer tanya booking mereka, mau reschedule, atau mau cancel. " +
				"Jika data tidak ditemukan padahal customer yakin pernah booking -> handover.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"phone": {Type: genai.TypeString, Description: "Nomor WhatsApp customer"},
				},
				Required: []string{"phone"},
			},
		},
		{
			Name:        "cancel_booking",
			Description: "Batalkan booking berdasarkan kode booking (dapatkan dari get_my_orders dulu).",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"booking_code": {Type: genai.TypeString, Description: "Kode booking, contoh: GLW-20260613-A3F1"},
					"reason":       {Type: genai.TypeString, Description: "Alasan pembatalan dari customer"},
				},
				Required: []string{"booking_code"},
			},
		},
		{
			Name: "handover_to_admin",
			Description: "Alihkan percakapan ke admin manusia dan nonaktifkan AI untuk nomor ini. " +
				"Panggil saat: customer minta bicara admin, komplain berat, data yang ditanya tidak ada di sistem " +
				"(maksimal 1x coba tool lain dulu), atau situasi di luar kemampuan.",
			Parameters: &genai.Schema{
				Type: genai.TypeObject,
				Properties: map[string]*genai.Schema{
					"phone":  {Type: genai.TypeString, Description: "Nomor WhatsApp customer"},
					"reason": {Type: genai.TypeString, Description: "Alasan handover untuk dicatat ke admin"},
				},
				Required: []string{"phone", "reason"},
			},
		},
	}
}

func (ts *ToolService) ExecuteTool(name string, args map[string]any) map[string]any {
	switch name {
	case "search_treatments":
		q, _ := args["query"].(string)
		return ts.SearchTreatments(q)
	case "check_available_schedule":
		d, _ := args["booking_date"].(string)
		return ts.CheckAvailableSchedule(d)
	case "book_treatment":
		name, _ := args["customer_name"].(string)
		phone, _ := args["phone"].(string)
		tName, _ := args["treatment_name"].(string)
		date, _ := args["booking_date"].(string)
		time, _ := args["booking_time"].(string)
		return ts.BookTreatment(name, phone, tName, date, time)
	case "get_my_orders":
		phone, _ := args["phone"].(string)
		return ts.GetMyOrders(phone)
	case "cancel_booking":
		code, _ := args["booking_code"].(string)
		reason, _ := args["reason"].(string)
		return ts.CancelBooking(code, reason)
	case "handover_to_admin":
		phone, _ := args["phone"].(string)
		reason, _ := args["reason"].(string)
		return ts.HandoverToAdmin(phone, reason)
	default:
		return map[string]any{"error": fmt.Sprintf("Tool '%s' tidak dikenal.", name)}
	}
}
```

- [ ] **Step 5: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/tools/...
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/tools
git commit -m "feat: implement clinic tools logic, overlap capacity engine, and tool declarations"
```

---

### Task 4: Memory Management (Sliding Window & Takeover State)

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/memory/memory.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/memory/memory_test.go`

**Interfaces:**
- Consumes: `gorm.DB`, `model.*`
- Produces: `memory.NewMemory(db *gorm.DB, window, ttlHours int) *Memory` with methods:
  - `GetHistory(phone string) []*genai.Content`
  - `Add(phone, role, text string) error`
  - `IsAIEnabled(phone string) bool`
  - `SetAIEnabled(phone string, enabled bool) error`
  - `SetName(phone, name string) error`
  - `GetContactName(phone string) *string`

- [ ] **Step 1: Write failing unit test for memory**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/memory/memory_test.go`
```go
package memory

import (
	"testing"
	"time"

	"github.com/raygbrn/ai-sales-agent-go/internal/db"
	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

func TestMemorySlidingWindow(t *testing.T) {
	database, _ := db.InitDB("sqlite://file::memory:?cache=shared")
	mem := NewMemory(database, 10, 24)

	phone := "628111"
	for i := 0; i < 25; i++ {
		role := "user"
		if i%2 == 1 {
			role = "model"
		}
		_ = mem.Add(phone, role, "msg")
	}

	history := mem.GetHistory(phone)
	if len(history) != 10 {
		t.Errorf("expected 10 messages in sliding window, got %d", len(history))
	}
}

func TestMemoryTakeover(t *testing.T) {
	database, _ := db.InitDB("sqlite://file::memory:?cache=shared")
	mem := NewMemory(database, 20, 24)

	phone := "628222"
	if !mem.IsAIEnabled(phone) {
		t.Errorf("default AI enabled should be true")
	}

	_ = mem.SetAIEnabled(phone, false)
	if mem.IsAIEnabled(phone) {
		t.Errorf("expected AI enabled false after handover")
	}

	_ = mem.SetAIEnabled(phone, true)
	if !mem.IsAIEnabled(phone) {
		t.Errorf("expected AI enabled true after admin enables")
	}
}

func TestMemorySessionTTL(t *testing.T) {
	database, _ := db.InitDB("sqlite://file::memory:?cache=shared")
	mem := NewMemory(database, 20, 1) // 1 hour TTL

	phone := "628333"
	oldTime := time.Now().Add(-2 * time.Hour)
	database.Create(&model.ConversationMessage{
		Phone:     phone,
		Role:      "user",
		Text:      "old message",
		CreatedAt: oldTime,
	})

	history := mem.GetHistory(phone)
	if len(history) != 0 {
		t.Errorf("expected empty history due to TTL expiry, got %d", len(history))
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/memory/...
```
Expected: FAIL.

- [ ] **Step 3: Implement Memory**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/memory/memory.go`
```go
package memory

import (
	"time"

	"google.golang.org/genai"
	"gorm.io/gorm"

	"github.com/raygbrn/ai-sales-agent-go/internal/model"
)

type Memory struct {
	db       *gorm.DB
	window   int
	ttlHours int
}

func NewMemory(db *gorm.DB, window, ttlHours int) *Memory {
	return &Memory{db: db, window: window, ttlHours: ttlHours}
}

func (m *Memory) GetHistory(phone string) []*genai.Content {
	var rows []model.ConversationMessage
	m.db.Where("phone = ?", phone).Order("created_at DESC").Limit(m.window).Find(&rows)

	if len(rows) == 0 {
		return []*genai.Content{}
	}

	// Reverse to chronological order
	for i, j := 0, len(rows)-1; i < j; i, j = i+1, j-1 {
		rows[i], rows[j] = rows[j], rows[i]
	}

	if m.ttlHours > 0 {
		lastMsg := rows[len(rows)-1]
		if time.Since(lastMsg.CreatedAt) > time.Duration(m.ttlHours)*time.Hour {
			return []*genai.Content{}
		}
	}

	var contents []*genai.Content
	for _, row := range rows {
		contents = append(contents, &genai.Content{
			Role: row.Role,
			Parts: []*genai.Part{
				{Text: row.Text},
			},
		})
	}
	return contents
}

func (m *Memory) Add(phone, role, text string) error {
	msg := model.ConversationMessage{
		Phone: phone,
		Role:  role,
		Text:  text,
	}
	return m.db.Create(&msg).Error
}

func (m *Memory) IsAIEnabled(phone string) bool {
	var contact model.Contact
	if err := m.db.Where("phone = ?", phone).First(&contact).Error; err != nil {
		return true
	}
	return contact.AiEnabled
}

func (m *Memory) SetAIEnabled(phone string, enabled bool) error {
	var contact model.Contact
	if err := m.db.Where("phone = ?", phone).First(&contact).Error; err == nil {
		contact.AiEnabled = enabled
		return m.db.Save(&contact).Error
	}
	return m.db.Create(&model.Contact{
		Phone:     phone,
		AiEnabled: enabled,
	}).Error
}

func (m *Memory) SetName(phone, name string) error {
	if name == "" {
		return nil
	}
	var contact model.Contact
	if err := m.db.Where("phone = ?", phone).First(&contact).Error; err == nil {
		if contact.Name == nil || *contact.Name != name {
			contact.Name = &name
			return m.db.Save(&contact).Error
		}
		return nil
	}
	return m.db.Create(&model.Contact{
		Phone:     phone,
		Name:      &name,
		AiEnabled: true,
	}).Error
}

func (m *Memory) GetContactName(phone string) *string {
	var contact model.Contact
	if err := m.db.Where("phone = ?", phone).First(&contact).Error; err != nil {
		return nil
	}
	return contact.Name
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/memory/...
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/memory
git commit -m "feat: implement conversation memory sliding window and takeover state"
```

---

### Task 5: Gemini Agent Core Loop & System Prompt Renderer

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/agent.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/prompt.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/prompt_test.go`

**Interfaces:**
- Consumes: `config.Config`, `tools.ToolService`, `google.golang.org/genai`
- Produces: `agent.NewAgent(cfg *config.Config, ts *tools.ToolService, promptPath string) (*Agent, error)` with method:
  - `RunAgent(ctx context.Context, history []*genai.Content, userMessage, phone string, images []ImageData) (string, []*genai.Content, error)`

- [ ] **Step 1: Write test for system prompt rendering**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/prompt_test.go`
```go
package agent

import (
	"strings"
	"testing"
)

func TestRenderSystemPrompt(t *testing.T) {
	promptPath := "../../prompts/system.md"
	rendered, err := RenderSystemPrompt(promptPath, "Gita", "Glowria Aesthetic Clinic")
	if err != nil {
		t.Fatalf("failed to render prompt: %v", err)
	}

	if strings.Contains(rendered, "{{aiName}}") {
		t.Errorf("unrendered {{aiName}} remains in prompt")
	}
	if !strings.Contains(rendered, "Gita") {
		t.Errorf("expected Gita in rendered prompt")
	}
	if !strings.Contains(rendered, "Glowria Aesthetic Clinic") {
		t.Errorf("expected Glowria Aesthetic Clinic in rendered prompt")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/agent/...
```
Expected: FAIL.

- [ ] **Step 3: Implement prompt renderer and Agent loop**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/prompt.go`
```go
package agent

import (
	"os"
	"strings"
)

func RenderSystemPrompt(path, aiName, companyName string) (string, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	raw := string(bytes)

	replacements := map[string]string{
		"{{aiName}}":      aiName,
		"{{companyName}}": companyName,
		"{{currentDateContext}}": "Tanggal dan jam SAAT INI selalu diberikan di awal setiap pesan customer " +
			"(dalam tanda [Konteks: ...]). Jadikan itu satu-satunya acuan waktu untuk " +
			"menghitung 'hari ini', 'besok', 'lusa', dll. JANGAN PERNAH menawarkan atau " +
			"menyetujui booking untuk jam yang sudah lewat.",
		"{{bookingContext}}": "<booking_context>Gunakan tool check_available_schedule dan " +
			"book_treatment untuk status slot real-time. Jangan pernah berasumsi soal ketersediaan tanpa hasil tool.</booking_context>",
		"{{leadContext}}":         "Lihat info customer di awal percakapan.",
		"{{conversationSummary}}": "Lihat history percakapan di contents.",
		"{{knowledgeBase}}": "Gunakan tool search_treatments untuk data treatment dan harga. " +
			"Info klinik statis ada di <clinic_info>.",
		"{{additionalContext}}": "",
	}

	for k, v := range replacements {
		raw = strings.ReplaceAll(raw, k, v)
	}
	return raw, nil
}
```

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/agent/agent.go`
```go
package agent

import (
	"context"
	"fmt"
	"log"
	"time"

	"google.golang.org/genai"

	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/tools"
)

const (
	MaxToolIterations = 5
	FallbackMessage   = "Mohon maaf kak, whatsapp kami sedang ada sedikit kendala🙏[NEXT]" +
		"Admin kami akan segera membantu ya kak 😊[HANDOVER]"
)

var (
	HariNama  = []string{"Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"}
	BulanNama = []string{"Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli",
		"Agustus", "September", "Oktober", "November", "Desember"}
)

type ImageData struct {
	Bytes    []byte
	MIMEType string
}

type Agent struct {
	client       *genai.Client
	model        string
	systemPrompt string
	tools        *tools.ToolService
	genConfig    *genai.GenerateContentConfig
}

func NewAgent(cfg *config.Config, ts *tools.ToolService, promptPath string) (*Agent, error) {
	sysPrompt, err := RenderSystemPrompt(promptPath, cfg.AIName, cfg.CompanyName)
	if err != nil {
		return nil, fmt.Errorf("failed to render system prompt: %w", err)
	}

	ctx := context.Background()
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey:  cfg.GeminiAPIKey,
		Backend: genai.BackendGeminiAPI,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize genai client: %w", err)
	}

	genConfig := &genai.GenerateContentConfig{
		SystemInstruction: &genai.Content{
			Parts: []*genai.Part{{Text: sysPrompt}},
		},
		Tools: []*genai.Tool{
			{FunctionDeclarations: ts.GetFunctionDeclarations()},
		},
		Temperature: genai.Ptr(float32(0.7)),
	}

	return &Agent{
		client:       client,
		model:        cfg.GeminiModel,
		systemPrompt: sysPrompt,
		tools:        ts,
		genConfig:    genConfig,
	}, nil
}

func (a *Agent) RunAgent(ctx context.Context, history []*genai.Content, userMessage, phone string, images []ImageData) (string, []*genai.Content, error) {
	now := time.Now()
	weekday := int(now.Weekday()) - 1
	if weekday < 0 {
		weekday = 6
	}

	dateCtx := fmt.Sprintf("Hari ini %s, %d %s %d (%s), pukul %02d:%02d",
		HariNama[weekday], now.Day(), BulanNama[now.Month()-1], now.Year(),
		now.Format("2006-01-02"), now.Hour(), now.Minute())

	if userMessage == "" {
		userMessage = "(customer mengirim gambar tanpa teks)"
	}

	parts := []*genai.Part{
		{Text: fmt.Sprintf("[Konteks: %s. Nomor WhatsApp customer: %s]\n%s", dateCtx, phone, userMessage)},
	}
	for _, img := range images {
		parts = append(parts, &genai.Part{
			InlineData: &genai.Blob{
				MIMEType: img.MIMEType,
				Data:     img.Bytes,
			},
		})
	}

	contents := append([]*genai.Content{}, history...)
	contents = append(contents, &genai.Content{Role: "user", Parts: parts})

	for iter := 0; iter < MaxToolIterations; iter++ {
		resp, err := a.client.Models.GenerateContent(ctx, a.model, contents, a.genConfig)
		if err != nil {
			log.Printf("[error] Gemini API error: %v", err)
			return FallbackMessage, contents, err
		}

		if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
			return FallbackMessage, contents, nil
		}

		cand := resp.Candidates[0]
		contents = append(contents, cand.Content)

		functionCalls := cand.Content.FunctionCalls()
		if len(functionCalls) == 0 {
			replyText := resp.Text()
			if replyText == "" {
				replyText = FallbackMessage
			}
			return replyText, contents, nil
		}

		var resultParts []*genai.Part
		for _, fc := range functionCalls {
			log.Printf("  [tool] %s(%v)", fc.Name, fc.Args)
			result := a.tools.ExecuteTool(fc.Name, fc.Args)
			resultParts = append(resultParts, &genai.Part{
				FunctionResponse: &genai.FunctionResponse{
					Name:     fc.Name,
					Response: map[string]any{"result": result},
				},
			})
		}
		contents = append(contents, &genai.Content{Role: "user", Parts: resultParts})
	}

	return FallbackMessage, contents, nil
}
```

- [ ] **Step 4: Run prompt tests to verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/agent/...
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/agent
git commit -m "feat: implement gemini agent core loop and system prompt renderer"
```

---

### Task 6: WhatsApp Evolution API Integration & Debounce Buffer

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/client.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/parser.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/whatsapp_test.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/buffer/buffer.go`

**Interfaces:**
- Consumes: `config.Config`, `agent.Agent`, `memory.Memory`, `storage.Storage`
- Produces:
  - `whatsapp.NewClient(cfg *config.Config) *WhatsAppClient`
  - `whatsapp.ExtractIncoming(payload map[string]any) *IncomingMessage`
  - `whatsapp.SendReply(client *WhatsAppClient, phone, reply string) error`
  - `buffer.NewDebounceBuffer(cfg *config.Config, mem *memory.Memory, ag *agent.Agent, wa *whatsapp.WhatsAppClient, st storage.Storage) *DebounceBuffer`
  - `buffer.Add(incoming *whatsapp.IncomingMessage)`

- [ ] **Step 1: Write test for incoming message parser and bubble split**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/whatsapp_test.go`
```go
package whatsapp

import (
	"testing"
)

func TestExtractIncomingText(t *testing.T) {
	payload := map[string]any{
		"data": map[string]any{
			"key": map[string]any{
				"remoteJid": "628123456789@s.whatsapp.net",
				"fromMe":    false,
			},
			"pushName": "Budi",
			"message": map[string]any{
				"conversation": "Halo apa kabar?",
			},
		},
	}

	msg := ExtractIncoming(payload)
	if msg == nil {
		t.Fatalf("expected message parsed, got nil")
	}
	if msg.Phone != "628123456789" {
		t.Errorf("expected phone 628123456789, got %s", msg.Phone)
	}
	if msg.Text != "Halo apa kabar?" {
		t.Errorf("expected text 'Halo apa kabar?', got %s", msg.Text)
	}
	if msg.Name != "Budi" {
		t.Errorf("expected name Budi, got %s", msg.Name)
	}
}

func TestExtractIncomingIgnoreSelfOrGroup(t *testing.T) {
	// From me
	selfPayload := map[string]any{
		"data": map[string]any{
			"key": map[string]any{
				"remoteJid": "628123456789@s.whatsapp.net",
				"fromMe":    true,
			},
		},
	}
	if ExtractIncoming(selfPayload) != nil {
		t.Errorf("expected nil for fromMe=true")
	}

	// Group message
	groupPayload := map[string]any{
		"data": map[string]any{
			"key": map[string]any{
				"remoteJid": "123456789@g.us",
				"fromMe":    false,
			},
		},
	}
	if ExtractIncoming(groupPayload) != nil {
		t.Errorf("expected nil for group message")
	}
}

func TestSplitBubbles(t *testing.T) {
	text := "Halo kak! [NEXT] Ada yang bisa dibantu?\n\nSilakan cek menu kami."
	bubbles := SplitBubbles(text)
	if len(bubbles) != 3 {
		t.Errorf("expected 3 bubbles, got %d: %v", len(bubbles), bubbles)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/whatsapp/...
```
Expected: FAIL.

- [ ] **Step 3: Implement WhatsApp client and incoming extractor**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/parser.go`
```go
package whatsapp

import (
	"regexp"
	"strings"
)

type IncomingMessage struct {
	Phone     string
	Name      string
	Text      string
	MediaType string // "image" or empty
	Mime      string
	RawData   map[string]any
}

func ExtractIncoming(payload map[string]any) *IncomingMessage {
	data, _ := payload["data"].(map[string]any)
	if data == nil {
		return nil
	}
	key, _ := data["key"].(map[string]any)
	if key == nil {
		return nil
	}
	if fromMe, _ := key["fromMe"].(bool); fromMe {
		return nil
	}

	remoteJid, _ := key["remoteJid"].(string)
	if strings.Contains(remoteJid, "@g.us") || !strings.HasSuffix(remoteJid, "@s.whatsapp.net") {
		return nil
	}

	phone := strings.Split(remoteJid, "@")[0]
	name, _ := data["pushName"].(string)
	message, _ := data["message"].(map[string]any)
	if message == nil {
		return nil
	}

	// Check image message
	if imgMsg, ok := message["imageMessage"].(map[string]any); ok {
		caption, _ := imgMsg["caption"].(string)
		mime, _ := imgMsg["mimetype"].(string)
		if mime == "" {
			mime = "image/jpeg"
		}
		return &IncomingMessage{
			Phone:     phone,
			Name:      name,
			Text:      caption,
			MediaType: "image",
			Mime:      mime,
			RawData:   data,
		}
	}

	// Check regular text message
	text, _ := message["conversation"].(string)
	if text == "" {
		if ext, ok := message["extendedTextMessage"].(map[string]any); ok {
			text, _ = ext["text"].(string)
		}
	}

	if text == "" {
		return nil
	}

	return &IncomingMessage{
		Phone:   phone,
		Name:    name,
		Text:    text,
		RawData: data,
	}
}

var splitRegex = regexp.MustCompile(`\[NEXT\]|\n\s*\n`)

func SplitBubbles(reply string) []string {
	clean := strings.ReplaceAll(reply, "[WAIT]", "")
	clean = strings.ReplaceAll(clean, "[HANDOVER]", "")

	rawBubbles := splitRegex.Split(clean, -1)
	var bubbles []string
	for _, b := range rawBubbles {
		t := strings.TrimSpace(b)
		if t != "" {
			bubbles = append(bubbles, t)
		}
	}
	return bubbles
}
```

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/whatsapp/client.go`
```go
package whatsapp

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/raygbrn/ai-sales-agent-go/internal/config"
)

const (
	TypingSecondsPerChar = 0.03
	TypingMinSeconds     = 1.0
	TypingMaxSeconds     = 5.0
)

type WhatsAppClient struct {
	apiURL   string
	apiKey   string
	instance string
	http     *http.Client
}

func NewWhatsAppClient(cfg *config.Config) *WhatsAppClient {
	return &WhatsAppClient{
		apiURL:   cfg.EvolutionAPIURL,
		apiKey:   cfg.EvolutionAPIKey,
		instance: cfg.EvolutionInstance,
		http:     &http.Client{Timeout: 30 * time.Second},
	}
}

func calculateTypingDuration(text string) time.Duration {
	secs := float64(len(text)) * TypingSecondsPerChar
	if secs < TypingMinSeconds {
		secs = TypingMinSeconds
	}
	if secs > TypingMaxSeconds {
		secs = TypingMaxSeconds
	}
	return time.Duration(secs * float64(time.Second))
}

func (c *WhatsAppClient) SendTyping(phone string, duration time.Duration) {
	url := fmt.Sprintf("%s/chat/sendPresence/%s", c.apiURL, c.instance)
	payload := map[string]any{
		"number":   phone,
		"presence": "composing",
		"delay":    int(duration.Milliseconds()),
	}
	data, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(data))
	if err != nil {
		return
	}
	req.Header.Set("apikey", c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req)
	if err == nil {
		_ = resp.Body.Close()
	}
}

func (c *WhatsAppClient) SendText(phone, text string) error {
	url := fmt.Sprintf("%s/message/sendText/%s", c.apiURL, c.instance)
	payload := map[string]any{
		"number": phone,
		"text":   text,
	}
	data, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(data))
	if err != nil {
		return err
	}
	req.Header.Set("apikey", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("evolution api returned status %d", resp.StatusCode)
	}
	return nil
}

func (c *WhatsAppClient) FetchMediaBase64(message map[string]any) ([]byte, string, error) {
	url := fmt.Sprintf("%s/chat/getBase64FromMediaMessage/%s", c.apiURL, c.instance)
	payload := map[string]any{
		"message":       message,
		"convertToMp4": false,
	}
	data, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(data))
	if err != nil {
		return nil, "", err
	}
	req.Header.Set("apikey", c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()

	var body struct {
		Base64   string `json:"base64"`
		MimeType string `json:"mimetype"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, "", err
	}

	decoded, err := base64.StdEncoding.DecodeString(body.Base64)
	if err != nil {
		return nil, "", err
	}
	mime := body.MimeType
	if mime == "" {
		mime = "image/jpeg"
	}
	return decoded, mime, nil
}

func (c *WhatsAppClient) SendReply(phone, reply string) {
	bubbles := SplitBubbles(reply)
	for _, bubble := range bubbles {
		dur := calculateTypingDuration(bubble)
		c.SendTyping(phone, dur)
		time.Sleep(dur)
		if err := c.SendText(phone, bubble); err != nil {
			log.Printf("[whatsapp] failed to send text to %s: %v", phone, err)
		}
	}
}
```

- [ ] **Step 4: Implement In-Memory Debounce Buffer**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/buffer/buffer.go`
```go
package buffer

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/raygbrn/ai-sales-agent-go/internal/agent"
	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/memory"
	"github.com/raygbrn/ai-sales-agent-go/internal/storage"
	"github.com/raygbrn/ai-sales-agent-go/internal/whatsapp"
)

type DebounceBuffer struct {
	cfg      *config.Config
	mem      *memory.Memory
	agent    *agent.Agent
	wa       *whatsapp.WhatsAppClient
	storage  storage.StorageService
	buffers  map[string][]*whatsapp.IncomingMessage
	timers   map[string]*time.Timer
	locks    map[string]*sync.Mutex
	mapMutex sync.Mutex
}

func NewDebounceBuffer(
	cfg *config.Config,
	mem *memory.Memory,
	ag *agent.Agent,
	wa *whatsapp.WhatsAppClient,
	st storage.StorageService,
) *DebounceBuffer {
	return &DebounceBuffer{
		cfg:     cfg,
		mem:     mem,
		agent:   ag,
		wa:      wa,
		storage: st,
		buffers: make(map[string][]*whatsapp.IncomingMessage),
		timers:  make(map[string]*time.Timer),
		locks:   make(map[string]*sync.Mutex),
	}
}

func (db *DebounceBuffer) getLock(phone string) *sync.Mutex {
	db.mapMutex.Lock()
	defer db.mapMutex.Unlock()
	if _, ok := db.locks[phone]; !ok {
		db.locks[phone] = &sync.Mutex{}
	}
	return db.locks[phone]
}

func (db *DebounceBuffer) Add(msg *whatsapp.IncomingMessage) int {
	lock := db.getLock(msg.Phone)
	lock.Lock()
	defer lock.Unlock()

	db.buffers[msg.Phone] = append(db.buffers[msg.Phone], msg)
	count := len(db.buffers[msg.Phone])

	if t, exists := db.timers[msg.Phone]; exists {
		t.Stop()
	}

	phone := msg.Phone
	db.timers[phone] = time.AfterFunc(time.Duration(db.cfg.BufferSeconds)*time.Second, func() {
		db.processBufferedMessages(phone)
	})

	return count
}

func (db *DebounceBuffer) processBufferedMessages(phone string) {
	lock := db.getLock(phone)
	lock.Lock()
	defer lock.Unlock()

	pending := db.buffers[phone]
	delete(db.buffers, phone)
	delete(db.timers, phone)

	if len(pending) == 0 {
		return
	}

	// Update pushName if present
	for i := len(pending) - 1; i >= 0; i-- {
		if pending[i].Name != "" {
			_ = db.mem.SetName(phone, pending[i].Name)
			break
		}
	}

	var texts []string
	var images []agent.ImageData
	var memoryLines []string

	for _, item := range pending {
		if item.Text != "" {
			texts = append(texts, item.Text)
		}
		if item.MediaType == "image" && item.RawData != nil {
			imgBytes, mime, err := db.wa.FetchMediaBase64(item.RawData)
			if err == nil && len(imgBytes) > 0 {
				path, err := db.storage.SaveMedia(phone, imgBytes, mime)
				if err == nil {
					images = append(images, agent.ImageData{Bytes: imgBytes, MIMEType: mime})
					memoryLines = append(memoryLines, fmt.Sprintf("[image:%s]", path))
				}
			}
		}
	}

	combined := strings.Join(texts, "\n")
	memoryText := strings.TrimSpace(strings.Join(append([]string{combined}, memoryLines...), "\n"))
	if memoryText == "" {
		memoryText = "[customer mengirim gambar]"
	}

	log.Printf("[buffer] %s: %d pesan, %d gambar -> %q", phone, len(pending), len(images), memoryText)

	// Check human takeover switch
	if !db.mem.IsAIEnabled(phone) {
		log.Printf("[takeover] AI nonaktif untuk %s, pesan disimpan saja.", phone)
		_ = db.mem.Add(phone, "user", memoryText)
		return
	}

	history := db.mem.GetHistory(phone)
	ctx := context.Background()
	reply, _, err := db.agent.RunAgent(ctx, history, combined, phone, images)
	if err != nil {
		log.Printf("[error] gagal proses %s: %v", phone, err)
		return
	}

	_ = db.mem.Add(phone, "user", memoryText)
	_ = db.mem.Add(phone, "model", reply)

	if strings.Contains(reply, "[HANDOVER]") {
		_ = db.mem.SetAIEnabled(phone, false)
		log.Printf("[handover] AI dinonaktifkan untuk %s.", phone)
	}

	db.wa.SendReply(phone, reply)
	log.Printf("[balas] %s: %q", phone, reply)
}
```

- [ ] **Step 5: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/whatsapp/...
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/whatsapp internal/buffer
git commit -m "feat: implement whatsapp evolution client and debounce buffer"
```

---

### Task 7: Storage Service (Cloudflare R2 / S3 & Local Media Fallback)

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/storage/storage.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/storage/storage_test.go`

**Interfaces:**
- Consumes: `config.Config`
- Produces: `storage.NewStorageService(cfg *config.Config, mediaDir string) StorageService` with methods:
  - `SaveMedia(phone string, data []byte, mime string) (string, error)`
  - `GetMedia(fname string) ([]byte, string, error)`

- [ ] **Step 1: Write test for local storage fallback**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/storage/storage_test.go`
```go
package storage

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/raygbrn/ai-sales-agent-go/internal/config"
)

func TestLocalStorageSaveAndGet(t *testing.T) {
	tempDir, err := os.MkdirTemp("", "media_test")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	cfg := &config.Config{} // R2 disabled
	svc := NewStorageService(cfg, tempDir)

	data := []byte("test-image-content")
	path, err := svc.SaveMedia("628123", data, "image/png")
	if err != nil {
		t.Fatalf("failed to save media: %v", err)
	}

	if !strings.HasPrefix(path, "media/628123_") || !strings.HasSuffix(path, ".png") {
		t.Errorf("unexpected path format: %s", path)
	}

	fname := filepath.Base(path)
	gotBytes, mime, err := svc.GetMedia(fname)
	if err != nil {
		t.Fatalf("failed to get media: %v", err)
	}
	if string(gotBytes) != string(data) {
		t.Errorf("data mismatch")
	}
	if mime != "image/png" {
		t.Errorf("expected mime image/png, got %s", mime)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/storage/...
```
Expected: FAIL.

- [ ] **Step 3: Implement StorageService**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/storage/storage.go`
```go
package storage

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"

	"github.com/raygbrn/ai-sales-agent-go/internal/config"
)

type StorageService interface {
	SaveMedia(phone string, data []byte, mime string) (string, error)
	GetMedia(fname string) ([]byte, string, error)
}

type storageImpl struct {
	cfg      *config.Config
	mediaDir string
	s3Client *s3.Client
}

var extMap = map[string]string{
	"image/jpeg": "jpg",
	"image/png":  "png",
	"image/webp": "webp",
}

func NewStorageService(cfg *config.Config, mediaDir string) StorageService {
	_ = os.MkdirAll(mediaDir, 0755)

	var client *s3.Client
	if cfg.IsR2Enabled() {
		customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{
				URL: cfg.R2Endpoint,
			}, nil
		})
		awsCfg, err := awsconfig.LoadDefaultConfig(context.TODO(),
			awsconfig.WithEndpointResolverWithOptions(customResolver),
			awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(cfg.R2AccessKeyID, cfg.R2SecretAccessKey, "")),
			awsconfig.WithRegion("auto"),
		)
		if err == nil {
			client = s3.NewFromConfig(awsCfg)
		}
	}

	return &storageImpl{
		cfg:      cfg,
		mediaDir: mediaDir,
		s3Client: client,
	}
}

func (s *storageImpl) randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (s *storageImpl) SaveMedia(phone string, data []byte, mime string) (string, error) {
	ext := extMap[mime]
	if ext == "" {
		ext = "jpg"
	}
	fname := fmt.Sprintf("%s_%s.%s", phone, s.randomHex(4), ext)

	if s.s3Client != nil {
		_, err := s.s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
			Bucket:      aws.String(s.cfg.R2Bucket),
			Key:         aws.String(fname),
			Body:        bytes.NewReader(data),
			ContentType: aws.String(mime),
		})
		if err != nil {
			return "", err
		}
	} else {
		target := filepath.Join(s.mediaDir, fname)
		if err := os.WriteFile(target, data, 0644); err != nil {
			return "", err
		}
	}

	return fmt.Sprintf("media/%s", fname), nil
}

func (s *storageImpl) GetMedia(fname string) ([]byte, string, error) {
	fname = filepath.Base(fname) // prevent directory traversal

	if s.s3Client != nil {
		out, err := s.s3Client.GetObject(context.TODO(), &s3.GetObjectInput{
			Bucket: aws.String(s.cfg.R2Bucket),
			Key:    aws.String(fname),
		})
		if err != nil {
			return nil, "", err
		}
		defer out.Body.Close()
		content, err := io.ReadAll(out.Body)
		if err != nil {
			return nil, "", err
		}
		mime := "image/jpeg"
		if out.ContentType != nil {
			mime = *out.ContentType
		}
		return content, mime, nil
	}

	target := filepath.Join(s.mediaDir, fname)
	data, err := os.ReadFile(target)
	if err != nil {
		return nil, "", err
	}
	mime := http.DetectContentType(data)
	return data, mime, nil
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/storage/...
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/storage
git commit -m "feat: implement storage service with Cloudflare R2 and local filesystem fallback"
```

---

### Task 8: Gin HTTP Handlers (Webhook, Media Proxy, Dashboard HTML & API)

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/handler/handler.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/handler/handler_test.go`

**Interfaces:**
- Consumes: `config.Config`, `gorm.DB`, `buffer.DebounceBuffer`, `storage.StorageService`, `whatsapp.WhatsAppClient`
- Produces: `handler.RegisterRoutes(r *gin.Engine, deps *Dependencies)`

- [ ] **Step 1: Write tests for Health and Dashboard API authentication**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/handler/handler_test.go`
```go
package handler

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/db"
)

func TestHealthEndpoint(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	cfg := &config.Config{BufferSeconds: 8, DashboardAPIKey: "secret123"}
	database, _ := db.InitDB("sqlite://file::memory:?cache=shared")

	RegisterRoutes(r, &Dependencies{
		Config: cfg,
		DB:     database,
	})

	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/health", nil)
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200 OK, got %d", w.Code)
	}
}

func TestDashboardAuthMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	cfg := &config.Config{DashboardAPIKey: "secret123"}
	database, _ := db.InitDB("sqlite://file::memory:?cache=shared")

	RegisterRoutes(r, &Dependencies{
		Config: cfg,
		DB:     database,
	})

	// Without key -> 401
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/dashboard/api/config", nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 Unauthorized, got %d", w.Code)
	}

	// With correct key -> 200
	w2 := httptest.NewRecorder()
	req2, _ := http.NewRequest("GET", "/dashboard/api/config", nil)
	req2.Header.Set("X-API-Key", "secret123")
	r.ServeHTTP(w2, req2)
	if w2.Code != http.StatusOK {
		t.Errorf("expected 200 OK with valid X-API-Key, got %d", w2.Code)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test ./internal/handler/...
```
Expected: FAIL.

- [ ] **Step 3: Implement Gin Handlers and Routes**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/internal/handler/handler.go`
```go
package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"github.com/raygbrn/ai-sales-agent-go/internal/buffer"
	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/memory"
	"github.com/raygbrn/ai-sales-agent-go/internal/model"
	"github.com/raygbrn/ai-sales-agent-go/internal/storage"
	"github.com/raygbrn/ai-sales-agent-go/internal/whatsapp"
)

type Dependencies struct {
	Config   *config.Config
	DB       *gorm.DB
	Buffer   *buffer.DebounceBuffer
	Storage  storage.StorageService
	WhatsApp *whatsapp.WhatsAppClient
	Memory   *memory.Memory
}

func RegisterRoutes(r *gin.Engine, deps *Dependencies) {
	// Root and Health
	r.GET("/", func(c *gin.Context) {
		c.Redirect(http.StatusFound, "/dashboard")
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":         "ok",
			"buffer_seconds": deps.Config.BufferSeconds,
		})
	})

	// Webhook for Evolution API
	r.POST("/webhook", func(c *gin.Context) {
		var payload map[string]any
		if err := c.ShouldBindJSON(&payload); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
			return
		}

		incoming := whatsapp.ExtractIncoming(payload)
		if incoming == nil {
			c.JSON(http.StatusOK, gin.H{"status": "ignored"})
			return
		}

		if deps.Buffer != nil {
			count := deps.Buffer.Add(incoming)
			c.JSON(http.StatusOK, gin.H{"status": "buffered", "pending": count})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "buffered", "pending": 1})
	})

	// Media Proxy
	r.GET("/media/:fname", func(c *gin.Context) {
		fname := filepath.Base(c.Param("fname"))
		if deps.Storage == nil {
			c.Status(http.StatusNotFound)
			return
		}
		data, mime, err := deps.Storage.GetMedia(fname)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Gambar tidak ditemukan."})
			return
		}
		c.Header("Cache-Control", "public, max-age=86400")
		c.Data(http.StatusOK, mime, data)
	})

	// Dashboard HTML
	r.GET("/dashboard", func(c *gin.Context) {
		htmlBytes, err := os.ReadFile("templates/dashboard.html")
		if err != nil {
			c.String(http.StatusInternalServerError, "templates/dashboard.html not found")
			return
		}
		c.Data(http.StatusOK, "text/html; charset=utf-8", htmlBytes)
	})

	// Dashboard Protected API group
	api := r.Group("/dashboard/api", func(c *gin.Context) {
		key := c.GetHeader("X-API-Key")
		if deps.Config.DashboardAPIKey == "" || key != deps.Config.DashboardAPIKey {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "API key dashboard salah."})
			return
		}
		c.Next()
	})

	api.GET("/config", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"company": deps.Config.CompanyName,
			"ai_name": deps.Config.AIName,
		})
	})

	api.GET("/conversations", func(c *gin.Context) {
		var msgs []model.ConversationMessage
		deps.DB.Order("created_at DESC").Find(&msgs)

		var contacts []model.Contact
		deps.DB.Find(&contacts)
		contactMap := make(map[string]model.Contact)
		for _, ct := range contacts {
			contactMap[ct.Phone] = ct
		}

		var bookings []model.Booking
		deps.DB.Where("status != ?", "cancelled").Find(&bookings)
		bookingPhones := make(map[string]bool)
		for _, b := range bookings {
			bookingPhones[b.Phone] = true
		}

		lastMsg := make(map[string]model.ConversationMessage)
		var order []string
		for _, m := range msgs {
			if _, exists := lastMsg[m.Phone]; !exists {
				lastMsg[m.Phone] = m
				order = append(order, m.Phone)
			}
		}

		var result []gin.H
		for _, phone := range order {
			m := lastMsg[phone]
			ct, hasCt := contactMap[phone]
			name := phone
			if hasCt && ct.Name != nil && *ct.Name != "" {
				name = *ct.Name
			}
			aiEnabled := true
			if hasCt {
				aiEnabled = ct.AiEnabled
			}
			result = append(result, gin.H{
				"phone":       phone,
				"name":        name,
				"last_text":   m.Text,
				"last_role":   m.Role,
				"last_time":   m.CreatedAt.Format(time.RFC3339),
				"ai_enabled":  aiEnabled,
				"handover":    !aiEnabled,
				"has_booking": bookingPhones[phone],
			})
		}
		c.JSON(http.StatusOK, result)
	})

	api.GET("/conversations/:phone", func(c *gin.Context) {
		phone := c.Param("phone")
		var msgs []model.ConversationMessage
		deps.DB.Where("phone = ?", phone).Order("created_at ASC").Find(&msgs)

		var contact model.Contact
		deps.DB.Where("phone = ?", phone).First(&contact)

		var bookings []model.Booking
		deps.DB.Preload("Treatment").Where("phone = ?", phone).Order("booking_date DESC").Find(&bookings)

		name := phone
		if contact.Name != nil && *contact.Name != "" {
			name = *contact.Name
		}

		var msgList []gin.H
		for _, m := range msgs {
			msgList = append(msgList, gin.H{
				"role": m.Role,
				"text": m.Text,
				"time": m.CreatedAt.Format(time.RFC3339),
			})
		}

		var bList []gin.H
		for _, b := range bookings {
			bList = append(bList, gin.H{
				"code":      b.Code,
				"treatment": b.Treatment.Name,
				"date":      b.BookingDate,
				"time":      b.BookingTime,
				"status":    b.Status,
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"phone":        phone,
			"name":         name,
			"ai_enabled":   contact.AiEnabled,
			"is_returning": contact.IsReturning,
			"messages":     msgList,
			"bookings":     bList,
		})
	})

	api.POST("/conversations/:phone/ai", func(c *gin.Context) {
		phone := c.Param("phone")
		var req struct {
			Enabled bool `json:"enabled"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
			return
		}

		var contact model.Contact
		if err := deps.DB.Where("phone = ?", phone).First(&contact).Error; err == nil {
			contact.AiEnabled = req.Enabled
			deps.DB.Save(&contact)
		} else {
			deps.DB.Create(&model.Contact{
				Phone:     phone,
				AiEnabled: req.Enabled,
			})
		}
		c.JSON(http.StatusOK, gin.H{"phone": phone, "ai_enabled": req.Enabled})
	})

	api.POST("/conversations/:phone/send", func(c *gin.Context) {
		phone := c.Param("phone")
		var req struct {
			Text string `json:"text"`
		}
		if err := c.ShouldBindJSON(&req); err != nil || strings.TrimSpace(req.Text) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Pesan kosong."})
			return
		}

		if deps.WhatsApp != nil {
			go deps.WhatsApp.SendReply(phone, req.Text)
		}
		if deps.Memory != nil {
			_ = deps.Memory.Add(phone, "model", req.Text)
		}
		c.JSON(http.StatusOK, gin.H{"ok": true})
	})

	api.GET("/bookings", func(c *gin.Context) {
		rangeFilter := c.DefaultQuery("range", "all")
		statusFilter := c.DefaultQuery("status", "all")
		query := c.DefaultQuery("q", "")

		var allBookings []model.Booking
		deps.DB.Preload("Treatment").Order("booking_date DESC, booking_time ASC").Find(&allBookings)

		today := time.Now().Format("2006-01-02")
		stats := gin.H{
			"today":     0,
			"total":     len(allBookings),
			"active":    0,
			"completed": 0,
		}

		for _, b := range allBookings {
			if b.BookingDate == today && b.Status != "cancelled" {
				stats["today"] = stats["today"].(int) + 1
			}
			if b.Status == "pending" || b.Status == "confirmed" {
				stats["active"] = stats["active"].(int) + 1
			}
			if b.Status == "completed" {
				stats["completed"] = stats["completed"].(int) + 1
			}
		}

		var items []gin.H
		for _, b := range allBookings {
			if statusFilter != "all" && b.Status != statusFilter {
				continue
			}
			if rangeFilter == "today" && b.BookingDate != today {
				continue
			}
			if query != "" {
				ql := strings.ToLower(query)
				if !strings.Contains(strings.ToLower(b.CustomerName), ql) && !strings.Contains(strings.ToLower(b.Treatment.Name), ql) {
					continue
				}
			}
			items = append(items, gin.H{
				"code":          b.Code,
				"customer_name": b.CustomerName,
				"phone":         b.Phone,
				"treatment":     b.Treatment.Name,
				"date":          b.BookingDate,
				"time":          b.BookingTime,
				"status":        b.Status,
			})
		}

		c.JSON(http.StatusOK, gin.H{"stats": stats, "bookings": items})
	})

	api.POST("/bookings/:code/status", func(c *gin.Context) {
		code := c.Param("code")
		var req struct {
			Status string `json:"status"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Status tidak valid."})
			return
		}

		validStatus := map[string]bool{"pending": true, "confirmed": true, "completed": true, "cancelled": true}
		if !validStatus[req.Status] {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Status tidak valid."})
			return
		}

		var b model.Booking
		if err := deps.DB.Where("code = ?", code).First(&b).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Booking tidak ditemukan."})
			return
		}
		b.Status = req.Status
		deps.DB.Save(&b)
		c.JSON(http.StatusOK, gin.H{"code": code, "status": req.Status})
	})
}
```

- [ ] **Step 4: Run tests and verify they pass**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./internal/handler/...
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add internal/handler
git commit -m "feat: implement gin http handlers for webhook, media, and dashboard api"
```

---

### Task 9: Server & CLI Entrypoints

**Files:**
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/cmd/server/main.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/cmd/cli/main.go`
- Create: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/README.md`

**Interfaces:**
- Server: wires `config`, `db`, `seed`, `tools`, `memory`, `agent`, `storage`, `whatsapp`, `buffer`, and `handler`. Starts Gin HTTP server on `PORT`.
- CLI: wires `config`, `db`, `seed`, `tools`, `agent`. Runs interactive terminal chat loop using dummy phone `6281234567890`.

- [ ] **Step 1: Write `cmd/server/main.go`**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/cmd/server/main.go`
```go
package main

import (
	"fmt"
	"log"

	"github.com/gin-gonic/gin"

	"github.com/raygbrn/ai-sales-agent-go/internal/agent"
	"github.com/raygbrn/ai-sales-agent-go/internal/buffer"
	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/db"
	"github.com/raygbrn/ai-sales-agent-go/internal/handler"
	"github.com/raygbrn/ai-sales-agent-go/internal/memory"
	"github.com/raygbrn/ai-sales-agent-go/internal/storage"
	"github.com/raygbrn/ai-sales-agent-go/internal/tools"
	"github.com/raygbrn/ai-sales-agent-go/internal/whatsapp"
)

func main() {
	cfg := config.Load()

	database, err := db.InitDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	if err := db.SeedDB(database); err != nil {
		log.Fatalf("Failed to seed database: %v", err)
	}

	toolService := tools.NewToolService(database)
	mem := memory.NewMemory(database, cfg.MemoryWindow, cfg.SessionTTLHours)
	storageService := storage.NewStorageService(cfg, "media")
	waClient := whatsapp.NewWhatsAppClient(cfg)

	var ag *agent.Agent
	if cfg.GeminiAPIKey != "" {
		ag, err = agent.NewAgent(cfg, toolService, "prompts/system.md")
		if err != nil {
			log.Printf("[warning] Failed to init agent: %v. Webhook AI will not respond.", err)
		}
	} else {
		log.Println("[warning] GEMINI_API_KEY is empty. Provide API key in .env to enable AI agent.")
	}

	var debouncer *buffer.DebounceBuffer
	if ag != nil {
		debouncer = buffer.NewDebounceBuffer(cfg, mem, ag, waClient, storageService)
	}

	r := gin.Default()
	handler.RegisterRoutes(r, &handler.Dependencies{
		Config:   cfg,
		DB:       database,
		Buffer:   debouncer,
		Storage:  storageService,
		WhatsApp: waClient,
		Memory:   mem,
	})

	log.Printf("Glowria AI Sales Agent Server listening on port %s (Buffer debounce: %ds)", cfg.Port, cfg.BufferSeconds)
	if err := r.Run(fmt.Sprintf(":%s", cfg.Port)); err != nil {
		log.Fatalf("Server stopped: %v", err)
	}
}
```

- [ ] **Step 2: Write `cmd/cli/main.go`**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/cmd/cli/main.go`
```go
package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"google.golang.org/genai"

	"github.com/raygbrn/ai-sales-agent-go/internal/agent"
	"github.com/raygbrn/ai-sales-agent-go/internal/config"
	"github.com/raygbrn/ai-sales-agent-go/internal/db"
	"github.com/raygbrn/ai-sales-agent-go/internal/tools"
	"github.com/raygbrn/ai-sales-agent-go/internal/whatsapp"
)

const DummyPhone = "6281234567890"

func main() {
	cfg := config.Load()
	if cfg.GeminiAPIKey == "" {
		log.Fatal("GEMINI_API_KEY belum diisi. Salin .env.example ke .env dan isi API key dari https://aistudio.google.com")
	}

	database, err := db.InitDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}

	if err := db.SeedDB(database); err != nil {
		log.Fatalf("Failed to seed database: %v", err)
	}

	toolService := tools.NewToolService(database)
	ag, err := agent.NewAgent(cfg, toolService, "prompts/system.md")
	if err != nil {
		log.Fatalf("Failed to initialize agent: %v", err)
	}

	fmt.Println(strings.Repeat("=", 60))
	fmt.Printf("  Glowria Aesthetic Clinic — AI Sales Agent (model: %s)\n", cfg.GeminiModel)
	fmt.Println("  Ketik pesan seperti customer WhatsApp. 'exit' untuk keluar.")
	fmt.Println(strings.Repeat("=", 60))

	reader := bufio.NewReader(os.Stdin)
	var history []*genai.Content
	ctx := context.Background()

	for {
		fmt.Print("\nCustomer > ")
		input, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		input = strings.TrimSpace(input)
		if input == "" || strings.EqualFold(input, "exit") || strings.EqualFold(input, "quit") {
			break
		}

		reply, newHistory, err := ag.RunAgent(ctx, history, input, DummyPhone, nil)
		if err != nil {
			fmt.Printf("\n[Error]: %v\n", err)
			continue
		}
		history = newHistory

		bubbles := whatsapp.SplitBubbles(reply)
		for _, b := range bubbles {
			if strings.Contains(reply, "[HANDOVER]") {
				fmt.Printf("\nGita    > %s\n  ⚠ [HANDOVER terdeteksi]\n", b)
			} else {
				fmt.Printf("\nGita    > %s\n", b)
			}
		}
	}

	fmt.Println("\nSampai jumpa!")
}
```

- [ ] **Step 3: Write comprehensive `README.md`**

File: `/home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go/README.md`
```markdown
# AI Sales Agent Workshop (Go & Gin Version)

Implementasi ulang AI Sales Agent (Gita - Glowria Aesthetic Clinic) menggunakan bahasa Go dan framework Gin.

## Fitur Utama

- **Otak AI Gemini**: Menggunakan `google.golang.org/genai` dengan Function Calling otomatis (6 tools klinik).
- **Engine Booking Berbasis Kapasitas**: Deteksi tumpang tindih waktu (overlap) booking secara atomik (kapasitas 3 perawat, durasi 90 menit).
- **Integrasi WhatsApp via Evolution API**: Buffer debounce per nomor, simulasi typing indicator proporsional, dan bubble message split (`[NEXT]`).
- **Dashboard Admin**: Monitoring percakapan, saklar takeover AI on/off, kirim pesan manual, dan manajemen status booking.
- **Penyimpanan Media Fleksibel**: Support Cloudflare R2 (S3-compatible) dengan auto fallback ke disk lokal (`media/`).
- **Mode CLI**: Percakapan interaktif langsung di terminal untuk testing instan.

## Menjalankan Aplikasi

### 1. Konfigurasi
Salin `.env.example` ke `.env` dan isi `GEMINI_API_KEY`:
```bash
cp .env.example .env
```

### 2. Jalankan Server Web (Gin)
```bash
go run ./cmd/server
```
Buka browser di `http://localhost:8000/dashboard`.

### 3. Jalankan CLI Interaktif
```bash
go run ./cmd/cli
```

### 4. Menjalankan Unit Tests
```bash
go test -v ./...
```
```

- [ ] **Step 4: Verify build of both binaries**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go build -o /dev/null ./cmd/server
go build -o /dev/null ./cmd/cli
```
Expected: Build succeeds with exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add cmd README.md
git commit -m "feat: implement server and cli entrypoints and documentation"
```

---

### Task 10: Complete Verification Suite

**Files:**
- Test all packages: `go test -v ./...`
- Verify binary builds

- [ ] **Step 1: Run all unit tests across the entire Go codebase**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
go test -v ./...
```
Expected: All tests PASS.

- [ ] **Step 2: Build release binaries**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
mkdir -p bin
go build -o bin/server ./cmd/server
go build -o bin/cli ./cmd/cli
ls -la bin/
```
Expected: Binaries `bin/server` and `bin/cli` generated.

- [ ] **Step 3: Commit final build configuration**

```bash
cd /home/raygbrn/project/ai/AI-Sales-Agent-Workshop-Go
git add .
git commit -m "chore: complete test verification and build release binaries"
```
