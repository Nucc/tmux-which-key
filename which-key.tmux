#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key popup for tmux
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

main() {
    local trigger
    trigger=$(get_tmux_option "@which-key-trigger" "Space")

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
        config_flag="--config $config"
    fi

    # Build popup command
    local popup_cmd="tmux display-popup -E"
    popup_cmd+=" -h $popup_height -w $popup_width"
    popup_cmd+=" -x $popup_x -y $popup_y"
    popup_cmd+=" -S 'fg=$popup_fg' -s 'bg=$popup_bg'"
    popup_cmd+=" '$CURRENT_DIR/scripts/which-key.sh $config_flag #{pane_id}'"

    tmux bind-key "$trigger" run-shell "$popup_cmd"
}

main
