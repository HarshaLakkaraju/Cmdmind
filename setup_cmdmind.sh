#!/bin/bash
# setup_cmdmind.sh - Enterprise-grade, production-ready setup script for cmdmind
# Author: Harsha lakkaraju
# Description: Installs cmdmind tool, sets up Ollama model, scripts, history, aliases, and verifies installation.

# Exit immediately if a command fails
set -e
# Exit if any command in a pipeline fails
set -o pipefail

########################
# 0. Terminal Colors
########################
G='\033[0;32m'   # Green text (success)
Y='\033[1;33m'   # Yellow text (info/warning)
R='\033[0;31m'   # Red text (error)
N='\033[0m'      # Reset text color to normal

# Inform user that setup has started
echo -e "${G}🚀 Starting cmdmind setup...${N}"

#############################
# 1. Banner
#############################
print_banner() {
cat <<'EOF'
╔════════════════════════════════════════╗
║              🧠 cmdmind                ║ 
║    AI-powered command generator        ║
║          Installer v2.0                ║
╚════════════════════════════════════════╝
EOF
}

########################
# 1. Detect platform
########################
OS="$(uname)"  # Get operating system name
case "$OS" in
    Linux) PLATFORM="Linux"; SCRIPT_SRC="Linux/cmd_linux.sh" ;;  # If Linux, pick Linux script
    Darwin) PLATFORM="Mac"; SCRIPT_SRC="Mac/cmd_mac.sh" ;;       # If macOS, pick Mac script
    *) echo -e "${R}Unsupported OS: $OS${N}"; exit 1 ;;          # Exit if OS is unsupported
esac
# Show detected platform
echo -e "${G}Platform detected: $PLATFORM${N}"

########################
# 2. Verify dependencies ,  Bash version Platform-specific dependencies
########################
# Essential tools needed for setup

if [[ "$PLATFORM" == "Mac" ]]; then
    echo -e "${Y}Running macOS dependency installer...${N}"

    if [[ ! -f "Mac/dependency.sh" ]]; then
        echo -e "${R}Error: Mac/dependency.sh not found${N}"
        exit 1
    fi

    chmod +x Mac/dependency.sh
    Mac/dependency.sh

else
    echo -e "${G}Using native Linux dependencies${N}"

    deps=(bash sed awk curl timeout)

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${R}Error: Missing dependency $dep${N}"
            exit 1
        fi
    done
fi

echo -e "${G}Dependency check completed${N}"


deps=(bash sed awk curl)
# Only Linux requires 'timeout'
if [[ "$PLATFORM" == "Linux" ]]; then
    deps+=(timeout)
fi

# Loop through each dependency and check if installed
for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        # Exit with error if dependency missing
        echo -e "${R}Error: Missing dependency $dep${N}"
        exit 1
    fi
done
echo -e "${G}All essential dependencies verified${N}"

########################
# 3. Install Ollama if missing
########################
if ! command -v ollama >/dev/null 2>&1; then
    # Install Ollama if not found
    echo -e "${Y}Ollama not found. Installing...${N}"
    curl -fsSL https://ollama.com/install.sh | bash
else
    # Inform user Ollama is already installed
    echo -e "${G}Ollama already installed${N}"
fi

########################
# 3b. Start Ollama service
########################
# Check if Ollama service is running
if ! pgrep -x "ollama" >/dev/null 2>&1; then
    echo -e "${Y}Starting Ollama service...${N}"
    # Start Ollama in background
    ollama serve >/dev/null 2>&1 &
    # Wait a few seconds for service to initialize
    sleep 3
fi

########################
# 4. Pull base model
########################
BASE_MODEL="qwen2.5-coder:1.5b"  # Base model required by cmdmind
# Check if model already exists
if ! ollama list | grep -q "$BASE_MODEL"; then
    echo -e "${G}Pulling base model: $BASE_MODEL${N}"
    # Pull base model from Ollama
    ollama pull "$BASE_MODEL"
else
    echo -e "${G}Base model already exists: $BASE_MODEL${N}"
fi

