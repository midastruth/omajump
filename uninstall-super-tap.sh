#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
bindings="$config_home/hypr/bindings.lua"

if [[ ! -f "$bindings" ]] || ! grep -Fqx -- "-- OmaJump: begin" "$bindings"; then
  echo "OmaJump's Super-tap integration is not installed."
  exit 0
fi

backup="$bindings.bak.omajump.$(date +%s)"
cp "$bindings" "$backup"
sed -i '/^-- OmaJump: begin$/,/^-- OmaJump: end$/d' "$bindings"

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null
fi

echo "Removed OmaJump's lone-Super launcher."
echo "Backup: $backup"
