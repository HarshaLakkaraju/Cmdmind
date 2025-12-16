#!/bin/bash
# Use Bash shell to run this script
# Build the custom model

# ollama create model shellcmd \: file with  Modelfile-shell
# shellcmd -f ~/Modelfile-shell

# Check model exists
# ollama list

set -o pipefail
# If any command in a pipeline fails, the whole pipeline fails

########################
# Ultra-light defaults
########################

MODEL="shellcmd"
# Ollama model name used for generating shell commands

HISTORY_FILE="$HOME/.shellgen_history"
# File to store command generation history

LOCK_FILE="$HISTORY_FILE.lock"
# Lock file to prevent concurrent history writes

MAX_HISTORY=50
# Maximum number of history entries to keep

MAX_CMD_LENGTH=500
# Maximum length of stored command (safety limit)

# ANSI color codes for terminal output
G='\033[0;32m'   # Green
Y='\033[1;33m'   # Yellow
R='\033[0;31m'   # Red
N='\033[0m'      # Reset / Normal

########################
# Minimal config loading
########################

[[ -f ~/.config/shellgen.conf ]] && . ~/.config/shellgen.conf 2>/dev/null
# Load optional user config file if it exists (silently)

touch "$HISTORY_FILE" 2>/dev/null
# Ensure history file exists (ignore permission errors)

########################
# Robust helpers
########################

log_history() {
    # Function to log command activity safely

    local status=$1
    # Status symbol (✓, ✗, etc.)

    local safe_query="${QUERY//|/\\|}"
    # Escape pipe characters to protect history format

    local safe_cmd="${CMD:0:$MAX_CMD_LENGTH}"
    # Truncate command to max allowed length

    local entry="$(date '+%F %T')|$status|$safe_query|$safe_cmd"
    # Build history entry: timestamp | status | query | command

    exec 9>"$LOCK_FILE"
    # Open lock file on file descriptor 9

    flock -x 9
    # Acquire exclusive lock (prevents race conditions)

    echo "$entry" >> "$HISTORY_FILE"
    # Append entry to history file

    local line_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
    # Count number of history lines safely

    if [[ $line_count -gt $MAX_HISTORY ]]; then
        # If history exceeds limit

        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" &&
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
        # Keep only the most recent entries
    fi

    flock -u 9
    # Release file lock

    exec 9>&-
    # Close file descriptor
}

spinner() {
    # Simple spinner animation while background process runs

    local pid=$1
    # Process ID to monitor

    local spinstr='-\|/'
    # Spinner characters

    while kill -0 "$pid" 2>/dev/null 2>&1; do
        # While process is still running

        printf "\r${Y}[%c]${N}" "${spinstr:0:1}"
        # Print spinner frame

        spinstr="${spinstr:1}${spinstr:0:1}"
        # Rotate spinner characters

        sleep 0.05
        # Control animation speed
    done

    printf "\r\033[K"
    # Clear spinner line after completion
}

########################
# Fast input parsing
########################

