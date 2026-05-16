#!/usr/bin/env bash
# tmux-which-key - LazyVim-style which-key popup for tmux
# Usage: which-key.sh [--config <path>] [--pane <pane_id>] [--window <window_id>] [--session <session_id>] [--client <client_id>]

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE=""
PANE_ID=""
WINDOW_ID=""
SESSION_ID=""
CLIENT_ID=""
EXECUTE_ACTION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --pane)
            PANE_ID="$2"
            shift 2
            ;;
        --window)
            WINDOW_ID="$2"
            shift 2
            ;;
        --session)
            SESSION_ID="$2"
            shift 2
            ;;
        --client)
            CLIENT_ID="$2"
            shift 2
            ;;
        --execute)
            EXECUTE_ACTION="$2"
            shift 2
            ;;
        *)
            PANE_ID="$1"
            shift
            ;;
    esac
done

execute_kill_session() {
    local session_count

    if [[ -z "$SESSION_ID" ]]; then
        echo "Missing --session for kill-session"
        exit 1
    fi

    if ! tmux has-session -t "$SESSION_ID" 2>/dev/null; then
        exit 0
    fi

    session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
    if [[ -n "$CLIENT_ID" && "$session_count" -gt 1 ]]; then
        tmux switch-client -c "$CLIENT_ID" -n
        sleep 0.1
    fi

    tmux kill-session -t "$SESSION_ID"
}

if [[ -n "$EXECUTE_ACTION" ]]; then
    case "$EXECUTE_ACTION" in
        kill-session)
            execute_kill_session
            ;;
        *)
            echo "Unknown internal action: $EXECUTE_ACTION"
            exit 1
            ;;
    esac
    exit 0
fi

# Resolve config file: explicit > XDG > user home > plugin default
if [[ -z "$CONFIG_FILE" ]]; then
    local_xdg="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-which-key/config.json"
    local_home="$HOME/.tmux-which-key.json"
    if [[ -f "$local_xdg" ]]; then
        CONFIG_FILE="$local_xdg"
    elif [[ -f "$local_home" ]]; then
        CONFIG_FILE="$local_home"
    else
        CONFIG_FILE="$PLUGIN_DIR/configs/default.json"
    fi
fi

# Nord theme colors
C_KEY=$'\033[38;2;235;203;139m'       # #EBCB8B - yellow
C_GRP=$'\033[38;2;136;192;208m'       # #88C0D0 - cyan
C_DESC=$'\033[38;2;216;222;233m'      # #D8DEE9 - light gray
C_SEP=$'\033[38;2;76;86;106m'         # #4C566A - dark gray
C_HDR=$'\033[38;2;129;161;193m'       # #81A1C1 - blue
C_R=$'\033[0m'

if [[ -z "$PANE_ID" ]]; then
    echo "Usage: which-key.sh [--config <path>] [--pane <pane_id>] [--window <window_id>] [--session <session_id>] [--client <client_id>]"
    exit 1
fi

if [[ -z "$WINDOW_ID" ]]; then
    WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}')
fi

if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID=$(tmux display-message -t "$PANE_ID" -p '#{session_id}')
fi

if [[ -z "$CLIENT_ID" ]]; then
    CLIENT_ID=$(tmux display-message -p '#{client_name}')
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config not found: $CONFIG_FILE"
    exit 1
fi

# Read entire config into memory once
CONFIG=$(cat "$CONFIG_FILE")

# Navigation stack (jq path indices)
NAV_STACK=()

# Get current items as tab-separated lines: key\ttype\tdescription\tcommand\timmediate
# Single jq call per menu level instead of per-item
get_current_items() {
    local path=".items"
    for idx in "${NAV_STACK[@]}"; do
        path="${path}[${idx}].items"
    done
    echo "$CONFIG" | jq -r "${path}[] | [.key, .type, .description, (.command // \"\"), (if .immediate then \"true\" else \"false\" end)] | @tsv" 2>/dev/null
}

get_breadcrumb() {
    local path=".items"
    local parts=("root")
    for idx in "${NAV_STACK[@]}"; do
        parts+=("$(echo "$CONFIG" | jq -r "${path}[${idx}].description")")
        path="${path}[${idx}].items"
    done
    local IFS=" > "
    echo "${parts[*]}"
}

expand_command() {
    local command="$1"
    command="${command//\{\{pane_id\}\}/$PANE_ID}"
    command="${command//\{\{window_id\}\}/$WINDOW_ID}"
    command="${command//\{\{session_id\}\}/$SESSION_ID}"
    command="${command//\{\{client_id\}\}/$CLIENT_ID}"
    echo "$command"
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

write_tmux_command_file() {
    local command="$1"
    local command_file
    command="${command//\\;/;}"
    command_file=$(mktemp "${TMPDIR:-/tmp}/tmux-which-key.XXXXXX") || return 1
    printf '%s\n' "$command" > "$command_file"
    echo "$command_file"
}

run_tmux_command() {
    local command_file
    command_file=$(write_tmux_command_file "$1") || return 1
    tmux source-file "$command_file"
    rm -f "$command_file"
}

run_tmux_command_delayed() {
    local command_file quoted_file
    command_file=$(write_tmux_command_file "$1") || return 1
    quoted_file=$(shell_quote "$command_file")
    tmux run-shell -b "sleep 0.1; tmux source-file $quoted_file; rm -f $quoted_file"
}

run_internal_action() {
    local action="$1"
    local script_path quoted_script quoted_action quoted_client quoted_session
    script_path="$PLUGIN_DIR/scripts/which-key.sh"
    quoted_script=$(shell_quote "$script_path")
    quoted_action=$(shell_quote "$action")
    quoted_client=$(shell_quote "$CLIENT_ID")
    quoted_session=$(shell_quote "$SESSION_ID")

    case "$action" in
        kill-session)
            run_tmux_command_delayed "confirm-before -t $CLIENT_ID -p 'Kill session? (y/n)' 'run-shell -b \"$quoted_script --execute $quoted_action --client $quoted_client --session $quoted_session\"'"
            ;;
        *)
            tmux display-message -t "$PANE_ID" "Unknown internal action: $action"
            ;;
    esac
}

