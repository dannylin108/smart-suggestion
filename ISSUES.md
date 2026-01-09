# Known Issues

## Proxy Mode

### Problem

When proxy mode is enabled (default), the plugin spawns a **nested shell**. This is because the proxy wraps the shell in a PTY to capture terminal output for AI context.

Users see two shells spawning when opening a terminal, which is jarring.

### Why Proxy Mode Exists

The plugin needs terminal history (recent commands and output) to provide context to the AI. Different terminals have different ways to access scrollback:

| Terminal | Method |
|----------|--------|
| tmux | `tmux capture-pane` |
| kitty | `kitten @ get-text` |
| Others | No standard API - proxy mode fills this gap |

Proxy mode captures all terminal I/O by wrapping the shell in a PTY and logging to `/tmp/smart_suggestion_proxy.log`.

### Current Workaround

Disable proxy mode if you don't need terminal context, or if you use tmux/kitty:

```bash
export SMART_SUGGESTION_PROXY_MODE=false
```

### Potential Solutions

1. **Use `exec` instead of spawning nested shell**

   Change `smart-suggestion.plugin.zsh` line 231 from:
   ```zsh
   "$SMART_SUGGESTION_BINARY" proxy
   ```
   to:
   ```zsh
   exec "$SMART_SUGGESTION_BINARY" proxy
   ```

   This replaces the original shell instead of nesting. Caveat: if proxy crashes, terminal closes.

2. **Add missing guard in zsh plugin**

   Line 230 should also check `SMART_SUGGESTION_PROXY_ACTIVE` to avoid calling the binary unnecessarily on the nested shell:
   ```zsh
   if [[ "$SMART_SUGGESTION_PROXY_MODE" == "true" && -z "$TMUX" && -z "$KITTY_LISTEN_ON" && -z "$SMART_SUGGESTION_PROXY_ACTIVE" ]]; then
   ```

3. **Use zsh preexec/precmd hooks**

   Capture commands and output via shell hooks instead of PTY wrapping. More complex to implement.

### Related Code

- `smart-suggestion.plugin.zsh:230-232` - proxy mode trigger
- `cmd/smart-suggestion/main.go:1353-1570` - `runProxy` function
- `cmd/smart-suggestion/main.go:1572-1653` - `getShellBuffer` function (context retrieval methods)