if [[ $# -eq 0 ]]; then
    # If no CLI arguments were provided

    read -rp "Describe command: " QUERY
    # Prompt user for natural language input
else
    QUERY="$*"
    # Combine all CLI arguments into one query
fi

[[ -z "$QUERY" ]] && echo -e "${R}Empty query${N}" && exit 1
# Exit if query is empty

########################
# Parallel generation with timeout
########################

TMP_OUT=$(mktemp)
# Temporary file for model output

TMP_ERR=$(mktemp)
# Temporary file for model errors

timeout 10s ollama run "$MODEL" "$QUERY" >"$TMP_OUT" 2>"$TMP_ERR" &
# Run Ollama in background with 10s timeout

OLLAMA_PID=$!
# Capture background process ID

spinner $OLLAMA_PID &
# Start spinner in background

SPINNER_PID=$!
# Capture spinner PID

wait $OLLAMA_PID 2>/dev/null
# Wait for Ollama process to finish

OLLAMA_EXIT=$?
# Capture exit code

kill $SPINNER_PID 2>/dev/null
# Stop spinner

if [[ $OLLAMA_EXIT -eq 124 ]] || [[ ! -s "$TMP_OUT" ]]; then
    # Handle timeout or empty output

    echo -e "${R}✗ Model timeout/error${N}"
    # Show error message

    [[ -s "$TMP_ERR" ]] && echo "Error: $(head -1 "$TMP_ERR")"
    # Print first error line if available

    rm -f "$TMP_OUT" "$TMP_ERR"
    # Clean temp files

    exit 1
fi

########################
# Robust command extraction
########################

CMD=$(sed -e 's/^```[a-z]*//' -e 's/```$//' "$TMP_OUT")
# Remove Markdown code fences from model output

CMD=$(echo "$CMD" | awk '
    BEGIN{block=""; in_block=0}
    /^[[:space:]]*[^[:space:]]/ {
        if(!in_block) in_block=1
        if(block=="") block=$0
        else if(NR<=5) block=block "\n" $0
    }
    /^[[:space:]]*$/ && in_block {exit}
    END{print block}
')
# Extract first non-empty command block (max 5 lines)

CMD="${CMD#"${CMD%%[![:space:]]*}"}"
# Trim leading whitespace

CMD="${CMD%"${CMD##*[![:space:]]}"}"
# Trim trailing whitespace

rm -f "$TMP_OUT" "$TMP_ERR"
# Remove temporary files

[[ -z "$CMD" ]] && echo -e "${R}✗ Empty output${N}" && exit 1
# Abort if no command was extracted

########################
# Comprehensive danger detection
########################

check_danger() {
    # Detect potentially destructive commands

    local patterns=(
        'rm[[:space:]]+.*-[rf]'
        'dd[[:space:]]+.*of='
        'mkfs\.?'
        'fdisk[[:space:]]+/dev'
        'sudo[[:space:]]+rm'
        'sudo[[:space:]]+dd'
    )
    # Regex patterns representing dangerous operations

    local danger_list=""
    # Accumulates matched danger patterns

    for pattern in "${patterns[@]}"; do
        if [[ "$CMD" =~ $pattern ]]; then
            danger_list+="  • $pattern\n"
        fi
    done

    if [[ -n "$danger_list" ]]; then
        # If any dangerous pattern matched

        echo -e "${R}⚠️  Danger detected${N}"
        echo -e "${Y}Command:${N} $CMD"
        echo -e "${R}Matches:${N}"
        echo -e "$danger_list"

        read -rp "Continue? [y/N]: " -n 1 confirm
        # Ask user confirmation

        echo ""
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
        # Abort if not confirmed
    fi
    return 0
}

check_danger || { log_history "✗" && exit 1; }
# Stop execution if danger not confirmed

########################
# Formatted single-key action menu
########################

echo -e "${G}Command:${N} $CMD"
# Display generated command

echo ""

printf "  ${G}[y]${N}es, ${G}[e]${N}xplain, ${G}[c]${N}opy, ${G}[h]${N}istory, ${G}[n]${N}o\n"
# Show menu options

echo ""

read -rp "Choice: " -n 1 REPLY
# Read single key choice

echo ""

case "$REPLY" in
    y|Y)
        echo -e "${G}Running...${N}"
        bash -c -- "$CMD"
        # Execute command safely

        log_history "✓"
        ;;
    e|E)
        echo -e "${Y}Explaining...${N}"
        EXP_TMP=$(mktemp)

        if timeout 5s ollama run "$MODEL" "Explain: $CMD" > "$EXP_TMP" 2>/dev/null; then
            sed -e 's/^```[a-z]*//' -e 's/```$//' "$EXP_TMP" | head -10
            # Show short explanation
        else
            echo "Explanation failed"
        fi

        rm -f "$EXP_TMP"
        log_history "✗"
        ;;
    o|O)
        # Copy command to clipboard using available tool

        if type pbcopy >/dev/null 2>&1; then
            echo -n "$CMD" | pbcopy
        elif type xclip >/dev/null 2>&1; then
            echo -n "$CMD" | xclip -selection clipboard
        elif type wl-copy >/dev/null 2>&1; then
            echo -n "$CMD" | wl-copy
        elif type clip.exe >/dev/null 2>&1; then
            echo -n "$CMD" | clip.exe
        else
            echo -e "${Y}No clipboard tool${N}"
            echo "Command: $CMD"
        fi

        echo -e "${G}✓ Copied${N}"
        log_history "✗"
        ;;
    h|H)
        echo -e "${Y}Last 10:${N}"

        if [[ -s "$HISTORY_FILE" ]]; then
            IFS='|'
            tail -10 "$HISTORY_FILE" | while read -r date time status query cmd; do
                printf "  %s %s [%s] %s\n" "$date" "$time" "$status" "${query:0:40}"
            done
        else
            echo "  No history yet"
        fi
        ;;
    n|N|*)
        echo -e "${R}Cancelled${N}"
        log_history "✗"
        ;;
esac
