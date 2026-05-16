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

    local config
    config=$(get_tmux_option "@which-key-config" "")

    # Build config flag
    local config_flag=""
    if [[ -n "$config" ]]; then
        config_flag=" --config $(shell_quote "$config")"
    fi

    # Build native menu command
    local menu_cmd
    menu_cmd="$(shell_quote "$CURRENT_DIR/scripts/which-key.sh") --menu$config_flag"
    menu_cmd+=" --pane #{pane_id} --window #{window_id} --session #{session_id} --client #{client_name}"

    tmux bind-key "$trigger" run-shell "$menu_cmd"
}

main
