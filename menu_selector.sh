#!/bin/bash

#==============================================================================
# INTERACTIVE MENU SELECTOR - macOS Compatible Version
#==============================================================================
# An advanced terminal-based menu system with arrow key navigation, 
# customizable display text, and separate return values.
# Fixed for macOS compatibility issues.
#
# Author: blue-Samarth
# Version: 1.1 - macOS Compatible
# License: MIT
#==============================================================================

#------------------------------------------------------------------------------
# Function: menu_selector
#------------------------------------------------------------------------------
# Creates an interactive menu with arrow key navigation and customizable 
# display/return value pairs.
#
# USAGE:
#   menu_selector "prompt" variable_name display_options... [-- return_values...]
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
#------------------------------------------------------------------------------
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
    
    # If no return values specified, use display options as return values
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi
    
    # Validate array lengths match
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value arrays" >&2
        return 1
    fi
    
    # Initialize navigation variables
    local cur=0 count=${#display_options[@]} index=0
    
    # Ensure we have at least one option
    if (( count == 0 )); then
        echo "Error: No options provided" >&2
        return 1
    fi
    
    # Check if terminal supports colors
    local use_colors=false
    if command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
        if (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
            use_colors=true
        fi
    fi
    
    # Color definitions - use tput for better compatibility
    local color_green color_reset cursor_up cursor_clear_line
    if $use_colors; then
        color_green=$(tput setaf 2 2>/dev/null)$(tput bold 2>/dev/null)
        color_reset=$(tput sgr0 2>/dev/null)
        cursor_up=$(tput cuu1 2>/dev/null)
        cursor_clear_line=$(tput el 2>/dev/null)
    else
        color_green=""
        color_reset=""
        cursor_up=""
        cursor_clear_line=""
    fi
    
    # Terminal setup: hide cursor and disable echo
    local cursor_hidden=false echo_disabled=false
    if tput civis >/dev/null 2>&1; then
        tput civis
        cursor_hidden=true
    fi
    
    # Set up cleanup trap
    trap 'cleanup_terminal' EXIT INT TERM
    
    cleanup_terminal() {
        if $cursor_hidden && command -v tput >/dev/null 2>&1; then
            tput cnorm 2>/dev/null
        fi
        if $echo_disabled; then
            stty echo 2>/dev/null
        fi
        trap - EXIT INT TERM
    }
    
    if stty -echo 2>/dev/null; then
        echo_disabled=true
    fi
    
    printf "%s\n" "$prompt"
    
    # Main interactive loop
    while true; do
        # Render menu
        index=0 
        for o in "${display_options[@]}"; do
            if [[ "$index" == "$cur" ]]; then
                printf " >%s %s %s\n" "$color_green" "$o" "$color_reset"
            else 
                printf "   %s\n" "$o"
            fi
            (( ++index ))
        done
        
        # Read single character
        local key
        if ! read -rsn1 key 2>/dev/null; then
            # Fallback for systems where read -n1 doesn't work
            key=$(dd bs=1 count=1 2>/dev/null)
        fi
        
        # Handle escape sequences (arrow keys)
        if [[ $key == $'\033' ]]; then
            # Read the bracket
            local bracket
            if ! read -rsn1 -t 0.1 bracket 2>/dev/null; then
                continue
            fi
            if [[ $bracket == "[" ]]; then
                # Read the direction
                local direction
                if ! read -rsn1 -t 0.1 direction 2>/dev/null; then
                    continue
                fi
                case "$direction" in
                    "A") # Up arrow
                        (( cur-- ))
                        (( cur < 0 )) && (( cur = count - 1 ))
                        ;;
                    "B") # Down arrow
                        (( cur++ ))
                        (( cur >= count )) && (( cur = 0 ))
                        ;;
                esac
            fi
        # Handle selection and exit keys
        elif [[ $key == "" ]] || [[ $key == $'\n' ]] || [[ $key == $'\r' ]]; then
            # Enter key: make selection
            break
        elif [[ $key == $'\003' ]] || [[ $key == "q" ]] || [[ $key == "Q" ]]; then
            # Ctrl+C, q, or Q: cancel operation
            cleanup_terminal
            
            # Clear menu
            if [[ -n "$cursor_up" ]]; then
                for (( i=0; i<count; i++ )); do
                    printf "%s" "$cursor_up"
                done
            fi
            
            echo "Selection cancelled" >&2
            return 130
        fi
        
        # Move cursor back to top of menu
        if [[ -n "$cursor_up" ]]; then
            for (( i=0; i<count; i++ )); do
                printf "%s" "$cursor_up"
            done
        fi
    done
    
    # Clean up terminal
    cleanup_terminal
    
    # Clear the menu from screen
    if [[ -n "$cursor_up" && -n "$cursor_clear_line" ]]; then
        for (( i=0; i<count; i++ )); do
            printf "%s" "$cursor_up"
        done
        for (( i=0; i<count; i++ )); do
            printf "%s\n" "$cursor_clear_line"
        done
        for (( i=0; i<count; i++ )); do
            printf "%s" "$cursor_up"
        done
    fi
    
    # Set the output variable to the selected return value
    printf -v "$outvar" "%s" "${return_values[$cur]}"
    
    # Display confirmation of selection
    printf "Selected: %s (value: %s)\n" "${display_options[$cur]}" "${return_values[$cur]}"
    
    return 0
}