render_menu() {
    clear

    local breadcrumb
    breadcrumb=$(get_breadcrumb)

    # Header
    printf "%s  Which Key%s  %s│%s  %s%s%s\n" "$C_HDR" "$C_R" "$C_SEP" "$C_R" "$C_DESC" "$breadcrumb" "$C_R"
    printf "%s" "$C_SEP"
    printf '%.0s─' {1..98}
    printf "%s\n" "$C_R"

    # Parse all items in one jq call
    local keys=() types=() descs=()
    while IFS=$'\t' read -r key type desc _cmd; do
        keys+=("$key")
        types+=("$type")
        descs+=("$desc")
    done < <(get_current_items)

    local total=${#keys[@]}
    if [[ $total -eq 0 ]]; then
        printf "  %s(empty)%s\n" "$C_DESC" "$C_R"
        return
    fi

    # Column layout
    local col_width=32
    local num_cols=3
    local num_rows=$(( (total + num_cols - 1) / num_cols ))

    for ((row = 0; row < num_rows; row++)); do
        printf "  "
        for ((col = 0; col < num_cols; col++)); do
            local i=$((col * num_rows + row))
            if [[ $i -lt $total ]]; then
                local k="${keys[$i]}" t="${types[$i]}" d="${descs[$i]}"
                local prefix="" dc="$C_DESC"
                if [[ "$t" == "group" ]]; then
                    prefix="+"
                    dc="$C_GRP"
                fi
                local visible_len=$(( ${#k} + 4 + ${#prefix} + ${#d} ))
                local pad=$((col_width - visible_len))
                [[ $pad -lt 1 ]] && pad=1
                printf "%s%s%s  %s→%s %s%s%s%s" "$C_KEY" "$k" "$C_R" "$C_SEP" "$C_R" "$dc" "$prefix" "$d" "$C_R"
                printf '%*s' "$pad" ""
            fi
        done
        printf "\n"
    done

    # Footer
    printf "\n%s" "$C_SEP"
    printf '%.0s─' {1..98}
    printf "%s\n" "$C_R"
    if [[ ${#NAV_STACK[@]} -gt 0 ]]; then
        printf "  %sesc  close    ⌫  back%s\n" "$C_SEP" "$C_R"
    else
        printf "  %sesc  close%s\n" "$C_SEP" "$C_R"
    fi
}

handle_key() {
    local keypress="$1"
    local i=0

    while IFS=$'\t' read -r key type desc command immediate; do
        if [[ "$key" == "$keypress" ]]; then
            command=$(expand_command "$command")
            case "$type" in
                group)
                    NAV_STACK+=("$i")
                    return 0
                    ;;
                action)
                    tmux send-keys -t "$PANE_ID" -l "$command"
                    if [[ "$immediate" == "true" ]]; then
                        tmux send-keys -t "$PANE_ID" Enter
                    fi
                    exit 0
                    ;;
                popup)
                    local pane_path
                    local quoted_command
                    local quoted_pane_path
                    pane_path=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}')
                    quoted_command=$(shell_quote "$command")
                    quoted_pane_path=$(shell_quote "$pane_path")
                    tmux run-shell -b "sleep 0.1; tmux display-popup -E -h 80% -w 80% -d $quoted_pane_path $quoted_command"
                    exit 0
                    ;;
                tmux)
                    case "$command" in
                        choose-*|command-prompt*|confirm-before*|customize-mode*|copy-mode*|clock-mode*|display-panes*|*display-message*)
                            run_tmux_command_delayed "$command"
                            ;;
                        *)
                            run_tmux_command "$command"
                            ;;
                    esac
                    exit 0
                    ;;
                script)
                    tmux run-shell "$command"
                    exit 0
                    ;;
                internal)
                    run_internal_action "$command"
                    exit 0
                    ;;
            esac
        fi
        ((i++))
    done < <(get_current_items)
}

# Main loop
while true; do
    render_menu

    IFS= read -rsn1 keypress

    # Escape
    if [[ "$keypress" == $'\x1b' ]]; then
        read -rsn1 -t 0.1 seq1 || true
        if [[ -z "$seq1" ]]; then
            if [[ ${#NAV_STACK[@]} -gt 0 ]]; then
                unset 'NAV_STACK[${#NAV_STACK[@]}-1]'
            else
                exit 0
            fi
        fi
        continue
    fi

    # Backspace
    if [[ "$keypress" == $'\x7f' || "$keypress" == $'\x08' ]]; then
        if [[ ${#NAV_STACK[@]} -gt 0 ]]; then
            unset 'NAV_STACK[${#NAV_STACK[@]}-1]'
        else
            exit 0
        fi
        continue
    fi

    # Regular key
    if [[ -n "$keypress" ]]; then
        handle_key "$keypress"
    fi
done
