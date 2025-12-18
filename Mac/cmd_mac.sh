#!/usr/bin/env bash
# ============================================================
# shellgen — macOS-native Natural Language → Shell Command Tool
# ============================================================
# Requirements:
#   - macOS
#   - Ollama (https://ollama.ai)
#   - Homebrew packages: coreutils, flock (optional)
#
# This script is defensive, safe, and production-ready.
# ============================================================

set -o pipefail
set -u

########################
# Configuration
########################

MODEL="${MODEL:-shellcmd}"                    # Ollama model name
HISTORY_FILE="$HOME/.shellgen_history"        # Command history file
LOCK_FILE="$HISTORY_FILE.lock"                # Lock file
MAX_HISTORY=50                                # Max history entries
MAX_CMD_LENGTH=500                            # Max stored command length
OLLAMA_TIMEOUT=10                             # Seconds
EXPLAIN_TIMEOUT=5                             # Seconds

########################
# macOS tool detection
########################

# timeout → gtimeout fallback
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_CMD="gtimeout"
else
    echo "❌ timeout not found. Install coreutils:"
    echo "   brew install coreutils"
    exit 1
fi

# flock is optional now, we have a fallback
FLOCK_AVAILABLE=0
command -v flock >/dev/null 2>&1 && FLOCK_AVAILABLE=1

########################
# Colors
########################

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

########################
# Ollama Verification
########################

check_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        echo -e "${R}❌ Ollama not found. Install from https://ollama.ai${N}"
        exit 1
    fi
    
    # Check if model exists
    if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
        echo -e "${Y}⚠ Model '$MODEL' not found. Pulling...${N}"
        if ! ollama pull "$MODEL"; then
            echo -e "${R}❌ Failed to pull model '$MODEL'${N}"
            echo -e "${Y}Try: ollama pull codellama${N}"
            exit 1
        fi
    fi
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo -e "${Y}⚠ Ollama service not running. Starting...${N}"
        ollama serve >/dev/null 2>&1 &
        local wait_time=0
        while ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && [ $wait_time -lt 10 ]; do
            sleep 1
            ((wait_time++))
        done
        [ $wait_time -ge 10 ] && echo -e "${Y}⚠ Ollama slow to start, continuing anyway...${N}"
    fi
}

check_ollama

########################
# Init
########################

touch "$HISTORY_FILE" 2>/dev/null || {
    echo "❌ Cannot write history file"
    exit 1
}

########################
# History Logger (macOS-compatible)
########################

log_history() {
    local status="$1"
    local safe_query="${QUERY//|/\\|}"
    local safe_cmd="${CMD:0:$MAX_CMD_LENGTH}"
    local entry
    entry="$(date '+%F %T')|$status|$safe_query|$safe_cmd"
    
    if [[ $FLOCK_AVAILABLE -eq 1 ]]; then
        # Use flock if available
        exec 9>"$LOCK_FILE"
        flock -x 9
        echo "$entry" >> "$HISTORY_FILE"
        
        if [[ $(wc -l < "$HISTORY_FILE") -gt $MAX_HISTORY ]]; then
            tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" &&
            mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null
        fi
        
        flock -u 9
        exec 9>&-
    else
        # Directory-based locking (macOS fallback)
        local lock_dir="$LOCK_FILE.dir"
        local max_attempts=30
        local attempt=0
        
        while (( attempt++ < max_attempts )); do
            if mkdir "$lock_dir" 2>/dev/null; then
                echo "$entry" >> "$HISTORY_FILE"
                
                if [[ $(wc -l < "$HISTORY_FILE") -gt $MAX_HISTORY ]]; then
                    tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" &&
                    mv "$HISTORY_FILE.tmp" "$HISTORY_FILE" 2>/dev/null
                fi
                
                rmdir "$lock_dir" 2>/dev/null
                return 0
            fi
            sleep 0.1
        done
        
        # Fallback: write without lock
        echo "$entry" >> "$HISTORY_FILE"
    fi
}

########################
# Spinner
########################

spinner() {
    local pid=$1
    local spin='-\|/'
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${Y}[%c]${N}" "${spin:0:1}"
        spin="${spin:1}${spin:0:1}"
        sleep 0.05
    done
    printf "\r\033[K"
}

########################
# Input
########################

