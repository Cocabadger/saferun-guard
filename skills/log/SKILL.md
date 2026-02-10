---
name: log
description: Show the SafeRun Guard audit log — what actions the agent executed in recent sessions
---

Read the audit log file at `~/.saferun/audit.jsonl`. Each line is a JSON record of a tool action that was allowed and executed.

Fields: `ts` (timestamp), `session` (session ID), `tool` (Bash/Write/Edit/Read), `input` (command or file path), `cwd` (working directory).

Show the most recent 20 entries by default. If the user asks for more, show more.

Format as a readable table or summary. Group by session if there are multiple sessions.

If the file doesn't exist, tell the user no actions have been logged yet.
