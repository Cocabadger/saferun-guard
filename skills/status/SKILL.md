---
name: status
description: Show SafeRun Guard status — loaded rules, recent activity stats, and configuration
---

Report the current SafeRun Guard status:

1. **Rules loaded**: Count rules in each JSON file under the plugin's `rules/` directory:
   - `block-commands.json` — BLOCK command rules
   - `ask-commands.json` — ASK command rules  
   - `allow-commands.json` — ALLOW command rules
   - `block-files.json` — BLOCK file rules
   - `ask-files.json` — ASK file rules

2. **Audit log stats**: Read `~/.saferun/audit.jsonl` and report:
   - Total entries
   - Entries from today
   - Most common tools used
   - Most common commands/files

3. **Plugin info**: Read `.claude-plugin/plugin.json` for version and description.

If the audit log doesn't exist, note that no actions have been logged yet.
