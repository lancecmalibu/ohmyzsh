# ANSI formatting function (\033[<code>m)
# 0: reset, 1: bold, 4: underline, 22: no bold, 24: no underline, 31: red, 33: yellow

# Timing function - disabled unless OMZ_DEBUG_TIMING=1
_omz_timer() {
  [[ "$OMZ_DEBUG_TIMING" = "1" ]] || return
  
  local start_var="$1"
  local end_var="$2"
  local label="$3"
  
  if [[ -n "$end_var" ]]; then
    # End timing - get current time
    local end_time=$(($(gdate +%s%N)/1000000))
    eval "$end_var=\$end_time"
    local start_time=${(P)start_var}
    local elapsed=$((end_time - start_time))
    echo "${elapsed}ms: $label"
  else
    # Start timing
    eval "$start_var=\$(($(gdate +%s%N)/1000000))"
  fi
}

# Simple debug print function
_omz_debug() {
  [[ "$OMZ_DEBUG_TIMING" = "1" ]] || return
  local current_time=$(($(gdate +%s%N)/1000000))
  echo "${current_time}ms: $1"
}

# Start overall timing
_omz_timer start_total

omz_f() {
  [ $# -gt 0 ] || return
  IFS=";" printf "\033[%sm" $*
}
# If stdout is not a terminal ignore all formatting
[ -t 1 ] || omz_f() { :; }

# Protect against non-zsh execution of Oh My Zsh (use POSIX syntax here)
[ -n "$ZSH_VERSION" ] || {
  omz_ptree() {
    # Get process tree of the current process
    pid=$$; pids="$pid"
    while [ ${pid-0} -ne 1 ] && ppid=$(ps -e -o pid,ppid | awk "\$1 == $pid { print \$2 }"); do
      pids="$pids $pid"; pid=$ppid
    done

    # Show process tree
    case "$(uname)" in
    Linux) ps -o ppid,pid,command -f -p $pids 2>/dev/null ;;
    Darwin|*) ps -o ppid,pid,command -p $pids 2>/dev/null ;;
    esac

    # If ps command failed, try Busybox ps
    [ $? -eq 0 ] || ps -o ppid,pid,comm | awk "NR == 1 || index(\"$pids\", \$2) != 0"
  }

  {
    shell=$(ps -o pid,comm | awk "\$1 == $$ { print \$2 }")
    printf "$(omz_f 1 31)Error:$(omz_f 22) Oh My Zsh can't be loaded from: $(omz_f 1)${shell}$(omz_f 22). "
    printf "You need to run $(omz_f 1)zsh$(omz_f 22) instead.$(omz_f 0)\n"
    printf "$(omz_f 33)Here's the process tree:$(omz_f 22)\n\n"
    omz_ptree
    printf "$(omz_f 0)\n"
  } >&2

  return 1
}

# Check if in emulation mode, if so early return
# https://github.com/ohmyzsh/ohmyzsh/issues/11686
[[ "$(emulate)" = zsh ]] || {
  printf "$(omz_f 1 31)Error:$(omz_f 22) Oh My Zsh can't be loaded in \`$(emulate)\` emulation mode.$(omz_f 0)\n" >&2
  return 1
}

unset -f omz_f

# If ZSH is not defined, use the current script's directory.
[[ -n "$ZSH" ]] || export ZSH="${${(%):-%x}:a:h}"

# Set ZSH_CUSTOM to the path where your custom config files
# and plugins exists, or else we will use the default custom/
[[ -n "$ZSH_CUSTOM" ]] || ZSH_CUSTOM="$ZSH/custom"

# Set ZSH_CACHE_DIR to the path where cache files should be created
# or else we will use the default cache/
[[ -n "$ZSH_CACHE_DIR" ]] || ZSH_CACHE_DIR="$ZSH/cache"

# Make sure $ZSH_CACHE_DIR is writable, otherwise use a directory in $HOME
if [[ ! -w "$ZSH_CACHE_DIR" ]]; then
  ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
fi

# Create cache and completions dir and add to $fpath
_omz_debug "Starting cache setup"
mkdir -p "$ZSH_CACHE_DIR/completions"
(( ${fpath[(Ie)$ZSH_CACHE_DIR/completions]} )) || fpath=("$ZSH_CACHE_DIR/completions" $fpath)

