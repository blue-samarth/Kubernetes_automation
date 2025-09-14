#!/bin/bash

#==============================================================================
# UNIVERSAL MENU SELECTOR - Cross-Platform Compatible
#==============================================================================
# Automatically detects terminal capabilities and chooses the best approach
# Works on: macOS Terminal, iTerm2, WSL, Linux terminals, Git Bash, etc.
#
# Author: blue-Samarth
# Version: 3.0 - Universal Compatibility
# License: MIT
#==============================================================================

#------------------------------------------------------------------------------
# Environment Detection Functions
#------------------------------------------------------------------------------

detect_terminal_capabilities() {
    local capabilities=""
    
    # Check if we're in a supported terminal environment
    if [[ -t 1 ]]; then
        capabilities+="interactive "
    fi
    
    # Check ANSI support
    if [[ $TERM == *"color"* ]] || [[ $TERM == "xterm"* ]] || [[ $TERM == "screen"* ]]; then
        capabilities+="ansi "
    fi
    
    # Check tput availability and color support
    if command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
        if (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
            capabilities+="tput_colors "
        fi
        if tput cup 0 0 >/dev/null 2>&1; then
            capabilities+="cursor_movement "
        fi
    fi
    
    # Check read capabilities
    if echo | read -rsn1 -t 0.1 >/dev/null 2>&1; then
        capabilities+="read_timeout "
    fi
    
    # Platform detection
    case "$(uname -s)" in
        Darwin) capabilities+="macos " ;;
        Linux) 
            if grep -qi microsoft /proc/version 2>/dev/null; then
                capabilities+="wsl "
            else
                capabilities+="linux "
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) capabilities+="windows_bash " ;;
    esac
    
    # Terminal app detection
    if [[ $TERM_PROGRAM == "Apple_Terminal" ]]; then
        capabilities+="apple_terminal "
    elif [[ $TERM_PROGRAM == "iTerm.app" ]]; then
        capabilities+="iterm2 "
    elif [[ $TERM == "screen"* ]] && [[ -n $TMUX ]]; then
        capabilities+="tmux "
    fi
    
    echo "$capabilities"
}

#------------------------------------------------------------------------------
# Color and Formatting Setup
#------------------------------------------------------------------------------

