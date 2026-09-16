#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
bindings="$config_home/hypr/bindings.lua"
plugin_lua="$config_home/omarchy/plugins/io.github.midastruth.omajump/super-tap.lua"
marker="-- OmaJump: begin"

if [[ ! -f "$plugin_lua" ]]; then
  echo "OmaJump is not installed at: $plugin_lua" >&2
  exit 1
fi

mkdir -p "$(dirname "$bindings")"
touch "$bindings"

if grep -Fqx -- "$marker" "$bindings"; then
  echo "OmaJump's Super-tap integration is already installed."
  exit 0
fi

backup="$bindings.bak.omajump.$(date +%s)"
cp "$bindings" "$backup"

cat >>"$bindings" <<'LUA'

-- OmaJump: begin
-- Tap Super by itself to show numbered hints without changing SUPER + number.
dofile((os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config") ..
  "/omarchy/plugins/io.github.midastruth.omajump/super-tap.lua")
-- OmaJump: end
LUA

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  errors="$(hyprctl configerrors)"
  if [[ -n "$errors" ]]; then
    cp "$backup" "$bindings"
    hyprctl reload >/dev/null || true
    echo "Hyprland rejected the change; restored $backup" >&2
    echo "$errors" >&2
    exit 1
  fi
fi

echo "Installed OmaJump's lone-Super launcher."
echo "Backup: $backup"
