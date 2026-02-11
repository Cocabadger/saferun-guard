# 🛡️ SafeRun Guard

**Runtime safety firewall for AI coding agents.**

SafeRun Guard is a Claude Code Plugin that intercepts dangerous commands and file operations **before they execute**. It protects your codebase from accidental `rm -rf /`, force pushes to main, credential overwrites, and more — automatically, silently, in ~20ms.

> **95% of actions — invisible.** SafeRun Guard only speaks up when something is actually dangerous.

---

## Quick Start

```bash
# Install from local directory
claude plugin install ./saferun-guard

# Or from GitHub
claude plugin install github:saferun/saferun-guard
```

That's it. SafeRun Guard is now active for every Claude Code session.

---

## What It Does

SafeRun Guard sits between Claude and your system. Every time Claude wants to run a shell command or write a file, SafeRun Guard checks it against **95 safety rules** in ~20ms:

```
Claude wants to run: git push --force origin main
                          │
                          ▼
                   SafeRun Guard
                          │
              ┌───────────┼───────────┐
              │           │           │
           🚫 BLOCK     ❓ ASK     ✅ ALLOW
          (23 rules)   (16 rules)   (silent)
              │           │           │
         Agent sees    User sees    Command
         "Blocked:     "Allow?"     executes
          reason"      [y/n]        normally
```

### Three Decisions

- 🚫 **BLOCK** — command denied. Claude sees the reason and adapts.
  `git push --force` → *"Force push rewrites remote history"*

- ❓ **ASK** — user gets a confirmation prompt.
  `git push origin main` → *"Push to production branch — allow?"*

- ✅ **ALLOW** — silent passthrough. No delay, no prompt.
  `npm test`, `git status`, `ls -la`

---

## What's Protected

### 🚫 Blocked Commands (23 rules)

- **Git destructive** — `git push --force`, `git reset --hard`, `git clean -fd`, delete main/master branch, interactive rebase
- **Filesystem** — `rm -rf /`, `rm -rf .`, `chmod 777`, `dd`, `mkfs`
- **Code execution** — `curl ... | bash`, `wget ... | sh` — remote code execution
- **Credentials** — `rm -rf ~/.ssh`, destroy SSH keys, overwrite `/etc/passwd`
- **Infrastructure** — `docker system prune -a`, fork bombs
- **Lockfiles** — overwrite `package-lock.json`, `yarn.lock`, `Cargo.lock` via shell

### ❓ Ask User (16 rules)

- **Git production** — `git push origin main`, `git merge main`, delete tags
- **Infrastructure** — `kubectl apply/delete`, `terraform apply/destroy`
- **Publishing** — `npm publish`, `pip upload`, `docker push`, `gem push`
- **Database** — `db migrate`, `db drop`, SQL execution on prod
- **Services** — `systemctl stop`, `service restart`

### 🚫 Blocked File Writes (22 rules)

- **Secrets** — `.env`, `.env.*`
- **SSH/Keys** — `.ssh/`, `*.pem`, `*.key`, `*.p12`
- **Cloud credentials** — `.aws/credentials`, `.config/gcloud/`, `.kube/config`
- **Registry tokens** — `.npmrc`, `.pypirc`
- **Git internals** — `.git/` (objects, refs, HEAD — not `.gitignore`)
- **Shell config** — `.bashrc`, `.zshrc`, `.profile`, `.bash_profile`
- **System paths** — `/etc/`, `/usr/`, `/var/`, `/System/`
- **Lockfiles** — `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Cargo.lock`, `Gemfile.lock`, `Pipfile.lock`, `composer.lock`

### ❓ Ask Before Writing (17 rules)

CI/CD configs, Dockerfiles, Terraform (`*.tf`), Kubernetes manifests, Ansible playbooks, SQL files, migration files, CODEOWNERS, deployment configs (Procfile, `fly.toml`, `vercel.json`, `netlify.toml`, `render.yaml`, `heroku.yml`).

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
- **PreToolUse** hooks on `Write|Edit` → `scripts/classify-file.sh`
- **PostToolUse** hook (async) → `scripts/audit-log.sh`

All scripts are **bash + jq** — zero dependencies. No Python, no Node, no pip install. Works on any macOS/Linux machine with jq installed.

Pattern matching uses **jq's Oniguruma regex engine** with case-insensitive matching. Every rule is a JSON object with `id`, `pattern`, `reason`, and `category`.

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
├── .claude-plugin/plugin.json     # Plugin manifest
├── hooks/hooks.json               # Hook event → script mapping
├── scripts/
│   ├── classify-command.sh        # PreToolUse: Bash commands
│   ├── classify-file.sh           # PreToolUse: Write/Edit files
│   └── audit-log.sh              # PostToolUse: async JSONL logger
├── rules/
│   ├── block-commands.json        # 23 BLOCK patterns
│   ├── ask-commands.json          # 16 ASK patterns
│   ├── allow-commands.json        # 17 ALLOW categories
│   ├── block-files.json           # 22 BLOCK file patterns
│   └── ask-files.json             # 17 ASK file patterns
├── skills/
│   ├── log/SKILL.md               # /saferun-guard:log
│   └── status/SKILL.md            # /saferun-guard:status
└── tests/
    ├── test-commands.sh           # 102 tests
    └── test-files.sh             # 80 tests
```

---

## Testing

```bash
# Run all tests
bash tests/test-commands.sh && bash tests/test-files.sh

# 182 tests — command rules + file rules
# Every BLOCK rule, every ASK rule, safe passthrough, edge cases
```

---

## Requirements

- **macOS or Linux** (bash + jq)
- **jq 1.6+** (`brew install jq` or `apt install jq`)
- **Claude Code** with plugin support

---

## License

MIT — see [LICENSE](LICENSE).

---

## Links

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code Plugins Guide](https://docs.anthropic.com/en/docs/claude-code/plugins)

---

Built by [SafeRun](https://github.com/saferun). SafeRun Guard is invisible until it saves your project.
