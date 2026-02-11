# 🛡️ SafeRun Guard

**Runtime safety firewall for AI coding agents.**

SafeRun Guard is a Claude Code Plugin that intercepts dangerous commands and file operations **before they execute**. It protects your codebase from accidental `rm -rf /`, force pushes to main, credential overwrites, and more — automatically, silently, in ~20ms.

Compound commands like `echo ok && rm -rf /` are split and each segment is checked independently. Secret patterns (AWS keys, private keys, API tokens) are detected in file writes before they hit disk.

> **95% of actions — invisible.** SafeRun Guard only speaks up when something is actually dangerous.

---

## Quick Start

```bash
# Install from GitHub (recommended)
claude plugin install github:Cocabadger/saferun-guard
```

That's it. SafeRun Guard is now active for every Claude Code session.

### Other install methods

```bash
# Via marketplace — browse + install
/plugin marketplace add Cocabadger/saferun-guard
/plugin install saferun-guard@saferun-guard

# Clone and install locally
git clone https://github.com/Cocabadger/saferun-guard.git
claude plugin install ./saferun-guard

# Load for one session only
claude --plugin-dir ./saferun-guard
```

### Set up for your team

Add to your project's `.claude/settings.json` so every team member gets prompted to install:

```json
{
  "extraKnownMarketplaces": {
    "saferun-guard": {
      "source": {
        "source": "github",
        "repo": "Cocabadger/saferun-guard"
      }
    }
  },
  "enabledPlugins": {
    "saferun-guard@saferun-guard": true
  }
}
```

---

## What It Does

SafeRun Guard sits between Claude and your system. Every time Claude wants to run a shell command or write a file, SafeRun Guard checks it against **112 safety rules + 9 secret patterns** in ~20ms:

```
Claude wants to run: git push --force origin main
                          │
                          ▼
                   SafeRun Guard
                          │
       ┌──────────┬───────┼───────┬──────────┐
       │          │       │       │          │
    🔄 REDIRECT  🚫 BLOCK  ❓ ASK  ✅ ALLOW
    (3 rules)  (27+25)  (25+23)  (silent)
       │          │       │       │
    Suggest    Agent    User    Command
    safer      sees     sees    executes
    command    block    prompt  normally
```

### Four Decisions

- 🔄 **REDIRECT** — suggest a safer alternative. Agent rewrites the command.
  `git push --force` → *"Use --force-with-lease instead"*

- 🚫 **BLOCK** — command denied. Claude sees the reason and adapts.
  `sudo rm -rf /` → *"Recursive delete as root"*

- ❓ **ASK** — user gets a confirmation prompt.
  `git push origin main` → *"Push to production branch — allow?"*

- ✅ **ALLOW** — silent passthrough. No delay, no prompt.
  `npm test`, `git status`, `ls -la`

### Compound Command Splitting

Commands chained with `&&`, `||`, or `;` are split and each segment is checked independently:

```
echo ok && rm -rf /
    │           │
    ✅          🚫 BLOCK — caught!
```

Pipe `|` is **not** split — it's part of a single pipeline (`grep foo | wc -l` is safe).

### Content Scanning

File writes and edits are scanned for **9 secret patterns** before they hit disk:

- AWS access keys (`AKIA...`) and secret keys
- Private keys (PEM `-----BEGIN...PRIVATE KEY-----`)
- GitHub tokens (`ghp_`, `gho_`, `ghs_`, `ghr_`)
- OpenAI / Stripe keys (`sk-...`)
- Slack tokens (`xox[bpras]-...`)
- Database connection strings with passwords
- Generic API keys and hardcoded passwords

---

## What's Protected

### 🚫 Blocked Commands (27 rules)

- **Git destructive** — `git push --force`, `git reset --hard`, `git clean -fd`, delete main/master branch, interactive rebase
- **Filesystem** — `rm -rf /`, `rm -rf .`, `chmod 777`, `chmod -R 777`, `dd`, `mkfs`, `sudo rm -rf`
- **Code execution** — `curl ... | bash`, `wget ... | sh` — remote code execution
- **Credentials** — `rm -rf ~/.ssh`, destroy SSH keys, overwrite `/etc/passwd`
- **Infrastructure** — `docker system prune -a`, fork bombs, `kubectl delete namespace`
- **History** — `history -c`, `history --clear` — audit trail destruction
- **Lockfiles** — overwrite `package-lock.json`, `yarn.lock`, `Cargo.lock` via shell

