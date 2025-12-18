#!/bin/bash
# uninstall_cmdmind.sh

echo "Removing cmdmind..."
rm -f ~/bin/cmdmind ~/.local/bin/cmdmind /usr/local/bin/cmdmind 2>/dev/null

# Remove from shell configs
for rc in ~/.bashrc ~/.zshrc ~/.config/fish/config.fish; do
    [ -f "$rc" ] && sed -i '/alias cmdmind=/d' "$rc" 2>/dev/null
done

echo "✅ cmdmind uninstalled"