#!/bin/sh
set -eu

: "${MCP_PROXY_AUTH_TOKEN:?MCP_PROXY_AUTH_TOKEN must be set}"
: "${HYPERRESEARCH_MCP_HOST:?HYPERRESEARCH_MCP_HOST must be set}"

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

case "$HYPERRESEARCH_MCP_HOST" in
    *[!a-zA-Z0-9.:-]*) fail 'HYPERRESEARCH_MCP_HOST must be a single Host authority without wildcards' ;;
esac

cd /vault
[ -r . ] && [ -w . ] && [ -x . ] || fail '/vault must be readable and writable'

if [ ! -e .hyperresearch ] && [ ! -L .hyperresearch ]; then
    for entry in .[!.]* ..?* *; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        # shortcut: ignore the filesystem-created directory; revisit if using another volume layout.
        [ "$entry" = lost+found ] && [ -d "$entry" ] && [ ! -L "$entry" ] && continue
        fail 'incomplete vault: /vault is not empty and has no .hyperresearch state'
    done
    hyperresearch init /vault
fi

for directory in .hyperresearch research research/notes research/index research/temp; do
    [ -d "$directory" ] && [ ! -L "$directory" ] \
        && [ -r "$directory" ] && [ -w "$directory" ] && [ -x "$directory" ] \
        || fail 'incomplete vault: missing, linked, or inaccessible vault directory'
done
for file in .hyperresearch/config.toml .hyperresearch/hyperresearch.db; do
    [ -f "$file" ] && [ ! -L "$file" ] && [ -s "$file" ] && [ -r "$file" ] \
        || fail 'incomplete vault: missing, linked, or inaccessible Hyperresearch config or database'
done
[ -w .hyperresearch/hyperresearch.db ] || fail 'incomplete vault: database is not writable'

exec mcp-proxy --host 0.0.0.0 --port 8080 --allowed-host "$HYPERRESEARCH_MCP_HOST" \
    --cwd /vault --initialization-timeout 20 -- hyperresearch mcp