### ❓ Ask User (25 rules)

- **Git production** — `git push origin main`, `git merge main`, delete tags
- **Infrastructure** — `kubectl apply/delete`, `terraform apply/destroy`
- **Cloud / IaC** — `helm install/upgrade/uninstall/rollback`, `pulumi up/destroy`, `cdk deploy/destroy`
- **CI / GitHub** — `gh pr merge/close`, `gh release create/delete`
- **AWS** — `aws ec2 run/terminate/stop`, `aws s3 rm/rb`
- **Config mgmt** — `ansible-playbook` (excluding `--check`/`--diff`/`--syntax-check`)
- **Publishing** — `npm publish`, `pip upload`, `docker push`, `gem push`
- **Database** — `db migrate`, `db drop`, SQL execution on prod
- **Services** — `systemctl stop`, `service restart`

### 🚫 Blocked File Writes (25 rules)

- **Secrets** — `.env`, `.env.*`
- **SSH/Keys** — `.ssh/`, `*.pem`, `*.key`, `*.p12`
- **Cloud credentials** — `.aws/credentials`, `.config/gcloud/`, `.kube/config`
- **Registry tokens** — `.npmrc`, `.pypirc`
- **Docker/Network auth** — `.docker/config.json`, `.netrc`
- **GPG keys** — `.gnupg/`
- **Git internals** — `.git/` (objects, refs, HEAD — not `.gitignore`)
- **Shell config** — `.bashrc`, `.zshrc`, `.profile`, `.bash_profile`
- **System paths** — `/etc/`, `/usr/`, `/var/`, `/System/`
- **Lockfiles** — `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Cargo.lock`, `Gemfile.lock`, `Pipfile.lock`, `composer.lock`

### ❓ Ask Before Writing (23 rules)

CI/CD configs (`.github/workflows/`, `.circleci/`, `buildspec.yml`, `cloudbuild.yaml`), Dockerfiles, Terraform (`*.tf`), Kubernetes manifests, Ansible playbooks, SQL files, migration files, CODEOWNERS, Nginx (`nginx.conf`), Serverless (`serverless.yml`), deployment configs (Procfile, `fly.toml`, `vercel.json`, `netlify.toml`, `render.yaml`, `heroku.yml`).

### 🔄 Redirect Commands (3 rules)

| Dangerous | Safer Alternative |
|---|---|
| `git push --force` | `git push --force-with-lease` |
| `git clean -f` | `git clean -n` (dry-run first) |
| `docker system prune` | `docker system prune --dry-run` |

---

## Real-World Examples

### 1. Prevents accidental force push to production

A developer asks Claude to "push my changes." Claude runs `git push --force origin main`. SafeRun Guard intercepts it via the REDIRECT tier and tells Claude: *"Use `git push --force-with-lease` instead — it only overwrites if no one else has pushed since your last fetch."* Claude rewrites the command automatically. No data loss, no broken team history.

### 2. Catches destructive commands hidden in compound chains

Claude runs `echo "cleaning up temp files" && rm -rf . && echo "done"`. SafeRun Guard splits the compound command on `&&`, checks each segment independently, and blocks `rm -rf .` — even though it's sandwiched between two harmless echo commands. Without splitting, this would pass a simple regex check.

### 3. Detects leaked secrets before they're written to disk

Claude generates a config file and includes `AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"` directly in the source code. SafeRun Guard scans file content for 9 secret patterns (AWS keys, private keys, GitHub tokens, API keys) and asks the user before allowing the write. The secret never reaches git history.

---

## Slash Commands

- `/saferun-guard:status` — show loaded rules count, audit stats, plugin info
- `/saferun-guard:log` — show last 20 agent actions from audit log

---

## Audit Log

Every action Claude takes is logged to `~/.saferun/audit.jsonl`:

