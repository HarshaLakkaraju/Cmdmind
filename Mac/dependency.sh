########################
# Dependency Management
########################

echo "🔍 Checking system dependencies..."

# -------- Homebrew --------
if ! command -v brew >/dev/null 2>&1; then
    echo "🍺 Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "❌ Homebrew installation failed"
        exit 1
    }

    # Ensure brew is available in current shell
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# -------- Helper --------
brew_install_if_missing() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "📦 Installing $2..."
        brew install "$2" || {
            echo "❌ Failed to install $2"
            exit 1
        }
    fi
}

# -------- Core Dependencies --------
brew_install_if_missing ollama ollama
brew_install_if_missing flock flock

# coreutils → gtimeout
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
    brew_install_if_missing gtimeout coreutils
fi

# -------- Clipboard (macOS native) --------
if ! command -v pbcopy >/dev/null 2>&1; then
    echo "❌ pbcopy not found (unexpected on macOS)"
    exit 1
fi

echo "✅ All dependencies installed and ready"
