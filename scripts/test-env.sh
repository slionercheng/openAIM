#!/bin/bash

# OpenAIM Test Environment Script
# Usage: ./test-env.sh <command> [args]

PROJECT_ROOT="/Users/slioner/Desktop/Project/openAIM"
LOG_DIR="$PROJECT_ROOT/logs"
SERVER_LOG="$LOG_DIR/server.log"
CLIENT_LOG="$LOG_DIR/client.log"
CRASH_DIR="$LOG_DIR/crash"
PID_FILE="$LOG_DIR/server.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if server is running
server_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Start server
start_server() {
    if server_running; then
        log_warn "Server already running (PID: $(cat $PID_FILE))"
        return 0
    fi

    log_info "Starting server..."
    cd "$PROJECT_ROOT"

    # Clear old log
    > "$SERVER_LOG"

    # Start server in background
    nohup go run cmd/server/main.go >> "$SERVER_LOG" 2>&1 &
    echo $! > "$PID_FILE"

    # Wait for server to start
    sleep 2

    if server_running; then
        log_info "Server started (PID: $(cat $PID_FILE))"

        # Check health
        if curl -s http://localhost:8080/health > /dev/null; then
            log_info "Server health check passed"
            return 0
        else
            log_error "Server health check failed"
            return 1
        fi
    else
        log_error "Failed to start server"
        cat "$SERVER_LOG"
        return 1
    fi
}

# Stop server
stop_server() {
    if server_running; then
        PID=$(cat "$PID_FILE")
        log_info "Stopping server (PID: $PID)..."
        kill $PID 2>/dev/null

        # Wait for process to terminate
        for i in {1..10}; do
            if ! ps -p $PID > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        # Force kill if still running
        if ps -p $PID > /dev/null 2>&1; then
            log_warn "Force killing server..."
            kill -9 $PID 2>/dev/null
        fi

        rm -f "$PID_FILE"
        log_info "Server stopped"
    else
        log_info "Server not running"
    fi
}

# Restart server
restart_server() {
    log_info "Restarting server..."
    stop_server
    sleep 1
    start_server
}

# Server status
server_status() {
    if server_running; then
        PID=$(cat "$PID_FILE")
        log_info "Server running (PID: $PID)"

        # Show recent logs
        echo ""
        echo "=== Recent server logs ==="
        tail -20 "$SERVER_LOG"

        # Check health
        echo ""
        echo "=== Health check ==="
        curl -s http://localhost:8080/health | jq . 2>/dev/null || curl -s http://localhost:8080/health
        echo ""
    else
        log_info "Server not running"
    fi
}

# View server logs
server_logs() {
    local lines=${1:-100}
    echo "=== Last $lines lines of server log ==="
    tail -n $lines "$SERVER_LOG"
}

