# Fixed version
alias() {
    if [[ $# -eq 0 ]]; then
        # No arguments, show all aliases
        builtin alias
    elif [[ $# -eq 1 ]] && [[ "$1" != *=* ]]; then
        # One argument without '=', filter aliases
        builtin alias | /usr/bin/grep -i "$1" | sort
    else
        # Setting an alias or multiple arguments
        builtin alias "$@"
    fi
}