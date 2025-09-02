# Universal Configuration Loader
# Automatically loads all .zsh files from subdirectories in $ZSH_CUSTOM

# Debug timing function
_loader_timer() {
  [[ "$OMZ_DEBUG_TIMING" = "1" ]] && echo "$(($(gdate +%s%N)/1000000 - ${start_total:-0}))ms: $1"
}

_loader_timer "Starting custom config loader"

_fast_load_configs() {
  local config_files=(
    "$ZSH_CUSTOM/claude/exports.zsh"
    "$ZSH_CUSTOM/aws/awsprofile_env.zsh"
    "$ZSH_CUSTOM/aws/exports.zsh"
    "$ZSH_CUSTOM/aws/deploy.zsh"
    "$ZSH_CUSTOM/aws/ssm.zsh"
    "$ZSH_CUSTOM/python/pip.zsh"
    # Add more files as needed
  )
  
  _loader_timer "Starting fast config loading"
  for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
      _loader_timer "Loading ${config_file:t}"
      source "$config_file"
    fi
  done
  _loader_timer "Finished fast config loading"
}

# Choose loading method:
_fast_load_configs  
return  
# # Original dynamic loader (slower but flexible):
# _loader_timer "Starting dynamic config loading"

# # Set null glob option to handle empty matches gracefully
# setopt NULL_GLOB

# # Load all .zsh files from all subdirectories
# for config_dir in "$ZSH_CUSTOM"/*/; do
#   if [[ -d "$config_dir" ]]; then
#     _loader_timer "Scanning directory ${config_dir:t}"
#     for config_file in "$config_dir"*.zsh; do
#       if [[ -f "$config_file" ]]; then
#         _loader_timer "Loading ${config_file:t}"
#         source "$config_file"
#       fi
#     done
#   fi
# done

# # Unset null glob option to restore default behavior
# unsetopt NULL_GLOB

# _loader_timer "Finished custom config loader"