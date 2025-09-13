#!/bin/bash
#==============================================================================
# INTERACTIVE MENU SELECTOR
#==============================================================================
# Terminal-based menu system with arrow key navigation, 
# customizable display text, and separate return values.
#
# Author: blue-Samarth
# Version: 1.1
# License: MIT
#==============================================================================

function menu_selector() {
    local -r prompt="$1" outvar="$2"
    local -a display_options=() return_values=()
    local parsing_display=true

    # Parse arguments: display options, then "--", then return values
    local i=3
    while (( i <= $# )); do
        if [[ "${!i}" == "--" ]]; then
            parsing_display=false
            (( i++ ))
            continue
        fi

        if $parsing_display; then
            display_options+=("${!i}")
        else
            return_values+=("${!i}")
        fi
        (( i++ ))
    done

    # If no return values specified, use display options
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi

    # Validate arrays
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value arrays" >&2
        return 1
    fi

    local cur=0 count=${#display_options[@]}
    local esc=$(echo -en "\e") # ESC character

    if (( count == 0 )); then
        echo "Error: No options provided" >&2
        return 1
    fi

    # Terminal setup
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null; stty echo 2>/dev/null' EXIT INT TERM
    stty -echo 2>/dev/null

    printf "$prompt\n"

    # Main loop
    while true; do
        # Clear previous menu lines if any
        for ((i=0; i<count; i++)); do
            echo -en "\e[1A\e[K"
        done

        # Render menu
        for i in "${!display_options[@]}"; do
            if [[ $i -eq $cur ]]; then
                echo -e " >\e[1;32m ${display_options[$i]} \e[0m"
            else
                echo "   ${display_options[$i]}"
            fi
        done

        # Read single character
        read -s -n1 key

        # Handle arrow keys
        if [[ $key == $esc ]]; then
            read -s -n2 -t 0.1 key 2>/dev/null || key=""
            case "$key" in
                "[A") ((cur--)); ((cur < 0)) && ((cur = count - 1)) ;;
                "[B") ((cur++)); ((cur >= count)) && ((cur = 0)) ;;
                *) ;; # ignore other escape sequences
            esac
        elif [[ -z $key ]] || [[ $key == $'\n' ]] || [[ $key == $'\r' ]]; then
            break
        elif [[ $key == $'\003' ]] || [[ $key == "q" ]] || [[ $key == "Q" ]]; then
            tput cnorm
            stty echo
            trap - EXIT INT TERM
            echo -e "\nSelection cancelled" >&2
            return 130
        fi
    done

    # Cleanup
    tput cnorm
    stty echo
    trap - EXIT INT TERM

    # Clear menu from screen
    for ((i=0; i<count; i++)); do
        echo -en "\e[1A\e[K"
    done

    # Set output variable
    printf -v "$outvar" "${return_values[$cur]}"

    # Display confirmation
    echo "Selected: ${display_options[$cur]} (value: ${return_values[$cur]})"
    return 0
}
