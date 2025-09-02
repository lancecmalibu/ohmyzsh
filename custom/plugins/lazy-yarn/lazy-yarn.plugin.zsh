# Lazy Yarn Plugin - Only load when needed

_lazy_load_yarn() {
  # Check if we're in a yarn project directory
  if [[ -f package.json || -f yarn.lock ]]; then
    # Load the real yarn plugin if not already loaded
    if ! (( ${+functions[yarn]} )) || [[ -z "${_comps[yarn]}" ]]; then
      source "$ZSH/plugins/yarn/yarn.plugin.zsh"
      echo "🧶 Yarn plugin loaded"
    fi
  fi
}

# Hook into directory changes
add-zsh-hook chpwd _lazy_load_yarn

# Check current directory on load
_lazy_load_yarn
