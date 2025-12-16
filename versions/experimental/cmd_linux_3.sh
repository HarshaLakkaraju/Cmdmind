#!/bin/bash
set -o pipefail

########################
# Ultra-light defaults
########################
MODEL="shellcmd"
HISTORY_FILE="$HOME/.shellgen_history"
LOCK_FILE="$HISTORY_FILE.lock"
MAX_HISTORY=50
MAX_CMD_LENGTH=500

# Colors
G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

########################
# Minimal config loading
########################
[[ -f ~/.config/shellgen.conf ]] && . ~/.config/shellgen.conf 2>/dev/null
touch "$HISTORY_FILE" 2>/dev/null

########################
# Robust helpers
########################
log_history() {
    local status=$1
    local safe_query="${QUERY//|/\\|}"
    local safe_cmd="${CMD:0:$MAX_CMD_LENGTH}"
    local entry="$(date '+%F %T')|$status|$safe_query|$safe_cmd"
    
    exec 9>"$LOCK_FILE"
    flock -x 9
    echo "$entry" >> "$HISTORY_FILE"
    
    local line_count=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo 0)
    if [[ $line_count -gt $MAX_HISTORY ]]; then
        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" &&
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
    
    flock -u 9
    exec 9>&-
}

spinner() {
    local pid=$1
    local spinstr='-\|/'
    while kill -0 "$pid" 2>/dev/null 2>&1; do
        printf "\r${Y}[%c]${N}" "${spinstr:0:1}"
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep 0.05
    done
    printf "\r\033[K"
}

########################
# Fast input parsing
########################
if [[ $# -eq 0 ]]; then
    read -rp "Describe command: " QUERY
else
    QUERY="$*"
fi

[[ -z "$QUERY" ]] && echo -e "${R}Empty query${N}" && exit 1

########################
# Parallel generation with timeout
########################
TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)

timeout 10s ollama run "$MODEL" "$QUERY" >"$TMP_OUT" 2>"$TMP_ERR" &
OLLAMA_PID=$!

spinner $OLLAMA_PID &
SPINNER_PID=$!

wait $OLLAMA_PID 2>/dev/null
OLLAMA_EXIT=$?
kill $SPINNER_PID 2>/dev/null

if [[ $OLLAMA_EXIT -eq 124 ]] || [[ ! -s "$TMP_OUT" ]]; then
    echo -e "${R}✗ Model timeout/error${N}"
    [[ -s "$TMP_ERR" ]] && echo "Error: $(head -1 "$TMP_ERR")"
    rm -f "$TMP_OUT" "$TMP_ERR"
    exit 1
fi

########################
# Robust command extraction
########################
CMD=$(sed -e 's/^```[a-z]*//' -e 's/```$//' "$TMP_OUT")
CMD=$(echo "$CMD" | awk 'BEGIN{block=""; in_block=0} 
    /^[[:space:]]*[^[:space:]]/ {
        if(!in_block) in_block=1
        if(block=="") block=$0
        else if(NR<=5) block=block "\n" $0
    }
    /^[[:space:]]*$/ && in_block {exit}
    END{print block}')

CMD="${CMD#"${CMD%%[![:space:]]*}"}"
CMD="${CMD%"${CMD##*[![:space:]]}"}"

rm -f "$TMP_OUT" "$TMP_ERR"
[[ -z "$CMD" ]] && echo -e "${R}✗ Empty output${N}" && exit 1

########################
# Comprehensive danger detection
########################
check_danger() {
    local patterns=(
        'rm[[:space:]]+.*-[rf]'
        'rm[[:space:]]+-[[:alpha:]]*[rf]'
        'rm[[:space:]]+-[[:alpha:]]*R[[:alpha:]]*[fF]'
        'dd[[:space:]]+.*of='
        '>[[:space:]]*/dev/(sd|nvme|mmc)'
        '^[[:space:]]*:\(\)'
        'chmod[[:space:]]+[0-7][0-7][0-7][[:space:]]+/'
        '\$\([^)]*rm'
        'mkfs\.?'
        'fdisk[[:space:]]+/dev'
        'sudo[[:space:]]+rm'
        'sudo[[:space:]]+dd'
    )
    
    local danger_list=""
    for pattern in "${patterns[@]}"; do
        if [[ "$CMD" =~ $pattern ]]; then
            danger_list+="  • $pattern\n"
        fi
    done
    
    if [[ -n "$danger_list" ]]; then
        echo -e "${R}⚠️  Danger detected${N}"
        echo -e "${Y}Command:${N} $CMD"
        echo -e "${R}Matches:${N}"
        echo -e "$danger_list"
        read -rp "Continue? [y/N]: " -n 1 confirm
        echo ""
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
    fi
    return 0
}

check_danger || { log_history "✗" && exit 1; }

########################
# Formatted single-key action menu
########################
echo -e "${G}Command:${N} $CMD"
echo ""

# Formatted exactly as requested: [y]es, [e]xplain, [o]opy, [h]istory, [n]o
printf "  ${G}[y]${N}es, ${G}[e]${N}xplain, ${G}[c]${N}opy, ${G}[h]${N}istory, ${G}[n]${N}o\n"
echo ""

read -rp "Choice: " -n 1 REPLY
echo ""

case "$REPLY" in
    y|Y)
        echo -e "${G}Running...${N}"
        bash -c -- "$CMD"
        log_history "✓"
        ;;
    e|E)
        echo -e "${Y}Explaining...${N}"
        EXP_TMP=$(mktemp)
        if timeout 5s ollama run "$MODEL" "Explain: $CMD" > "$EXP_TMP" 2>/dev/null; then
            sed -e 's/^```[a-z]*//' -e 's/```$//' "$EXP_TMP" | head -10
        else
            echo "Explanation failed"
        fi
        rm -f "$EXP_TMP"
        log_history "✗"
        ;;
    o|O)
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
            {
                IFS='|'
                while read -r date time status query cmd; do
                    printf "  %s %s [%s] %s\n" \
                        "$date" "$time" "$status" "${query:0:40}"
                done
            } < <(tail -10 "$HISTORY_FILE" 2>/dev/null)
        else
            echo "  No history yet"
        fi
        ;;
    n|N|*)
        echo -e "${R}Cancelled${N}"
        log_history "✗"
        ;;
esac