```json
{"ts":"2026-02-10T14:32:01Z","session":"abc123","tool":"Bash","input":"npm test","cwd":"/Users/art/project"}
{"ts":"2026-02-10T14:32:15Z","session":"abc123","tool":"Write","input":"/Users/art/project/src/app.ts","cwd":"/Users/art/project"}
```

Use `/saferun-guard:log` to view recent activity, or read the file directly.

---

## How It Works

SafeRun Guard uses [Claude Code Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) — the official plugin API for intercepting tool calls:

- **PreToolUse** hooks on `Bash` → `scripts/classify-command.sh`
  - Splits compound commands (`&&`, `||`, `;`) into segments
  - Checks each segment independently: REDIRECT → BLOCK → ASK → ALLOW
- **PreToolUse** hooks on `Write|Edit` → `scripts/classify-file.sh`
  - Path-based rules (BLOCK/ASK) + content scanning for secrets
- **PostToolUse** hook (async) → `scripts/audit-log.sh`

All scripts are **bash + jq** — zero dependencies. No Python, no Node, no pip install. Works on any macOS/Linux machine with jq installed.

Pattern matching uses **jq's Oniguruma regex engine** with case-insensitive matching. Every rule is a JSON object with `id`, `pattern`, `reason`, and `category`. Redirect rules add a `safe_pattern` field — if the command already uses the safe form, the redirect is skipped.

### Performance

- Safe command (no match, worst case) — **~20ms**
- Blocked command (early match) — **~19ms**
- Safe file write — **~20ms**
- Empty/missing input — **~9ms**

For context: Claude thinks for 2-10 seconds between actions. 20ms is imperceptible.

### Fail-Open Design

If any script errors (missing jq, corrupt JSON, etc.), the command **passes through**. SafeRun Guard should never block your work due to a plugin bug.

---

## Project Structure

```
saferun-guard/
├── .claude-plugin/
│   ├── plugin.json                # Plugin manifest
│   └── marketplace.json           # Marketplace catalog
├── hooks/hooks.json               # Hook event → script mapping
├── scripts/
│   ├── classify-command.sh        # PreToolUse: Bash (compound split + 4-tier)
│   ├── classify-file.sh           # PreToolUse: Write/Edit (path + content scan)
│   └── audit-log.sh              # PostToolUse: async JSONL logger
├── rules/
│   ├── redirect-commands.json     # 3 REDIRECT patterns (safer alternatives)
│   ├── block-commands.json        # 27 BLOCK patterns
│   ├── ask-commands.json          # 25 ASK patterns
│   ├── allow-commands.json        # 17 ALLOW categories
│   ├── block-files.json           # 25 BLOCK file patterns
│   ├── ask-files.json             # 23 ASK file patterns
│   └── scan-content.json          # 9 secret detection patterns
├── skills/
│   ├── log/SKILL.md               # /saferun-guard:log
│   └── status/SKILL.md            # /saferun-guard:status
└── tests/
    ├── test-commands.sh           # 143 tests
    └── test-files.sh             # 100 tests
```

---

## Testing

```bash
# Run all tests
bash tests/test-commands.sh && bash tests/test-files.sh

# 243 tests — command rules, file rules, compound splitting,
# redirect tier, content scanning, edge cases
```

---

## Requirements

- **macOS or Linux** (bash + jq)
- **jq 1.6+** (`brew install jq` or `apt install jq`)
- **Claude Code** with plugin support

---

## Disable or Uninstall

```bash
# Temporarily disable (keeps installed, can re-enable)
claude plugin disable saferun-guard@saferun-guard

# Re-enable
claude plugin enable saferun-guard@saferun-guard

# Update to latest version
claude plugin update saferun-guard@saferun-guard

# Remove completely
claude plugin uninstall saferun-guard@saferun-guard
```

---

## License

MIT — see [LICENSE](LICENSE).

---

## Links

- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [Discover Plugins & Marketplaces](https://code.claude.com/docs/en/discover-plugins)
- [Create a Plugin Marketplace](https://code.claude.com/docs/en/plugin-marketplaces)
- [Plugins Reference](https://code.claude.com/docs/en/plugins-reference)

---

Built by [SafeRun](https://github.com/Cocabadger/saferun-guard). SafeRun Guard is invisible until it saves your project.