# Check for updates on initial load...
_omz_debug "Starting update check"
source "$ZSH/tools/check_for_upgrade.sh"
_omz_debug "Finished update check"

# Initializes Oh My Zsh
_omz_debug "Starting Oh My Zsh initialization"

# add a function path
fpath=($ZSH/{functions,completions} $ZSH_CUSTOM/{functions,completions} $fpath)

# Load all stock functions (from $fpath files) called below.
_omz_debug "Loading autoload functions"
autoload -U compaudit compinit zrecompile

is_plugin() {
  local base_dir=$1
  local name=$2
  builtin test -f $base_dir/plugins/$name/$name.plugin.zsh \
    || builtin test -f $base_dir/plugins/$name/_$name
}

# Add all defined plugins to fpath. This must be done
# before running compinit.
_omz_timer fpath_start
for plugin ($plugins); do
  if is_plugin "$ZSH_CUSTOM" "$plugin"; then
    fpath=("$ZSH_CUSTOM/plugins/$plugin" $fpath)
  elif is_plugin "$ZSH" "$plugin"; then
    fpath=("$ZSH/plugins/$plugin" $fpath)
  else
    echo "[oh-my-zsh] plugin '$plugin' not found"
  fi
done
_omz_timer fpath_start fpath_end "Adding plugins to fpath"

# Figure out the SHORT hostname
_omz_debug "Getting hostname"
if [[ "$OSTYPE" = darwin* ]]; then
  # macOS's $HOST changes with dhcp, etc. Use LocalHostName if possible.
  SHORT_HOST=$(scutil --get LocalHostName 2>/dev/null) || SHORT_HOST="${HOST/.*/}"
else
  SHORT_HOST="${HOST/.*/}"
fi

# Save the location of the current completion dump file.
if [[ -z "$ZSH_COMPDUMP" ]]; then
  ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"
fi

# Construct zcompdump OMZ metadata
_omz_debug "Setting up completion metadata"
zcompdump_revision="#omz revision: $(builtin cd -q "$ZSH"; git rev-parse HEAD 2>/dev/null)"
zcompdump_fpath="#omz fpath: $fpath"

# Delete the zcompdump file if OMZ zcompdump metadata changed
if ! command grep -q -Fx "$zcompdump_revision" "$ZSH_COMPDUMP" 2>/dev/null \
   || ! command grep -q -Fx "$zcompdump_fpath" "$ZSH_COMPDUMP" 2>/dev/null; then
  command rm -f "$ZSH_COMPDUMP"
  zcompdump_refresh=1
fi

_omz_timer compinit_start
if [[ "$ZSH_DISABLE_COMPFIX" != true ]]; then
  _omz_debug "Loading compfix and running secure compinit"
  source "$ZSH/lib/compfix.zsh"
  # Load only from secure directories
  compinit -i -d "$ZSH_COMPDUMP"
  # If completion insecurities exist, warn the user
  handle_completion_insecurities &|
else
  _omz_debug "Running unsafe compinit"
  # If the user wants it, load from all found directories
  compinit -u -d "$ZSH_COMPDUMP"
fi
_omz_timer compinit_start compinit_end "Completion initialization"

# Append zcompdump metadata if missing
if (( $zcompdump_refresh )) \
  || ! command grep -q -Fx "$zcompdump_revision" "$ZSH_COMPDUMP" 2>/dev/null; then
  # Use `tee` in case the $ZSH_COMPDUMP filename is invalid, to silence the error
  # See https://github.com/ohmyzsh/ohmyzsh/commit/dd1a7269#commitcomment-39003489
  tee -a "$ZSH_COMPDUMP" &>/dev/null <<EOF

$zcompdump_revision
$zcompdump_fpath
EOF
fi
unset zcompdump_revision zcompdump_fpath zcompdump_refresh

# zcompile the completion dump file if the .zwc is older or missing.
_omz_timer zrecompile_start
if command mkdir "${ZSH_COMPDUMP}.lock" 2>/dev/null; then
  _omz_debug "Recompiling completion dump"
  zrecompile -q -p "$ZSH_COMPDUMP"
  command rm -rf "$ZSH_COMPDUMP.zwc.old" "${ZSH_COMPDUMP}.lock"