setup_colors() {
    local capabilities="$1"
    
    # Reset all colors first
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
    BOLD="" UNDERLINE="" REVERSE="" RESET="" NC=""
    
    # Try tput first (most reliable)
    if [[ $capabilities == *"tput_colors"* ]]; then
        RED=$(tput setaf 1 2>/dev/null)
        GREEN=$(tput setaf 2 2>/dev/null)
        YELLOW=$(tput setaf 3 2>/dev/null)
        BLUE=$(tput setaf 4 2>/dev/null)
        MAGENTA=$(tput setaf 5 2>/dev/null)
        CYAN=$(tput setaf 6 2>/dev/null)
        WHITE=$(tput setaf 7 2>/dev/null)
        BOLD=$(tput bold 2>/dev/null)
        UNDERLINE=$(tput smul 2>/dev/null)
        REVERSE=$(tput rev 2>/dev/null)
        RESET=$(tput sgr0 2>/dev/null)
        NC=$RESET
        return 0
    fi
    
    # Fallback to ANSI codes for compatible terminals
    if [[ $capabilities == *"ansi"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[0;37m'
        BOLD='\033[1m'
        UNDERLINE='\033[4m'
        REVERSE='\033[7m'
        RESET='\033[0m'
        NC=$RESET
        return 0
    fi
    
    # No colors available
    return 1
}

#------------------------------------------------------------------------------
# Cursor Movement Functions
#------------------------------------------------------------------------------

cursor_up() {
    local lines=${1:-1}
    local capabilities="$2"
    
    if [[ $capabilities == *"cursor_movement"* ]]; then
        tput cuu "$lines" 2>/dev/null
    elif [[ $capabilities == *"ansi"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        printf '\033[%dA' "$lines"
    fi
}

cursor_clear_line() {
    local capabilities="$1"
    
    if [[ $capabilities == *"cursor_movement"* ]]; then
        tput el 2>/dev/null
    elif [[ $capabilities == *"ansi"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        printf '\033[K'
    fi
}

hide_cursor() {
    local capabilities="$1"
    
    if [[ $capabilities == *"cursor_movement"* ]]; then
        tput civis 2>/dev/null
    elif [[ $capabilities == *"ansi"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        printf '\033[?25l'
    fi
}

show_cursor() {
    local capabilities="$1"
    
    if [[ $capabilities == *"cursor_movement"* ]]; then
        tput cnorm 2>/dev/null
    elif [[ $capabilities == *"ansi"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        printf '\033[?25h'
    fi
}

#------------------------------------------------------------------------------
# Advanced Menu (for capable terminals)
#------------------------------------------------------------------------------

advanced_menu_selector() {
    local prompt="$1" outvar="$2" capabilities="$3"
    shift 3
    
    local -a display_options=() return_values=()
    local parsing_display=true
    
    # Parse arguments
    while (( $# > 0 )); do
        if [[ "$1" == "--" ]]; then
            parsing_display=false
            shift
            continue
        fi
        
        if $parsing_display; then
            display_options+=("$1")
        else
            return_values+=("$1")
        fi
        shift
    done
    
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    local cur=0 count=${#display_options[@]}
    local esc=$'\033'
    
    hide_cursor "$capabilities"
    trap 'show_cursor "$capabilities"; stty echo 2>/dev/null' EXIT INT TERM
    stty -echo 2>/dev/null
    
    printf "%s\n" "$prompt"
    
    while true; do
        # Render menu
        for (( i=0; i<count; i++ )); do
            if (( i == cur )); then
                printf " >%s %s %s\n" "$GREEN$BOLD" "${display_options[i]}" "$RESET"
            else
                printf "   %s\n" "${display_options[i]}"
            fi
        done
        
        # Read key
        read -rsn1 key 2>/dev/null
        
        # Handle escape sequences
        if [[ $key == "$esc" ]]; then
            read -rsn2 -t 0.1 key 2>/dev/null
            case $key in
                '[A') (( cur-- )); (( cur < 0 )) && cur=$((count - 1)) ;;
                '[B') (( cur++ )); (( cur >= count )) && cur=0 ;;
            esac
        elif [[ $key == '' ]] || [[ $key == $'\n' ]] || [[ $key == $'\r' ]]; then
            break
        elif [[ $key == $'\003' ]] || [[ $key == 'q' ]] || [[ $key == 'Q' ]]; then
            show_cursor "$capabilities"
            stty echo 2>/dev/null
            trap - EXIT INT TERM
            echo "Selection cancelled" >&2
            return 130
        fi
        
        # Move cursor back up
        cursor_up "$count" "$capabilities"
    done
    
    # Cleanup
    show_cursor "$capabilities"
    stty echo 2>/dev/null
    trap - EXIT INT TERM
    
    # Clear menu
    cursor_up "$count" "$capabilities"
    for (( i=0; i<count; i++ )); do
        cursor_clear_line "$capabilities"
        printf "\n"
    done
    cursor_up "$count" "$capabilities"
    
    printf -v "$outvar" "%s" "${return_values[$cur]}"
    printf "Selected: %s\n" "${display_options[$cur]}"
    return 0
}

#------------------------------------------------------------------------------
# Simple Menu (for basic terminals)
#------------------------------------------------------------------------------

simple_menu_selector() {
    local prompt="$1" outvar="$2"
    shift 2
    
    local -a display_options=() return_values=()
    local parsing_display=true
    
    # Parse arguments
    while (( $# > 0 )); do
        if [[ "$1" == "--" ]]; then
            parsing_display=false
            shift
            continue
        fi
        
        if $parsing_display; then
            display_options+=("$1")
        else
            return_values+=("$1")
        fi
        shift
    done
    
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    local cur=0 count=${#display_options[@]}
    
    while true; do
        clear
        printf "%s\n\n" "$prompt"
        
        for (( i=0; i<count; i++ )); do
            if (( i == cur )); then
                printf " >> %s <<\n" "${display_options[i]}"
            else
                printf "    %s\n" "${display_options[i]}"
            fi
        done
        
        printf "\nUse w/s or arrow keys to move, Enter to select, q to quit\n"
        
        read -rsn1 key 2>/dev/null
        
        case $key in
            $'\033') # Arrow keys
                read -rsn2 -t 0.1 key 2>/dev/null
                case $key in
                    '[A') (( cur-- )); (( cur < 0 )) && cur=$((count - 1)) ;;
                    '[B') (( cur++ )); (( cur >= count )) && cur=0 ;;
                esac
                ;;
            w|W) (( cur-- )); (( cur < 0 )) && cur=$((count - 1)) ;;
            s|S) (( cur++ )); (( cur >= count )) && cur=0 ;;
            ''|$'\n'|$'\r') break ;;
            q|Q|$'\003')
                clear
                echo "Selection cancelled"
                return 130
                ;;
        esac
    done
    
    clear
    printf -v "$outvar" "%s" "${return_values[$cur]}"
    printf "Selected: %s\n" "${display_options[$cur]}"
    return 0
}

#------------------------------------------------------------------------------
# Numbered Menu (most compatible)
#------------------------------------------------------------------------------

numbered_menu_selector() {
    local prompt="$1" outvar="$2"
    shift 2
    
    local -a display_options=() return_values=()
    local parsing_display=true
    
    # Parse arguments
    while (( $# > 0 )); do
        if [[ "$1" == "--" ]]; then
            parsing_display=false
            shift
            continue
        fi
        
        if $parsing_display; then
            display_options+=("$1")
        else
            return_values+=("$1")
        fi
        shift
    done
    
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    local count=${#display_options[@]}
    
    printf "%s\n\n" "$prompt"
    for (( i=0; i<count; i++ )); do
        printf "%d. %s\n" "$((i + 1))" "${display_options[i]}"
    done
    printf "\n"
    
    while true; do
        printf "Enter choice (1-%d) or q to quit: " "$count"
        read -r choice
        
        case $choice in
            q|Q)
                echo "Selection cancelled"
                return 130
                ;;
            ''|*[!0-9]*)
                printf "Invalid input. Please enter a number between 1 and %d.\n" "$count"
                continue
                ;;
            *)
                if (( choice >= 1 && choice <= count )); then
                    local selected_index=$((choice - 1))
                    printf -v "$outvar" "%s" "${return_values[$selected_index]}"
                    printf "Selected: %s\n" "${display_options[$selected_index]}"
                    return 0
                else
                    printf "Invalid choice. Please enter a number between 1 and %d.\n" "$count"
                fi
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Main Universal Menu Function
#------------------------------------------------------------------------------

menu_selector() {
    # Detect capabilities once
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    
    # Setup colors based on capabilities
    setup_colors "$capabilities"
    
    # Choose the best menu implementation based on terminal capabilities
    if [[ $capabilities == *"cursor_movement"* ]] && [[ $capabilities == *"read_timeout"* ]] && [[ $capabilities != *"apple_terminal"* ]]; then
        # Full-featured menu for capable terminals (WSL, Linux, iTerm2)
        advanced_menu_selector "$@" "$capabilities"
    elif [[ $capabilities == *"interactive"* ]] && command -v clear >/dev/null 2>&1; then
        # Simple menu with screen clearing (macOS Terminal, basic terminals)
        simple_menu_selector "$@"
    else
        # Fallback to numbered menu (most compatible)
        numbered_menu_selector "$@"
    fi
}

#------------------------------------------------------------------------------
# Print Functions (color-aware)
#------------------------------------------------------------------------------

print_header() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s==========================================\n" "$BOLD" "$CYAN"
    printf "      %s       \n" "$1"
    printf "==========================================%s\n" "$RESET"
}

print_info() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s[INFO]%s %s\n" "$BOLD" "$BLUE" "$RESET" "$1"
}

print_success() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s[SUCCESS]%s %s\n" "$BOLD" "$GREEN" "$RESET" "$1"
}

print_warning() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s[WARNING]%s %s\n" "$BOLD" "$YELLOW" "$RESET" "$1"
}

print_error() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s[ERROR]%s %s\n" "$BOLD" "$RED" "$RESET" "$1"
}

print_guide() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s%s%s\n" "$BOLD" "$BLUE" "$1" "$RESET"
}

print_prompt() {
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    setup_colors "$capabilities"
    
    printf "%s%s%s%s\n" "$BOLD" "$CYAN" "$1" "$RESET"
}

#------------------------------------------------------------------------------
# Test Function
#------------------------------------------------------------------------------

test_universal_menu() {
    echo "=== Universal Menu Selector Test ==="
    echo
    
    local capabilities
    capabilities=$(detect_terminal_capabilities)
    echo "Detected capabilities: $capabilities"
    echo
    
    local result
    
