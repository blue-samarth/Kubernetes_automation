#!/bin/bash
#==============================================================================
# INTERACTIVE MENU SELECTOR
#==============================================================================
# Terminal-based menu system with arrow key navigation, 
# customizable display text, and separate return values.
#
# Author: blue-Samarth
# Version: 1.0
# License: MIT
#==============================================================================

#------------------------------------------------------------------------------
# Function: menu_selector
#------------------------------------------------------------------------------
# Creates an interactive menu with arrow key navigation and customizable 
# display/return value pairs.
#
# USAGE:
#   choose_from_menu_advanced "prompt" variable_name display_options... [-- return_values...]
#
# PARAMETERS:
#   $1 (prompt)       - Text to display above the menu
#   $2 (outvar)       - Variable name to store the selected return value
#   $3+ (display)     - Array of options to display to the user
#   -- (separator)    - Optional separator between display and return arrays
#   $n+ (returns)     - Optional array of values to return (if omitted, uses display values)
#
# NAVIGATION:
#   ↑/↓ Arrow Keys   - Navigate menu items
#   Enter            - Select current item
#   q/Q/Ctrl+C       - Cancel and exit
#
# RETURN VALUES:
#   0                - Success (item selected)
#   1                - Error (invalid parameters)
#   130              - User cancelled (Ctrl+C/q)
#
# EXAMPLES:
#   # Simple menu (display = return values)
#   choose_from_menu_advanced "Select option:" choice "Option 1" "Option 2" "Option 3"
#
#   # Advanced menu (separate display/return)
#   display=("🍎 Fresh Apple" "🍌 Ripe Banana" "🚪 Exit")
#   values=("apple" "banana" "exit")
#   choose_from_menu_advanced "Pick fruit:" result "${display[@]}" -- "${values[@]}"
#------------------------------------------------------------------------------
function menu_selector() {
    local -r prompt="$1" outvar="$2"
    local -a display_options=() return_values=()
    local parsing_display=true

    # Parse arguments: display options, then "--", then return values
    # This allows flexible parameter passing for both display text and return values
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
    
    # If no return values specified, use display options as return values
    # This provides a simpler interface when display text = return values
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    # Validate array lengths match to prevent index out of bounds errors
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value arrays" >&2
        return 1
    fi
    
    # Initialize navigation variables
    local cur=0 count=${#display_options[@]} index=0
    local esc=$(echo -en "\e")  # ESC character for detecting arrow keys
    
    # Ensure we have at least one option
    if (( count == 0 )); then
        echo "Error: No options provided" >&2
        return 1
    fi

    
    # Terminal setup: hide cursor and disable echo
    # This creates a clean interactive experience
    tput civis 2>/dev/null          # Hide cursor
    trap 'tput cnorm 2>/dev/null; stty echo 2>/dev/null' EXIT INT TERM  # Cleanup on exit
    stty -echo 2>/dev/null          # Disable terminal echo
    
    printf "$prompt\n"

    # Main loop
    while true; do
        # Clear previous menu lines if any
        for ((i=0; i<count; i++)); do
            echo -en "\e[1A\e[K"
        done

        # Render menu
        index=0 
        for o in "${display_options[@]}"; do
            if [[ "$index" == "$cur" ]]; then
                echo -e " >\e[1;32m $o \e[0m"
            else 
                echo "   $o"
            fi
        done
        # Read single character

        read -s -n1 key

        if [[ $key == $esc ]]; then
            # Try to read the rest of the escape sequence (2 more chars)
            if read -s -n2 -t 0.1 rest 2>/dev/null; then
                case "$rest" in
                    "[A") # Up arrow
                        (( cur-- ))
                        (( cur < 0 )) && (( cur = count - 1 ))
                        ;;
                    "[B") # Down arrow
                        (( cur++ ))
                        (( cur >= count )) && (( cur = 0 ))
                        ;;
                    *) ;;  # Ignore other escape sequences
                esac
            else
                # ESC pressed alone, just ignore/redraw instead of exiting
                continue
            fi
        elif [[ -z $key ]] || [[ $key == $'\n' ]] || [[ $key == $'\r' ]]; then
            break   # Enter
        elif [[ $key == $'\003' ]] || [[ $key == "q" ]] || [[ $key == "Q" ]]; then
            tput cnorm
            stty echo
            trap - EXIT INT TERM
            echo -e "\nSelection cancelled" >&2
            return 130
        fi

        # Reset cursor for re-render
        echo -en "\e[${count}A"
    done

    
    # Terminal cleanup: restore cursor and echo
    tput cnorm 2>/dev/null   # Show cursor
    stty echo 2>/dev/null    # Re-enable echo
    trap - EXIT INT TERM     # Remove trap handlers
    
    # Clear the menu from screen
    echo -en "\e[${count}A"           # Move cursor to top of menu
    for (( i=0; i<count; i++ )); do
        echo -e "\e[K"                # Clear each line
    done
    echo -en "\e[${count}A"           # Move cursor back to top
    
    # Set the output variable to the selected return value
    printf -v "$outvar" "${return_values[$cur]}"
    
    # Display confirmation of selection
    echo "Selected: ${display_options[$cur]} (value: ${return_values[$cur]})"
    
    return 0  # Success
}