fi
_omz_timer zrecompile_start zrecompile_end "Completion recompilation"

_omz_source() {
  local context filepath="$1"
  [[ "$OMZ_DEBUG_TIMING" = "1" ]] && local timer_start=$(($(gdate +%s%N)/1000000))

  # Construct zstyle context based on path
  case "$filepath" in
  lib/*) context="lib:${filepath:t:r}" ;;         # :t = lib_name.zsh, :r = lib_name
  plugins/*) context="plugins:${filepath:h:t}" ;; # :h = plugins/plugin_name, :t = plugin_name
  esac

  local disable_aliases=0
  zstyle -T ":omz:${context}" aliases || disable_aliases=1

  # Back up alias names prior to sourcing
  local -A aliases_pre galiases_pre
  if (( disable_aliases )); then
    aliases_pre=("${(@kv)aliases}")
    galiases_pre=("${(@kv)galiases}")
  fi

  # Source file from $ZSH_CUSTOM if it exists, otherwise from $ZSH
  if [[ -f "$ZSH_CUSTOM/$filepath" ]]; then
    source "$ZSH_CUSTOM/$filepath"
  elif [[ -f "$ZSH/$filepath" ]]; then
    source "$ZSH/$filepath"
  fi

  # Unset all aliases that don't appear in the backed up list of aliases
  if (( disable_aliases )); then
    if (( #aliases_pre )); then
      aliases=("${(@kv)aliases_pre}")
    else
      (( #aliases )) && unalias "${(@k)aliases}"
    fi
    if (( #galiases_pre )); then
      galiases=("${(@kv)galiases_pre}")
    else
      (( #galiases )) && unalias "${(@k)galiases}"
    fi
  fi

  # Report timing only if debug enabled
  if [[ "$OMZ_DEBUG_TIMING" = "1" ]]; then
    local timer_end=$(($(gdate +%s%N)/1000000))
    local elapsed=$((timer_end - timer_start))
    echo "${elapsed}ms: _omz_source $filepath"
  fi
}

# Load all of the lib files in ~/.oh-my-zsh/lib that end in .zsh
# TIP: Add files you don't want in git to .gitignore
_omz_timer lib_start
for lib_file ("$ZSH"/lib/*.zsh); do
  _omz_source "lib/${lib_file:t}"
done
_omz_timer lib_start lib_end "Loading lib files"
unset lib_file

# Load all of the plugins that were defined in ~/.zshrc
_omz_timer plugins_start
for plugin ($plugins); do
  _omz_source "plugins/$plugin/$plugin.plugin.zsh"
done
_omz_timer plugins_start plugins_end "Loading plugins"
unset plugin

# Load all of your custom configurations from custom/
_omz_timer custom_start
for config_file ("$ZSH_CUSTOM"/*.zsh(N)); do
  source "$config_file"
done
_omz_timer custom_start custom_end "Loading custom configs"
unset config_file

# Load the theme
is_theme() {
  local base_dir=$1
  local name=$2
  builtin test -f $base_dir/$name.zsh-theme
}

if [[ -n "$ZSH_THEME" ]]; then
  _omz_timer theme_start
  if is_theme "$ZSH_CUSTOM" "$ZSH_THEME"; then
    source "$ZSH_CUSTOM/$ZSH_THEME.zsh-theme"
  elif is_theme "$ZSH_CUSTOM/themes" "$ZSH_THEME"; then
    source "$ZSH_CUSTOM/themes/$ZSH_THEME.zsh-theme"
  elif is_theme "$ZSH/themes" "$ZSH_THEME"; then
    source "$ZSH/themes/$ZSH_THEME.zsh-theme"
  else
    echo "[oh-my-zsh] theme '$ZSH_THEME' not found"
  fi
  _omz_timer theme_start theme_end "Loading theme: $ZSH_THEME"
fi

# set completion colors to be the same as `ls`, after theme has been loaded
_omz_debug "Setting completion colors"
[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Final timing report
_omz_timer start_total total_end "TOTAL OH-MY-ZSH LOADING"
_omz_debug "Oh My Zsh loading complete"
