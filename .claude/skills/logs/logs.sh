#!/bin/bash
# Cloom log streaming helper
# Usage: logs.sh <on|off|read|clear>

LOG_DIR="/tmp/cloom-logs"
LOG_FILE="$LOG_DIR/cloom.log"
PID_FILE="$LOG_DIR/stream.pid"

case "${1:-on}" in
    on|start)
        mkdir -p "$LOG_DIR"

        # Kill existing stream if any
        if [ -f "$PID_FILE" ]; then
            old_pid=$(cat "$PID_FILE")
            kill "$old_pid" 2>/dev/null
            rm -f "$PID_FILE"
        fi

        # Clear previous log
        > "$LOG_FILE"

        # Start streaming in background
        /usr/bin/log stream \
            --predicate 'subsystem == "com.cloom.app"' \
            --level debug \
            --style compact \
            > "$LOG_FILE" 2>&1 &

        echo "$!" > "$PID_FILE"
        echo "==> Log streaming started (PID: $(cat "$PID_FILE"))"
        echo "    Log file: $LOG_FILE"
        ;;

    off|stop)
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
            kill "$pid" 2>/dev/null
            rm -f "$PID_FILE"
            echo "==> Log streaming stopped (was PID: $pid)"
        else
            # Try to find and kill any lingering stream
            pkill -f 'log stream.*com.cloom.app' 2>/dev/null
            echo "==> Log streaming stopped"
        fi

        if [ -f "$LOG_FILE" ]; then
            lines=$(wc -l < "$LOG_FILE" | tr -d ' ')
            echo "    Total lines captured: $lines"
            echo ""
            echo "==> Last 20 lines:"
            tail -20 "$LOG_FILE"
        fi
        ;;

    read|tail)
        if [ -f "$LOG_FILE" ]; then
            lines=$(wc -l < "$LOG_FILE" | tr -d ' ')
            echo "==> Log file: $LOG_FILE ($lines lines)"
            echo ""
            tail -50 "$LOG_FILE"
        else
            echo "==> No log file found. Run 'logs.sh on' first."
        fi
        ;;

    clear)
        > "$LOG_FILE" 2>/dev/null
        echo "==> Log file cleared: $LOG_FILE"
        ;;

    *)
        echo "Usage: logs.sh <on|off|read|clear>"
        exit 1
        ;;
esac
