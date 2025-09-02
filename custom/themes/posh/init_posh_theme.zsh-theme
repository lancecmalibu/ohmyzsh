# Oh My Posh initialization - Auto-detect first theme (glob)
if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
  # Find the first .json file explicitly
  local first_theme
  for theme_file in "$ZSH_CUSTOM/themes/posh"/*.omp.toml; do
    if [[ -f "$theme_file" ]]; then
      first_theme="$theme_file"
      break
    fi
  done
  
  if [[ -n "$first_theme" ]]; then
    eval "$(oh-my-posh init zsh --config $first_theme)"
  else
    echo "No Oh My Posh themes found in $ZSH_CUSTOM/themes/posh"
  fi
else
  eval "$(oh-my-posh init zsh --config $ZSH_CUSTOM/themes/zsh/example.zsh-theme)"
fi