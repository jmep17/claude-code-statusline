# claude-code-statusline

A two-row [Claude Code](https://code.claude.com/docs/en/statusline) status line written in Bash + `jq`.

```
[Opus · max] 📁 config | 🌿 main
████░░░░░░ 42% ctx | 💾 89% cache | $1.23
```

**Row 1** — model · reasoning effort · current directory · git branch
**Row 2** — context-usage bar + %, cache hit rate, session cost

The context bar is color-coded: green under 70%, yellow 70–89%, red 90%+.

## Install

1. Copy `work-statusline.sh` to your machine (e.g. `~/.claude/work-statusline.sh`) and make it executable:
   ```bash
   chmod +x ~/.claude/work-statusline.sh
   ```
2. Install the only dependency, `jq`:
   ```bash
   brew install jq        # macOS
   sudo apt install jq    # Debian/Ubuntu
   ```
3. Add it to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/work-statusline.sh",
       "padding": 0
     }
   }
   ```

## Test without launching Claude Code

```bash
echo '{"model":{"display_name":"Opus"},"effort":{"level":"high"},"workspace":{"current_dir":"/tmp/proj"},"cost":{"total_cost_usd":0.5},"context_window":{"used_percentage":42,"current_usage":{"input_tokens":8500,"cache_creation_input_tokens":5000,"cache_read_input_tokens":120000}}}' | ~/.claude/work-statusline.sh
```

## Notes

- **Cache % is for the most recent API turn only.** Claude Code does not expose a session-wide cache figure on stdin, so the script reports the last turn's rate, computed as `cache_read / (input + cache_creation + cache_read)`. It shows `n/a` before the first response and right after `/compact`, until the next API call repopulates the data.
- **Branch needs a git repo.** It is blank outside one. The script `cd`s into the session directory first, so it resolves the branch even when Claude Code is launched elsewhere.
- **Effort shows `—`** when the active model does not support the reasoning-effort parameter.

## Field mapping

| Display | Source field (statusLine stdin JSON) |
| --- | --- |
| Model | `model.display_name` |
| Effort | `effort.level` |
| Directory | `workspace.current_dir` |
| Branch | `git branch --show-current` (not in JSON) |
| Context % / bar | `context_window.used_percentage` |
| Cache rate | `context_window.current_usage.*` |
| Cost | `cost.total_cost_usd` |
