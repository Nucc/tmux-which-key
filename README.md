# tmux-which-key

A LazyVim-style which-key popup for tmux. Press a trigger key to open a discoverable, keyboard-driven command menu with nested groups, breadcrumb navigation, and Nord-themed colors.

![Nord theme](https://img.shields.io/badge/theme-Nord-88C0D0?style=flat-square)
![tmux](https://img.shields.io/badge/tmux-3.3+-green?style=flat-square)

![tmux-which-key screenshot](https://gist.githubusercontent.com/Nucc/2eb50f2a324d8e79a8f231b16cdb3b4f/raw/screenshot.png)

## Features

- **Discoverable keybindings** - see all available commands at a glance
- **Nested groups** - organize commands hierarchically (git, window, session, etc.)
- **Breadcrumb navigation** - always know where you are in the menu tree
- **Nord color theme** - clean, readable color scheme using 24-bit true color
- **JSON configuration** - easy to customize, extend, and share
- **Four action types** - shell commands, tmux commands, external scripts, and nested groups
- **Single-keystroke input** - no Enter key required, instant response

## Requirements

- tmux >= 3.3 (for `display-popup` support)
- `jq` (for JSON parsing)
- A terminal with true color (24-bit) support

## Installation

### With [TPM](https://github.com/tmux-plugins/tpm) (recommended)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'Nucc/tmux-which-key'
```

Then press `prefix + I` to install.

### Manual

Clone the repository:

```bash
git clone https://github.com/Nucc/tmux-which-key.git ~/.tmux/plugins/tmux-which-key
```

Add to your `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-which-key/which-key.tmux
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Usage

Press `prefix + Space` (default) to open the which-key popup.

- **Press a key** to execute the corresponding command or enter a group
- **Escape** to go back one level or close the menu
- **Backspace** to go back one level or close the menu

Groups are indicated by a `+` prefix and shown in cyan. Pressing a group key opens its submenu with a breadcrumb showing your navigation path.

## Configuration

### Tmux Options

Set these in your `~/.tmux.conf` before loading the plugin:

| Option | Default | Description |
|--------|---------|-------------|
| `@which-key-trigger` | `Space` | Key binding (after prefix) to open the menu |
| `@which-key-config` | _(auto-detected)_ | Path to a custom JSON config file |
| `@which-key-popup-height` | `16` | Popup height in lines |
| `@which-key-popup-width` | `100` | Popup width in characters |
| `@which-key-popup-bg` | `#2E3440` | Popup background color |
| `@which-key-popup-fg` | `#4C566A` | Popup border/foreground color |
| `@which-key-popup-x` | `C` | Popup X position (`C` = centered) |
| `@which-key-popup-y` | `S` | Popup Y position (`S` = status line) |

Example:

```tmux
set -g @which-key-config '~/.config/tmux-which-key/config.json'
set -g @which-key-popup-height '20'
set -g @which-key-popup-width '120'
set -g @plugin 'Nucc/tmux-which-key'
```

### Custom Key Binding

By default the plugin binds `prefix + Space`. You can override this with `@which-key-trigger`, or create your own binding entirely in `~/.tmux.conf`.

To bind `Ctrl-Space` directly (no prefix needed):

```tmux
# Disable the default prefix binding
set -g @which-key-trigger 'None'

# Bind Ctrl-Space directly (-n = no prefix)
bind-key -n C-Space run-shell 'tmux display-popup -E -h 16 -w 100 -x C -y S -S "fg=#4C566A" -s "bg=#2E3440" "~/.tmux/plugins/tmux-which-key/scripts/which-key.sh #{pane_id}"'
```

To use a custom config with a manual binding:

```tmux
bind-key -n C-Space run-shell 'tmux display-popup -E -h 16 -w 100 -x C -y S -S "fg=#4C566A" -s "bg=#2E3440" "~/.tmux/plugins/tmux-which-key/scripts/which-key.sh --config ~/.config/tmux-which-key/config.json #{pane_id}"'
```

### Custom Config File

The plugin looks for a config file in this order:

1. Path set via `@which-key-config` tmux option
2. `$XDG_CONFIG_HOME/tmux-which-key/config.json` (usually `~/.config/tmux-which-key/config.json`)
3. `~/.tmux-which-key.json`
4. Plugin's built-in `configs/default.json`

To create your own config:

```bash
mkdir -p ~/.config/tmux-which-key
cp ~/.tmux/plugins/tmux-which-key/configs/default.json ~/.config/tmux-which-key/config.json
```

Then edit `~/.config/tmux-which-key/config.json` to your liking.

### Config File Format

The config file is a JSON object with a top-level `items` array. Each item has:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | yes | Single character that triggers this item |
| `type` | string | yes | One of: `group`, `action`, `tmux`, `script` |
| `description` | string | yes | Label shown in the menu |
| `command` | string | for non-groups | Command to execute |
| `items` | array | for groups | Nested items in this group |

### Action Types

| Type | Behavior | Example |
|------|----------|---------|
| `group` | Opens a submenu with nested items | Navigate to git commands |
| `action` | Sends text to the active pane (as if typed) | `git status` |
| `tmux` | Executes a tmux command directly | `split-window -h` |
| `script` | Runs a shell script via `tmux run-shell` | `~/scripts/my-script.sh` |

### Example Config

```json
{
  "items": [
    {
      "key": "g",
      "type": "group",
      "description": "git",
      "items": [
        { "key": "s", "type": "action", "command": "git status", "description": "Status" },
        { "key": "p", "type": "action", "command": "git push", "description": "Push" },
        { "key": "l", "type": "action", "command": "git log --oneline -20", "description": "Log" }
      ]
    },
    {
      "key": "w",
      "type": "group",
      "description": "window",
      "items": [
        { "key": "v", "type": "tmux", "command": "split-window -h -c '#{pane_current_path}'", "description": "Split vertical" },
        { "key": "s", "type": "tmux", "command": "split-window -v -c '#{pane_current_path}'", "description": "Split horizontal" }
      ]
    },
    { "key": "r", "type": "tmux", "command": "source-file ~/.tmux.conf \\; display-message 'Config reloaded'", "description": "Reload config" },
    { "key": "e", "type": "action", "command": "nvim .", "description": "Open editor" },
    { "key": "d", "type": "script", "command": "~/scripts/deploy.sh", "description": "Deploy" }
  ]
}
```

## Default Keybindings

The built-in default config includes:

| Key | Type | Description |
|-----|------|-------------|
| `g` | group | **Git** - status, diff, log, push, pull, branches, fetch, add, commit, rebase |
| `w` | group | **Window** - split, zoom, new, close, pane navigation (hjkl) |
| `s` | group | **Session** - new, detach, choose, rename, kill |
| `b` | group | **Buffer** - list, paste, choose |
| `:` | tmux | Command prompt |
| `r` | tmux | Reload tmux config |
| `?` | tmux | List all keybindings |
| `c` | action | Clear screen |

## License

MIT
