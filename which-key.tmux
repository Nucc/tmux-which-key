#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key menu for tmux
# Plugin entry point (sourced by TPM)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option")
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

main() {
    local trigger
    trigger=$(get_tmux_option "@which-key-trigger" "Space")
    if [[ "$trigger" == "None" ]]; then
        return
    fi

    local mode
    mode=$(get_tmux_option "@which-key-mode" "popup")

    local config
    config=$(get_tmux_option "@which-key-config" "")

    local popup_height
    popup_height=$(get_tmux_option "@which-key-popup-height" "16")

    local popup_width
    popup_width=$(get_tmux_option "@which-key-popup-width" "100")

    local popup_bg
    popup_bg=$(get_tmux_option "@which-key-popup-bg" "#2E3440")

    local popup_fg
    popup_fg=$(get_tmux_option "@which-key-popup-fg" "#4C566A")

    local popup_x
    popup_x=$(get_tmux_option "@which-key-popup-x" "C")

    local popup_y
    popup_y=$(get_tmux_option "@which-key-popup-y" "S")

    # Build config flag
    local config_flag=""
    if [[ -n "$config" ]]; then
        config_flag=" --config $(shell_quote "$config")"
    fi

    local script_cmd
    script_cmd="$(shell_quote "$CURRENT_DIR/scripts/which-key.sh")$config_flag"
    script_cmd+=" --pane #{pane_id} --window #{window_id} --session #{session_id} --client #{client_name}"

    local bind_cmd
    if [[ "$mode" == "native" ]]; then
        bind_cmd="$(shell_quote "$CURRENT_DIR/scripts/which-key.sh") --menu$config_flag"
        bind_cmd+=" --pane #{pane_id} --window #{window_id} --session #{session_id} --client #{client_name}"
    else
        bind_cmd="tmux display-popup -E"
        bind_cmd+=" -h $popup_height -w $popup_width"
        bind_cmd+=" -x $popup_x -y $popup_y"
        bind_cmd+=" -S $(shell_quote "fg=$popup_fg") -s $(shell_quote "bg=$popup_bg")"
        bind_cmd+=" $(shell_quote "$script_cmd")"
        bind_cmd="{ $bind_cmd; rc=\$?; [ \$rc -eq 129 ] || exit \$rc; }"
    fi

    tmux bind-key "$trigger" run-shell "$bind_cmd"
}

main
