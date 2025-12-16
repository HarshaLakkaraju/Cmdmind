#!/bin/bash
set -o pipefail

# Colors
G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

# History
HISTORY="$HOME/.shellgen_history"
touch "$HISTORY" 2>/dev/null

# Interactive mode if no args
if [ $# -eq 0 ]; then
    read -rp "Describe command: " QUERY
else
    QUERY="$*"
fi

[ -z "$QUERY" ] && echo -e "${Y}Query cannot be empty${N}" && exit 1

echo -e "${Y}🤖 Generating...${N}"

# Generate command
CMD=$(ollama run shellcmd "$QUERY" 2>/dev/null \
    | sed -e 's/^```.*//' -e 's/```$//' -e 's/[[:space:]]*$//')

[ -z "$CMD" ] && echo -e "${R}✗ No command generated${N}" && exit 1

# Show command
echo -e "${G}📋 Command:${N}"
echo "    $CMD"
echo ""

# Destructive command detection
DANGER='(^|[[:space:]])(rm[[:space:]]+-rf|dd[[:space:]]+if=|mkfs|chmod[[:space:]]+-R[[:space:]]+777|:()\{:\|:&\};:)'
if echo "$CMD" | grep -qE "$DANGER"; then
    echo -e "${R}⚠️  WARNING: Destructive command detected!${N}"
    read -rp "Type 'YES' to confirm: " confirm
    if [ "$confirm" != "YES" ]; then
        echo -e "${R}Cancelled for safety${N}"
        echo "$(date '+%F %T') | ✗ | $QUERY | $CMD" >> "$HISTORY"
        exit 1
    fi
fi

# Action menu
read -rp "Action? [y/n/e/c/h]: " -n 1 -r
echo ""

case $REPLY in
    [Yy])
        echo -e "${G}✓ Running...${N}"
        bash -c "$CMD"
        echo "$(date '+%F %T') | ✓ | $QUERY | $CMD" >> "$HISTORY"
        ;;
    [Ee])
        echo -e "${Y}💡 Explanation:${N}"
        ollama run shellcmd "Explain this command: $CMD"
        echo "$(date '+%F %T') | ✗ | $QUERY | $CMD" >> "$HISTORY"
        ;;
    [Cc])
        if command -v xclip &>/dev/null; then
            echo -n "$CMD" | xclip -selection clipboard
        elif command -v pbcopy &>/dev/null; then
            echo -n "$CMD" | pbcopy
        elif command -v clip.exe &>/dev/null; then
            echo -n "$CMD" | clip.exe
        else
            echo -e "${R}Clipboard tool not found${N}"
            exit 1
        fi
        echo -e "${G}✓ Copied to clipboard${N}"
        echo "$(date '+%F %T') | ✗ | $QUERY | $CMD" >> "$HISTORY"
        ;;
    [Hh])
        echo -e "${Y}📜 Recent History:${N}"
        tail -n 10 "$HISTORY" 2>/dev/null || echo "No history yet"
        ;;
    *)
        echo -e "${R}✗ Cancelled${N}"
        echo "$(date '+%F %T') | ✗ | $QUERY | $CMD" >> "$HISTORY"
        ;;
esac
