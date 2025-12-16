Here’s a **complete step-by-step guide** to set up your `cmdmind` tool on **both Linux and Mac** using the final production-grade script:

---

## **1️⃣ Clone or place the repo**

Make sure your folder structure looks like this:

```
.
├── setup_cmdmind.sh
├── Modelfile-shell
├── Linux/cmd_linux.sh
├── Mac/cmd_mac.sh
├── docs/
└── versions/
```

> `Modelfile-shell` and platform scripts must exist, otherwise setup will fail.

---

## **2️⃣ Make the setup script executable**

```bash
chmod +x setup_cmdmind.sh
```

---

## **3️⃣ Run the setup script**

```bash
./setup_cmdmind.sh
```

**What happens automatically:**

1. Detects OS (Linux or Mac)
2. Checks for required dependencies: `bash`, `sed`, `awk`, `timeout`, `curl`
3. Installs **Ollama** if it’s missing
4. Creates Ollama model `cmdmind` from `Modelfile-shell`
5. Detects the best install path (`~/bin` → `~/.local/bin` → `/usr/local/bin`)
6. Copies the **platform-specific script** (`cmd_linux.sh` or `cmd_mac.sh`)
7. Creates **history file** `~/.cmdmind_history`
8. Adds alias `cmdmind` to your shell config
9. Adds bin path to your `PATH` if missing
10. Verifies the model works
11. Shows success message

---

## **4️⃣ Activate the alias and PATH**

After installation, reload your shell to apply the alias:

```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

---

## **5️⃣ Test the installation**

Run a simple command:

```bash
cmdmind "list files in ~/Documents"
```

* You will see the **menu options**:

| Key | Action                     |
| --- | -------------------------- |
| y   | Run command                |
| e   | Explain command            |
| c   | Copy command to clipboard  |
| h   | Show last 10 history items |
| n   | Cancel                     |

---

## **6️⃣ Check history**

Your generated commands are stored in:

```bash
~/.cmdmind_history
```

Format:

```
YYYY-MM-DD HH:MM:SS | Status | Query | Generated Command
```

---

## **7️⃣ Optional post-install checks**

* Verify the script is executable:

```bash
ls -l ~/bin ~/.local/bin /usr/local/bin | grep cmdmind
```

* Rebuild or update Ollama model if needed:

```bash
ollama create cmdmind -f ./Modelfile-shell
```

---
