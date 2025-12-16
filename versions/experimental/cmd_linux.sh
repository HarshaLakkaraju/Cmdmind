#!/bin/bash

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
N='\033[0m'

[ -z "$1" ] && echo -e "${Y}Usage: cmd \"your query\"${N}" && exit 1

QUERY="$*"
echo -e "${Y}🤖 Generating...${N}"

CMD=$(ollama run shellcmd "$QUERY" 2>/dev/null | sed -e 's/[[:space:]]*$//')

[ -z "$CMD" ] && echo -e "${R}✗ No command generated${N}" && exit 1

echo -e "${G}📋 Command:${N}"
echo "    $CMD"
echo ""

DANGER="rm -rf|dd if=|mkfs|:(){:|:&};:|chmod -R 777"

if echo "$CMD" | grep -qE "$DANGER"; then
    echo -e "${R}⚠️  WARNING: Destructive command!${N}"
    read -p "Type 'YES' to confirm: " confirm
    [ "$confirm" != "YES" ] && echo -e "${R}Cancelled${N}" && exit 1
fi

read -p "Execute? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${G}✓ Running...${N}"
    bash -c "$CMD"
else
    echo -e "${R}✗ Cancelled${N}"
fi
