# CmdMind

**Think it. Review it. Run it.**
Natural language → safe shell commands. Fully local. Fully offline.




## Quick Links

* [Overview](#overview)
* [Installation](#installation)

  * [Automatic Installation](#-automatic-installation-recommended)
  * [Manual Installation](#-manual-installation-advanced--developers)
* [Quick Start](#quick-start)
* [Usage](#usage)
* [Architecture](#architecture)

  * [Repository Structure](#repository-structure)
  * [Main Script – cmdmindsh](#main-script-cmdmindsh)
  * [Model Configuration – modelfile-cmdmind](#model-configuration-modelfile-cmdmind)
* [AI Model Customization](#ai-model-customization)
* [Shell Code Customization](#shell-code-customization)
* [Usage-Based Modes](#usage-based-modes)
* [History & Auditing](#history--auditing)
* [Performance](#performance)
* [License](#license)




## **Overview**

CmdMind translates your intent into precise shell commands using a **local AI model**, keeping the entire process on your machine. You get AI's intelligence without sacrificing control or privacy.

## **Core Philosophy**

> **Think it. Review it. Run it.**

We believe you should understand every command before it runs. CmdMind gives you the **power of AI with the safety of human oversight**.

## **Why CmdMind Exists**

| Problem | Solution |
|---------|----------|
| Forgetting command syntax | Natural language → immediate recall |
| Risky operations | Destructive pattern detection + confirmation |
| Privacy concerns | 100% local, zero telemetry |
| Slow lookups | Sub-second responses |
| Complex pipelines | AI-assisted construction |


## **Key Principles**

### **🔒 Privacy First**
- No cloud calls, no API keys
- Your queries stay on your machine
- History stored locally in plain text

### **🛡️ Safety by Design**
- No automatic execution—ever
- Warning system for destructive commands
- All commands visible before running

### **⚡ Developer Friendly**
- Plain Bash script (no compiled code)
- Readable model configuration
- Easy to audit and modify

### **📖 Radical Transparency**
- Every component is inspectable
- No hidden behaviors or telemetry
- History format designed for auditing

## **Who It's For**

- **Beginners** who want to learn shell commands safely
- **Experts** who need quick command recall without context switching
- **Developers** who value transparency and local-first tools
- **Teams** who want consistent command patterns with audit trails


It is designed for **both users and developers**, with radical transparency:

* 📴 **100% Offline** – No cloud, no API keys, no telemetry
* ⚡ **Fast** – Sub‑second responses with warm models
* 🔐 **Safe by design** – No auto‑execution, destructive warnings
* 🧩 **Understandable** – Plain Bash + readable model config

**Nothing is hidden. Everything is inspectable.**



## Installation

### ✅ Automatic Installation (Recommended)

The **intended and safest** way to install CmdMind.

```bash
chmod +x setup_cmdmind.sh
./setup_cmdmind.sh #Linux | Mac
```

**What this script does (fully transparent):**

* Installs / verifies Ollama
* Pulls the required base model
* Builds the `cmdmind` model from `Modelfile-cmdmind`
* Installs `cmdmind.sh`
* Sets permissions
* Adds PATH and `cmd` alias

After completion, CmdMind is ready to use.

---

### 🔧 Manual Installation (Advanced / Developers)

Use this if you want **full control** or are modifying internals.

#### Requirements

* Bash 4.0+
* Ollama running
* ~2–4 GB RAM

#### Steps

1. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

2. Pull a base model

```bash
ollama pull qwen2.5-coder:1.5b
# or
ollama pull deepseek-coder:1.3b
```

3. Create CmdMind model

```bash
ollama create cmdmind -f Modelfile-cmdmind
```

4. Install main script

```bash
chmod +x cmdmind.sh
mkdir -p ~/bin
cp cmdmind.sh ~/bin/cmdmind
```

5. Add PATH & alias

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
echo 'alias cmd="cmdmind"' >> ~/.bashrc
source ~/.bashrc
```

---

## Quick Start

```bash
cmd "find all python files modified today"
```

Interactive mode:

```bash
cmd
```

---

## Usage

After generation, **you stay in control**:

* `y` → Execute
* `e` → Explain
* `c` → Copy
* `h` → History
* `n` → Cancel

Examples:

```bash
cmd "compress logs folder as tar.gz"
cmd "top 10 memory consuming processes"
cmd "undo last commit but keep changes"
```

---

## Architecture

CmdMind follows a **single, clean repository structure**.
Only **stable, user‑facing files live at the root**.
All other versions are explicitly isolated.

---

### Repository Structure

```text

├── LICENSE                         # Project license information
├── Modelfile-shell                 # Core model/configuration definition
├── readme.md                       # Main project documentation (entry point)
│
├── Linux/                          # Linux-specific implementation
│   ├── cmd_linux.sh                # Primary Linux command execution script
│   └── setup_cmdmind.sh            # Linux environment setup & dependency installer
│
├── Mac/                            # macOS-specific implementation
│   ├── cmd_mac.sh                  # Primary macOS command execution script
│   └── cmd_mac_2.sh                # Alternate/extended macOS command version
│
├── docs/                           # Extended documentation
│   └── README.md                   # Detailed usage, design notes, and references
│
└── versions/                       # Versioned and experimental code
    ├── experimental/               #⚠️ Other versions (under development)
    │   ├── cmd_linux.sh             
    │   ├── cmd_linux_2.sh          
    │   └── cmd_linux_3.sh           
    │
    ├── v2/                         # Stable or refactored versioned release
    │   └── (future versioned code) # Placeholder for structured releases
    │
    └── version_readme.md           # Version history and change notes

```


**Rules:**

* Root = safe, auditable, production
* `versions/` = WIP, breaking changes allowed
* `docs/` = documentation only (no logic)

---

## Main Script (cmdmind.sh)


This is the **secure bridge** between natural language and shell commands. Here's what happens when you use `cmd`:

### **The Safety Pipeline**

```
Your Words → Model → Command → Danger Scan → Your Consent → Execution
```

### **Key Features**

1. **Parallel Generation**
   - 10-second timeout prevents hangs
   - Spinner shows live feedback

2. **Danger Detection**
   - Screens for `rm -rf`, `dd`, `mkfs`, `sudo rm` patterns
   - Requires explicit confirmation for risky commands

3. **Thread-Safe History**
   - 50-entry rotation with file locking
   - Plain text audit trail: `timestamp|status|query|command`

4. **Smart Extraction**
   - Handles markdown code blocks from model output
   - Extracts clean shell commands

5. **Action Menu**
   ```
   [y] Run   [e] Explain   [c] Copy   [h] History   [n] Cancel
   ```

### **Safety Architecture**
- **No auto-execution** - Every command requires `y` confirmation
- **Shell isolation** - Commands run in separate `bash -c` context
- **File locking** - Prevents history corruption during concurrent use
- **Temp file cleanup** - Automatic removal of intermediate files

### **Performance**
- Warm model: 200-500ms response time
- Cold model: 1-3s (with spinner feedback)
- 10-second timeout ensures responsiveness

> **The contract:** You see exactly what will run, choose to run/explain/cancel, and everything is logged for review. This is the only file that executes commands—everything else is configuration.

This is the **single trusted execution entry point**.

Responsibilities:

* Accept natural language input
* Call the Ollama model
* Preview generated command
* Ask for explicit confirmation
* Log history

If a user reads only one file, **this is it**.

---
## **Model Configuration: `Modelfile-cmdmind`**

This file defines **exactly how the AI thinks** about shell commands—nothing more.

### **Core Configuration**

```dockerfile
FROM qwen2.5-coder:1.5b          # 1.5B parameter model (fast & capable)
PARAMETER temperature 0.3        # Balanced creativity/safety
PARAMETER top_p 0.9              # Focus on high-probability tokens
PARAMETER num_ctx 2048           # Context window size
PARAMETER num_predict 128        # Max output length
PARAMETER stop "```" "###"       # Stop at code block markers
```

### **The Personality Prompt**

The `SYSTEM` instruction creates a specialized shell expert:

```text
RULES:
• Output ONLY the command, nothing else
• No explanations unless explicitly asked
• Prefer safe, non-destructive commands
• For destructive operations, add safety flags
• Use modern syntax (e.g., $(command) not backticks)
• Detect OS context when relevant
```

**Example behavior:**
```
Input: "find python files"
Output: find . -name "*.py" -type f
```

**Not:**
```
Output: You can use find command with -name flag...
```

### **Why This Matters**

| Setting | Effect | User Benefit |
|---------|--------|--------------|
| `temperature 0.3` | Less random, more consistent | Same query → same command |
| `stop "```"` | Stops at code block end | Clean command extraction |
| `num_predict 128` | Limits output length | Prevents verbose responses |
| `top_p 0.9` | Balances creativity | Useful but safe suggestions |

## **Key Design Decisions**

1. **No Chat, Only Commands**
   - The model never explains unless asked
   - Zero preamble in output
   - Pure utility focus

2. **Safety First**
   - Explicit destructive operation warnings
   - Modern syntax by default
   - Conservative flags when in doubt

3. **Context Awareness**
   - Infers OS from commands
   - Adjusts for common shells (bash/zsh)
   - Uses standard POSIX when possible

### **Customization Guide**

**Swap Models:**
```dockerfile
FROM deepseek-coder:1.3b        # Even smaller, faster
# OR
FROM codellama:7b               # More accurate, slower
```

**Adjust Safety/ Creativity:**
```dockerfile
PARAMETER temperature 0.1       # Very deterministic (safe)
PARAMETER temperature 0.7       # More creative (riskier)
```

**Rebuild after changes:**
```bash
ollama create cmdmind -f Modelfile-cmdmind
```

---

> **Note:** This file only controls AI behavior. The `cmd_3_comment.sh` script handles execution safety, history, and user interaction.

---

## AI Model Customization

Edit `Modelfile-cmdmind` to change behavior.

Change model:

```dockerfile
FROM deepseek-coder:1.3b
```

Rebuild:

```bash
ollama create cmdmind -f Modelfile-cmdmind
```

Lower temperature = safer & deterministic.

---

## Shell Code Customization

CmdMind is plain Bash.

Common tweaks:

* Disable execution (copy‑only mode)
* Enforce allow / deny rules
* Change history handling

Only `cmdmind.sh` is production logic.
Other experiments belong in `versions/`.

---

## Usage-Based Modes

Possible workflows:

* Beginner → explanations always on
* Power user → copy‑only
* Automation → generation only

All handled in shell logic, not the model.

---

## History & Auditing

```bash
cat ~/.cmdmind_history
grep "✓" ~/.cmdmind_history
```

Plain text. No lock‑in.

---

## Performance

Warm the model:

```bash
ollama run qwen2.5-coder:1.5b
```

Cold: ~1–3s · Warm: ~0.2–0.5s

---

## License

MIT License

---

## Acknowledgments

* Ollama – local LLM runtime
* Qwen / DeepSeek – base models
* Open‑source community