if [[ $# -eq 0 ]]; then
    echo -ne "${G}🤖 Describe command: ${N}"
    read -r QUERY
else
    QUERY="$*"
fi

[[ -z "${QUERY:-}" ]] && {
    echo -e "${R}Empty query${N}"
    exit 1
}

########################
# Run Ollama
########################

TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)
trap 'rm -f "$TMP_OUT" "$TMP_ERR"' EXIT

$TIMEOUT_CMD "${OLLAMA_TIMEOUT}s" \
    ollama run "$MODEL" "$QUERY" \
    >"$TMP_OUT" 2>"$TMP_ERR" &

OLLAMA_PID=$!
spinner "$OLLAMA_PID" &
SPINNER_PID=$!

wait "$OLLAMA_PID" 2>/dev/null
EXIT_CODE=$?

kill "$SPINNER_PID" 2>/dev/null
wait "$SPINNER_PID" 2>/dev/null

if [[ $EXIT_CODE -eq 124 ]] || [[ ! -s "$TMP_OUT" ]]; then
    echo -e "${R}✗ Model timeout or error${N}"
    [[ -s "$TMP_ERR" ]] && echo "Error: $(head -1 "$TMP_ERR")"
    exit 1
fi

########################
# Extract Command
########################

CMD=$(grep -v '^```' "$TMP_OUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | head -1)

# Alternative extraction if first method failed
[[ -z "$CMD" ]] && CMD=$(sed -n '/^[[:space:]]*[^[:space:]]/p' "$TMP_OUT" | head -1 | sed 's/^```[a-z]*//;s/```$//')

CMD="${CMD#"${CMD%%[![:space:]]*}"}"
CMD="${CMD%"${CMD##*[![:space:]]}"}"

[[ -z "$CMD" ]] && {
    echo -e "${R}✗ Empty output${N}"
    exit 1
}

########################
# Danger Detection
########################

check_danger() {
    local patterns=(
        'rm[[:space:]]+.*-[rf]'
        'dd[[:space:]]+.*of='
        'mkfs\.?'
        'fdisk[[:space:]]+/dev'
        'sudo[[:space:]]+rm'
        'sudo[[:space:]]+dd'
        ':\(\)\{ *:|:* & *\};:'  # Fork bomb
        'chmod.*777.*/'
        '>.*/dev/sd[a-z]'
    )
    
    for p in "${patterns[@]}"; do
        if [[ "$CMD" =~ $p ]]; then
            echo -e "${R}⚠ DANGEROUS COMMAND DETECTED${N}"
            echo -e "${Y}Pattern: $p${N}"
            echo -e "${G}Command: $CMD${N}"
            echo
            read -rp "Run anyway? [y/N]: " -n 1 ans
            echo
            [[ "$ans" != "y" && "$ans" != "Y" ]] && return 1
            break
        fi
    done
    return 0
}

check_danger || {
    log_history "BLOCKED"
    exit 1
}

########################
# Action Menu
########################

echo -e "${G}✅ Generated command:${N}"
echo -e "   ${Y}└──${N} $CMD"
echo
printf "  ${G}[y]${N} Run   ${G}[e]${N}xplain   ${G}[c]${N}opy   ${G}[h]${N}istory   ${G}[n]${N} Cancel\n"
echo

read -rp "Choice: " -n 1 CHOICE
echo

case "$CHOICE" in
    y|Y)
        echo -e "${G}🚀 Executing...${N}"
        bash -c -- "$CMD"
        log_history "EXECUTED"
        ;;
    e|E)
        echo -e "${Y}📚 Explaining...${N}"
        EXP_TMP=$(mktemp)
        trap 'rm -f "$EXP_TMP"' EXIT
        if $TIMEOUT_CMD "${EXPLAIN_TIMEOUT}s" \
            ollama run "$MODEL" "Explain in one line: $CMD" > "$EXP_TMP" 2>/dev/null; then
            sed -e 's/^```//' -e 's/```$//' "$EXP_TMP" | head -3
        else
            echo "Explanation failed or timed out"
        fi
        log_history "EXPLAINED"
        ;;
    c|C)
        if command -v pbcopy >/dev/null; then
            echo -n "$CMD" | pbcopy
            echo -e "${G}📋 Copied to clipboard${N}"
        else
            echo -e "${Y}Command:${N} $CMD"
        fi
        log_history "COPIED"
        ;;
    h|H)
        echo -e "${Y}📜 Last 10 commands:${N}"
        if [[ -s "$HISTORY_FILE" ]]; then
            tail -10 "$HISTORY_FILE" 2>/dev/null | while IFS='|' read -r d t s q _; do
                printf "  %s %s [%s] %s\n" "$d" "$t" "$s" "${q:0:40}"
            done
        else
            echo "  No history yet"
        fi
        ;;
    *)
        echo -e "${R}❌ Cancelled${N}"
        log_history "CANCELLED"
        ;;
esac

########################
# Shell Integration Tip
########################

if [[ -z "${SHELLGEN_NO_TIP:-}" ]]; then
    current_shell="${SHELL##*/}"
    case "$current_shell" in
        bash|zsh)
            if ! grep -q "alias shellgen=" ~/."${current_shell}rc" 2>/dev/null; then
                echo -e "\n${Y}💡 Tip: Add alias for quick access:${N}"
                echo "  echo \"alias shellgen='$(realpath "$0")'\" >> ~/.${current_shell}rc"
            fi
            ;;
    esac
fi