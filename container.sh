#!/usr/bin/env bash
# ==============================================================================
# Unified Container Management Helper for AI Sales Agent Workshop
# Automatically detects and uses Docker or Podman
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# 1. Detect Container Engine & Compose Tool
# ------------------------------------------------------------------------------
detect_tools() {
    if command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_CMD="podman-compose"
        ENGINE_CMD="podman"
    elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        COMPOSE_CMD="podman compose"
        ENGINE_CMD="podman"
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        ENGINE_CMD="docker"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        ENGINE_CMD="docker"
    elif command -v podman >/dev/null 2>&1; then
        COMPOSE_CMD="podman"
        ENGINE_CMD="podman"
    elif command -v docker >/dev/null 2>&1; then
        COMPOSE_CMD="docker"
        ENGINE_CMD="docker"
    else
        echo "❌ Error: Tidak ditemukan 'docker' maupun 'podman' di sistem Anda."
        echo "   Silakan instal Docker atau Podman terlebih dahulu."
        exit 1
    fi
}

detect_tools

# ------------------------------------------------------------------------------
# 2. Print Header
# ------------------------------------------------------------------------------
print_banner() {
    echo "=================================================================="
    echo "  Glowria AI Sales Agent — Container Management"
    echo "  Engine  : $ENGINE_CMD"
    echo "  Compose : $COMPOSE_CMD"
    echo "=================================================================="
}

ensure_env_file() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        echo "⚠️  File .env tidak ditemukan. Menyalin dari .env.example..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    fi
}

ensure_data_dirs() {
    mkdir -p "$SCRIPT_DIR/data" "$SCRIPT_DIR/media"
    ensure_env_file
}

# ------------------------------------------------------------------------------
# 3. Command Handlers
# ------------------------------------------------------------------------------
cmd_help() {
    print_banner
    echo "Penggunaan: ./container.sh <perintah>"
    echo ""
    echo "Perintah yang Tersedia:"
    echo "  build        Build container image (ai-sales-agent:latest)"
    echo "  up           Jalankan Sales Agent (FastAPI + SQLite, port 8000)"
    echo "  up:full      Jalankan Full Stack (Sales Agent + Evolution WhatsApp lokal, port 8080)"
    echo "  up:postgres  Jalankan Sales Agent + PostgreSQL DB lokal (port 5432)"
    echo "  down         Hentikan semua container dan jaringan"
    echo "  logs         Pantau log real-time dari container Sales Agent"
    echo "  cli          Buka simulator chat WhatsApp interaktif di dalam container"
    echo "  status       Periksa status dan healthcheck container"
    echo "  help         Tampilkan pesan bantuan ini"
    echo ""
}

cmd_build() {
    print_banner
    echo "🔨 Membangun image ai-sales-agent:latest..."
    $ENGINE_CMD build -t ai-sales-agent:latest -f Dockerfile .
    echo "✅ Build selesai!"
}

cmd_up() {
    print_banner
    ensure_data_dirs
    echo "🚀 Menjalankan Glowria Sales Agent (Default: SQLite)..."
    $COMPOSE_CMD up -d app
    echo ""
    echo "✅ Aplikasi berjalan!"
    echo "   - Dashboard & Webhook : http://localhost:8000/"
    echo "   - Cek log             : ./container.sh logs"
    echo "   - Chat CLI interaktif : ./container.sh cli"
}

cmd_up_full() {
    print_banner
    ensure_data_dirs
    echo "🚀 Menjalankan Full Stack (Sales Agent + Evolution API)..."
    $COMPOSE_CMD --profile full up -d
    echo ""
    echo "✅ Seluruh service berjalan!"
    echo "   - Sales Agent Dashboard : http://localhost:8000/"
    echo "   - Evolution WhatsApp UI : http://localhost:8080/"
}

cmd_up_postgres() {
    print_banner
    ensure_data_dirs
    echo "🚀 Menjalankan Sales Agent + PostgreSQL..."
    $COMPOSE_CMD --profile postgres up -d
    echo ""
    echo "✅ Service PostgreSQL dan Sales Agent berjalan!"
}

cmd_down() {
    print_banner
    echo "🛑 Menghentikan seluruh container..."
    $COMPOSE_CMD down
    echo "✅ Seluruh container telah dihentikan."
}

cmd_logs() {
    $COMPOSE_CMD logs -f app
}

cmd_cli() {
    print_banner
    echo "💬 Menghubungkan ke simulator WhatsApp di dalam container..."
    # Pastikan container app sedang menyala
    if ! $ENGINE_CMD ps --format '{{.Names}}' | grep -q "glowria-sales-agent"; then
        echo "⚠️ Container belum berjalan. Menyalakan container terlebih dahulu..."
        cmd_up
    fi
    $ENGINE_CMD exec -it glowria-sales-agent python cli.py
}

cmd_status() {
    print_banner
    $COMPOSE_CMD ps
}

# ------------------------------------------------------------------------------
# 4. Entrypoint Router
# ------------------------------------------------------------------------------
ACTION="${1:-help}"

case "$ACTION" in
    build)
        cmd_build
        ;;
    up)
        cmd_up
        ;;
    up:full)
        cmd_up_full
        ;;
    up:postgres)
        cmd_up_postgres
        ;;
    down)
        cmd_down
        ;;
    logs)
        cmd_logs
        ;;
    cli)
        cmd_cli
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo "❌ Perintah tidak dikenal: $ACTION"
        echo ""
        cmd_help
        exit 1
        ;;
esac
