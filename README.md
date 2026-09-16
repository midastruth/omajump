# OmaJump

Jump to any visible window by typing its on-screen number.

OmaJump is a native Omarchy Shell overlay. Tap **Super** by itself and every window currently visible across your monitors gets a numbered badge. Type a badge number to focus that window.

## Features

- Fast, keyboard-first window switching
- Numbered hints positioned over visible windows
- Multi-monitor support
- Multi-digit hints when more than nine windows are visible
- Filters out off-screen clients used by scrolling layouts
- Theme-aware colors, typography, and spacing
- Mouse selection and Escape-to-cancel
- Preserves existing shortcuts such as `Super+1`

## Requirements

- Omarchy 4.x
- Omarchy Shell / Quickshell
- Hyprland with Lua configuration and `input.keyboard.key` events

## Install

Install and enable the plugin:

```bash
omarchy plugin add https://github.com/midastruth/omajump.git --enable
```

Then install the lone-Super integration:

```bash
~/.config/omarchy/plugins/io.github.midastruth.omajump/install-super-tap.sh
```

The helper creates a timestamped backup of `~/.config/hypr/bindings.lua`, adds a small loader for `super-tap.lua`, reloads Hyprland, and rolls back if validation fails.

## Usage

1. Tap and release **Super** without pressing another key.
2. Type the number shown on the window you want.
3. Press **Escape** or click the dimmed background to cancel.

With ten or more visible windows, a prefix can be ambiguous. Continue typing the multi-digit number, press **Enter** to accept the shorter exact match, or wait 500 ms.

You can summon OmaJump directly without the Super integration:

```bash
omarchy-shell shell summon io.github.midastruth.omajump '{}'
```

## Update

```bash
omarchy plugin update io.github.midastruth.omajump
```

## Uninstall

Remove the Hyprland loader before removing the plugin:

```bash
~/.config/omarchy/plugins/io.github.midastruth.omajump/uninstall-super-tap.sh
omarchy plugin remove io.github.midastruth.omajump
```

## How it works

`super-tap.lua` watches Hyprland's raw keyboard events. A Super press is considered a lone tap only if no other key is pressed before Super is released, so normal Super shortcuts are unaffected.

The overlay queries `hyprctl monitors -j` and `hyprctl clients -j`, keeps clients whose centers are currently on an active output, and uses Hyprland's Lua focus dispatcher to activate the chosen address.

## Development

Validate the plugin and QML:

```bash
omarchy plugin validate .

lint_root=$(mktemp -d)
ln -s /usr/share/omarchy/shell "$lint_root/qs"
/usr/lib/qt6/bin/qmllint -I "$lint_root" Overlay.qml
rm -rf "$lint_root"
```

Files under `~/.config/omarchy/plugins/` hot-reload. If needed:

```bash
omarchy restart shell
```

## License

MIT