########################
# 5. Verify Modelfile
########################
MODEL_NAME="cmdmind"          # Name of the custom model
MODELPATH="./Modelfile-shell" # Path to the Modelfile
# Ensure Modelfile exists
if [[ ! -f "$MODELPATH" ]]; then
    echo -e "${R}Error: Modelfile-shell not found at $MODELPATH${N}"
    exit 1
fi

########################
# 6. Create Ollama model
########################
# Check if model already exists
if ! ollama list | grep -q "$MODEL_NAME"; then
    echo -e "${G}Creating Ollama model: $MODEL_NAME${N}"
    # Create the model using Modelfile
    ollama create "$MODEL_NAME" -f "$MODELPATH"
else
    echo -e "${G}Ollama model $MODEL_NAME already exists${N}"
fi

########################
# 7. Determine installation path
########################
# Try user-local bin folders first, fallback to system-wide
if [[ -w "$HOME/bin" ]]; then
    BIN_DIR="$HOME/bin"
elif [[ -w "$HOME/.local/bin" ]]; then
    BIN_DIR="$HOME/.local/bin"
else
    echo -e "${Y}No user bin writable, using /usr/local/bin with sudo${N}"
    BIN_DIR="/usr/local/bin"
    sudo mkdir -p "$BIN_DIR"
fi
# Ensure target directory exists
mkdir -p "$BIN_DIR"

########################
# 8. Install main script
########################
SCRIPT_TARGET="$BIN_DIR/cmdmind"  # Full path to installed script
# Check if platform-specific script exists
if [[ ! -f "$SCRIPT_SRC" ]]; then
    echo -e "${R}Error: Platform script $SCRIPT_SRC not found${N}"
    exit 1
fi
# Copy script to bin and make executable
cp "$SCRIPT_SRC" "$SCRIPT_TARGET"
chmod +x "$SCRIPT_TARGET"
echo -e "${G}Installed cmdmind script to $SCRIPT_TARGET${N}"

########################
# 9. Setup history file
########################
# File for storing command generation history
HISTORY_FILE="$HOME/.cmdmind_history"
touch "$HISTORY_FILE"  # Create if not exists
echo -e "${G}History file: $HISTORY_FILE${N}"

########################
# 10. Configure shell PATH and alias
########################
SHELL_RC=""
# Detect shell configuration file
if [[ "$SHELL" == *bash ]]; then
    SHELL_RC="$HOME/.bashrc"
elif [[ "$SHELL" == *zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.config/fish/config.fish" ]]; then
    SHELL_RC="$HOME/.config/fish/config.fish"
fi

# Add alias if not already present
if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "alias cmd=" "$SHELL_RC"; then
        # Fish shell syntax differs slightly
        if [[ "$SHELL_RC" == *"fish"* ]]; then
            echo "alias cmd='$SCRIPT_TARGET'" >> "$SHELL_RC"
        else
            echo "alias cmd='$SCRIPT_TARGET'" >> "$SHELL_RC"
        fi
        echo -e "${G}Alias 'cmd' added to $SHELL_RC${N}"
        echo "Run: source $SHELL_RC to activate alias"
    fi
fi

# Add BIN_DIR to PATH if missing
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if [[ "$SHELL_RC" == *"fish"* ]]; then
        echo "set -gx PATH \$PATH $BIN_DIR" >> "$SHELL_RC"
    else
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$SHELL_RC"
    fi
    echo -e "${Y}Added $BIN_DIR to PATH in $SHELL_RC${N}"
fi

########################
# 11. Model verification
########################
# Run a simple test query to ensure the model is responsive
echo -e "${G}Verifying model...${N}"
if ollama run "$MODEL_NAME" "echo test" >/dev/null 2>&1; then
    echo -e "${G}Model verification successful${N}"
else
    echo -e "${Y}Warning: Model created but verification failed${N}"
fi

########################
# 12. Final installation check
########################
# Ensure cmdmind command works
if command -v cmd
 >/dev/null 2>&1; then
    echo -e "${G}✅ cmdmind installation complete!${N}"
    echo "Test with: cmdmind 'list files in ~/Documents'"
else
    echo -e "${R}❌ Installation failed. Check errors above.${N}"
    exit 1
fi
