#!/bin/bash

#==============================================================================
# INTERACTIVE MENU SELECTOR
#==============================================================================
# An advanced terminal-based menu system with arrow key navigation, 
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
    
    # Use display options as return values if none provided
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    # Validate array lengths
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value arrays" >&2
        return 1
    fi
    
    local cur=0 count=${#display_options[@]} index=0
    local esc=$(echo -en "\e")
    
    if (( count == 0 )); then
        echo "Error: No options provided" >&2
        return 1
    fi
    
    # Terminal setup
    tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null; stty echo 2>/dev/null' EXIT INT TERM
    stty -echo 2>/dev/null
    printf "$prompt\n"
    
    # Main interactive loop
    while true; do
        # Render menu
        index=0
        for o in "${display_options[@]}"; do
            if [[ "$index" == "$cur" ]]; then
                echo -e " >\e[1;32m $o \e[0m"
            else
                echo "   $o"
            fi
            (( ++index ))
        done

        # Read single character from terminal
        if ! read -s -n1 -r key </dev/tty; then
            echo "Error: Could not read from terminal" >&2
            return 1
        fi

        # Handle arrow keys
        if [[ $key == $esc ]]; then
            if read -s -n2 -t 0.1 rest </dev/tty; then
                case "$rest" in
                    "[A") (( cur-- )); (( cur < 0 )) && (( cur = count - 1 )) ;;
                    "[B") (( cur++ )); (( cur >= count )) && (( cur = 0 )) ;;
                esac
            fi
            continue
        fi

        # Handle selection and exit
        if [[ $key == "" ]] || [[ $key == $'\n' ]] || [[ $key == $'\r' ]]; then
            break
        elif [[ $key == $'\003' ]] || [[ $key == "q" ]] || [[ $key == "Q" ]]; then
            tput cnorm 2>/dev/null
            stty echo 2>/dev/null
            trap - EXIT INT TERM
            echo -en "\e[${count}A"
            echo -e "\nSelection cancelled" >&2
            return 130
        fi

        # Move cursor back to top
        echo -en "\e[${count}A"
    done
    
    # Terminal cleanup
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    trap - EXIT INT TERM

    # Clear menu
    echo -en "\e[${count}A"
    for (( i=0; i<count; i++ )); do
        echo -e "\e[K"
    done
    echo -en "\e[${count}A"

    # Set output variable
    printf -v "$outvar" "${return_values[$cur]}"
    
    # Confirmation
    echo "Selected: ${display_options[$cur]} (value: ${return_values[$cur]})"
    return 0
}