# View client logs from Xcode
client_logs() {
    local lines=${1:-100}
    local client_filter=${2:-}  # Optional client ID filter
    local user_filter=${3:-}    # Optional user filter

    echo "=== Client Logs ==="

    # Find client log files in the app's caches directory
    CLIENT_LOG_DIR=~/Library/Caches/OpenAIM/Logs

    if [ ! -d "$CLIENT_LOG_DIR" ] || [ -z "$(ls -A $CLIENT_LOG_DIR 2>/dev/null)" ]; then
        echo "No client log files found in $CLIENT_LOG_DIR"
        echo ""
        echo "Note: Client logs are created when the app runs and Logger is used."
        return
    fi

    echo "Log files in $CLIENT_LOG_DIR:"
    echo ""
    ls -la "$CLIENT_LOG_DIR"
    echo ""

    # Extract unique client IDs from logs
    echo "=== Active Clients in Logs ==="
    grep -h "\[client_" "$CLIENT_LOG_DIR"/*.log 2>/dev/null | \
        sed 's/.*\[\(client_[A-F0-9]*\)\].*/\1/' | sort -u
    echo ""

    # Extract unique users from logs
    echo "=== Users in Logs ==="
    grep -h "\[usr_" "$CLIENT_LOG_DIR"/*.log 2>/dev/null | \
        sed 's/.*\[\(usr_[a-f0-9]*\)|[^]]*\].*/\1/' | sort -u
    echo ""

    # Build filter command
    local filter_cmd="cat"
    if [ -n "$client_filter" ]; then
        filter_cmd="grep '\[$client_filter\]'"
        echo "Filtering by client: $client_filter"
    fi
    if [ -n "$user_filter" ]; then
        filter_cmd="$filter_cmd | grep '\[$user_filter|'"
        echo "Filtering by user: $user_filter"
    fi

    echo ""
    echo "=== Combined Logs (last $lines lines, sorted by time) ==="
    echo "Usage: client-logs [lines] [client_id] [user_id]"
    echo "Example: client-logs 100 client_ABC123 usr_123456"
    echo ""

    # Merge all logs, sort by timestamp, and show last N lines
    if [ -n "$client_filter" ] || [ -n "$user_filter" ]; then
        eval "cat $CLIENT_LOG_DIR/*.log 2>/dev/null | $filter_cmd | sort | tail -n $lines"
    else
        # Show all logs merged and sorted
        cat "$CLIENT_LOG_DIR"/*.log 2>/dev/null | sort | tail -n $lines
    fi

    echo ""
    echo "=== Crash Logs ==="
    echo "Crash logs location: ~/Library/Logs/DiagnosticReports/"
    echo ""
    echo "Recent openAIM crashes:"
    ls -lt ~/Library/Logs/DiagnosticReports/openAIM* 2>/dev/null | head -5 || echo "None found"

    echo ""
    echo "=== Xcode Console Logs ==="
    echo "To collect Xcode console logs:"
    echo "1. Open Xcode"
    echo "2. Run the app"
    echo "3. View console output in Xcode"
}

# View crash logs
crash_logs() {
    echo "=== Recent Crash Logs ==="
    if [ -d "$CRASH_DIR" ] && [ "$(ls -A $CRASH_DIR 2>/dev/null)" ]; then
        for f in $(ls -t "$CRASH_DIR" | head -5); do
            echo "--- $f ---"
            head -100 "$CRASH_DIR/$f"
            echo ""
        done
    else
        echo "No crash logs found in $CRASH_DIR"
    fi

    echo ""
    echo "=== System Crash Logs ==="
    # macOS crash logs location
    if [ -d ~/Library/Logs/DiagnosticReports ]; then
        echo "Recent openAIM crashes:"
        ls -lt ~/Library/Logs/DiagnosticReports/openAIM* 2>/dev/null | head -5 || echo "None found"
    fi
}

# Clear logs
clear_logs() {
    log_info "Clearing logs..."
    > "$SERVER_LOG"
    > "$CLIENT_LOG"
    rm -rf "$CRASH_DIR"/*
    log_info "Logs cleared"
}

# Export logs
export_logs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_dir="$LOG_DIR/export_$timestamp"

    mkdir -p "$export_dir"

    # Server logs
    cp "$SERVER_LOG" "$export_dir/" 2>/dev/null

    # Client logs from app caches
    CLIENT_LOG_DIR=~/Library/Caches/OpenAIM/Logs
    if [ -d "$CLIENT_LOG_DIR" ]; then
        mkdir -p "$export_dir/client_logs"
        cp -r "$CLIENT_LOG_DIR"/* "$export_dir/client_logs/" 2>/dev/null
    fi

    # Crash logs
    cp -r "$CRASH_DIR" "$export_dir/" 2>/dev/null

    # System crash reports
    if [ -d ~/Library/Logs/DiagnosticReports ]; then
        mkdir -p "$export_dir/system_crashes"
        cp ~/Library/Logs/DiagnosticReports/openAIM* "$export_dir/system_crashes/" 2>/dev/null
    fi

    # Create info file
    echo "=== Export Info ===" > "$export_dir/info.txt"
    echo "Export Time: $(date)" >> "$export_dir/info.txt"
    echo "Client ID: $(defaults read com.openaim.mac clientId 2>/dev/null || echo 'Not found')" >> "$export_dir/info.txt"
    echo "" >> "$export_dir/info.txt"
    echo "=== Contents ===" >> "$export_dir/info.txt"
    ls -la "$export_dir" >> "$export_dir/info.txt"

    # Compress
    cd "$LOG_DIR"
    tar -czf "export_$timestamp.tar.gz" "export_$timestamp"
    rm -rf "export_$timestamp"

    log_info "Logs exported to: $LOG_DIR/export_$timestamp.tar.gz"
}

# Test API health
test_api() {
    log_info "Testing API..."

    echo "=== Health Check ==="
    curl -s http://localhost:8080/health | jq . 2>/dev/null || curl -s http://localhost:8080/health
    echo ""

    echo "=== API Endpoints ==="
    curl -s http://localhost:8080/api/v1/conversations -H "Authorization: Bearer test" 2>/dev/null | head -c 200
    echo ""
}

# Test WebSocket
test_ws() {
    log_info "Testing WebSocket..."

    # Use websocat if available, otherwise use curl
    if command -v websocat &> /dev/null; then
        echo "Testing WebSocket connection..."
        echo '{"type":"heartbeat"}' | timeout 5 websocat "ws://localhost:8080/ws?token=test" 2>&1 || echo "WebSocket test completed"
    else
        log_warn "websocat not installed. Install with: brew install websocat"
        echo "Manual test: Open the client app and check server logs"
    fi
}

# Check environment
check_env() {
    echo "=== Environment Check ==="

    echo ""
    echo "1. Go version:"
    go version 2>/dev/null || echo "Go not installed"

    echo ""
    echo "2. PostgreSQL:"
    pg_isready -h localhost -p 5432 2>/dev/null || echo "PostgreSQL not running or not accessible"

    echo ""
    echo "3. Redis:"
    redis-cli ping 2>/dev/null || echo "Redis not running or not accessible"

    echo ""
    echo "4. Server status:"
    server_running && echo "Running (PID: $(cat $PID_FILE))" || echo "Not running"

    echo ""
    echo "5. Port 8080:"
    lsof -i :8080 2>/dev/null || echo "Port 8080 is free"

    echo ""
    echo "6. Disk space:"
    df -h "$PROJECT_ROOT" | tail -1
}

# Diagnose issues
diagnose() {
    echo "=== Diagnosing Issues ==="

    echo ""
    echo "1. Checking server logs for errors..."
    grep -i "error\|fatal\|panic" "$SERVER_LOG" 2>/dev/null | tail -20 || echo "No errors found"

    echo ""
    echo "2. Checking for common issues..."

    # Check if port is in use by another process
    if lsof -i :8080 2>/dev/null | grep -v LISTEN > /dev/null; then
        log_warn "Port 8080 is in use by another process"
        lsof -i :8080
    fi

    # Check database connection
    if ! pg_isready -h localhost -p 5432 2>/dev/null; then
        log_error "PostgreSQL not accessible"
    fi

    # Check Redis
    if ! redis-cli ping 2>/dev/null | grep -q PONG; then
        log_error "Redis not accessible"
    fi
}

# Show active connections
show_connections() {
    echo "=== Active Connections ==="

    echo ""
    echo "WebSocket connections to port 8080:"
    lsof -i :8080 2>/dev/null | grep ESTABLISHED || echo "No active connections"

    echo ""
    echo "PostgreSQL connections:"
    psql -h localhost -U postgres -d openim -c "SELECT pid, usename, client_addr, state FROM pg_stat_activity WHERE datname='openim';" 2>/dev/null || echo "Cannot query PostgreSQL"
}

# Run all tests
run_all_tests() {
    log_info "Running all tests..."

    echo ""
    echo "=== 1. Environment Check ==="
    check_env

    echo ""
    echo "=== 2. Starting Server ==="
    restart_server

    echo ""
    echo "=== 3. API Test ==="
    test_api

    echo ""
    echo "=== 4. WebSocket Test ==="
    test_ws

    echo ""
    log_info "All tests completed"
}

# Setup environment
setup() {
    log_info "Setting up test environment..."

    mkdir -p "$LOG_DIR"
    mkdir -p "$CRASH_DIR"

    # Create empty log files
    touch "$SERVER_LOG"
    touch "$CLIENT_LOG"

    log_info "Test environment ready"
    log_info "Log directory: $LOG_DIR"
}

# Show client ID
show_client_id() {
    echo "=== Client Information ==="

    # Get client ID from UserDefaults (Swift)
    CLIENT_ID=$(defaults read com.openaim.mac clientId 2>/dev/null || echo "Not set")

    echo "Client ID: $CLIENT_ID"
    echo ""
    echo "Note: Client ID is generated on first app launch and stored in UserDefaults."
    echo "This ID is included in all log entries to distinguish different clients."
}

# Main command handler
case "$1" in
    start-server)
        start_server
        ;;
    stop-server)
        stop_server
        ;;
    restart-server)
        restart_server
        ;;
    server-status)
        server_status
        ;;
    server-logs)
        server_logs $2
        ;;
    client-logs)
        client_logs $2 $3 $4
        ;;
    client-id)
        show_client_id
        ;;
    crash-logs)
        crash_logs
        ;;
    clear-logs)
        clear_logs
        ;;
    export-logs)
        export_logs
        ;;
    test-api)
        test_api
        ;;
    test-ws)
        test_ws
        ;;
    check-env)
        check_env
        ;;
    diagnose)
        diagnose
        ;;
    connections)
        show_connections
        ;;
    run-all)
        run_all_tests
        ;;
    setup)
        setup
        ;;
    *)
        echo "OpenAIM Test Environment"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Server Management:"
        echo "  start-server    Start the backend server"
        echo "  stop-server     Stop the backend server"
        echo "  restart-server  Restart the backend server"
        echo "  server-status   Show server status and recent logs"
        echo ""
        echo "Log Management:"
        echo "  server-logs [n]           Show last n lines of server logs (default: 100)"
        echo "  client-logs [n] [client] [user]  Show client logs with optional filters"
        echo "                            - n: number of lines (default: 100)"
        echo "                            - client: filter by client ID (e.g. client_ABC123)"
        echo "                            - user: filter by user ID (e.g. usr_123456)"
        echo "  client-id                 Show client identifier"
        echo "  crash-logs                Show recent crash logs"
        echo "  clear-logs                Clear all log files"
        echo "  export-logs               Export all logs to a compressed archive"
        echo ""
        echo "Testing:"
        echo "  test-api        Test API endpoints"
        echo "  test-ws         Test WebSocket connection"
        echo "  run-all         Run all tests"
        echo ""
        echo "Debugging:"
        echo "  check-env       Check environment status"
        echo "  diagnose        Diagnose common issues"
        echo "  connections     Show active connections"
        echo ""
        echo "Setup:"
        echo "  setup           Initialize the test environment"
        ;;
esac