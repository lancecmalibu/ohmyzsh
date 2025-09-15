# Minimal gosso + AWS profile helper (interactive first, no fragile piping)

# Path to gosso (adjust if needed)
: "${AWS_GOSSO_CMD:=gosso}"

# Temp files gosso already produces (adjust names if different)
: "${AWS_GOSSO_PROFILE_FILE:=/tmp/gosso_last_profile}"
: "${AWS_GOSSO_CA_FILE:=/tmp/gosso_ca_bundle}"
: "${AWS_GOSSO_EXPORT_FILE:=/tmp/gosso_exports}"   # optional: only if gosso writes one

_awsprofile_load_files() {
  # Profile
  if [[ -f $AWS_GOSSO_PROFILE_FILE ]]; then
    local p; p=$(<"$AWS_GOSSO_PROFILE_FILE")
    [[ -n $p ]] && export AWS_PROFILE="$p" || unset AWS_PROFILE
  else
    unset AWS_PROFILE
  fi

  # CA bundle (either path or raw certs)
  if [[ -f $AWS_GOSSO_CA_FILE ]]; then
    local c; c=$(<"$AWS_GOSSO_CA_FILE")
    if [[ -f $c ]]; then
      export AWS_CA_BUNDLE="$c"
    elif grep -q "BEGIN CERTIFICATE" "$AWS_GOSSO_CA_FILE"; then
      local bundle=${TMPDIR:-/tmp}/gosso_aws_ca.pem
      cp "$AWS_GOSSO_CA_FILE" "$bundle" 2>/dev/null && chmod 600 "$bundle"
      export AWS_CA_BUNDLE="$bundle"
    else
      unset AWS_CA_BUNDLE
    fi
  else
    unset AWS_CA_BUNDLE
  fi

  # Optional: if gosso drops a full env script
  if [[ -f $AWS_GOSSO_EXPORT_FILE ]]; then
    # shellcheck disable=SC1090
    source "$AWS_GOSSO_EXPORT_FILE"
  fi
}

# Optional eval mode ONLY if gosso supports a --print-env (no TTY) flag.
_awsprofile_eval() {
  local out line key val
  out=$("$AWS_GOSSO_CMD" --print-env "$@" 2>/dev/null) || return 1
  while IFS= read -r line; do
    [[ $line == export\ AWS_* ]] && line=${line#export }
    [[ $line == AWS_*=* ]] || continue
    key=${line%%=*}
    val=${line#*=}
    val=${val#\"}; val=${val%\"}
    export "$key=$val"
  done <<<"$out"
  return 0
}

awsprofile() {
  case "$1" in
    show|"")
      _awsprofile_load_files
      ;;
    eval)
      shift
      if ! _awsprofile_eval "$@"; then
        echo "eval mode failed (maybe gosso lacks --print-env); falling back to interactive." >&2
        "$AWS_GOSSO_CMD" "$@"
        _awsprofile_load_files
      fi
      ;;
    *)
      # Run gosso interactively (dropdown happens here), then load files.
      "$AWS_GOSSO_CMD" "$@"
      _awsprofile_load_files
      ;;
  esac

  [[ -n $AWS_PROFILE ]] && echo "AWS_PROFILE=$AWS_PROFILE" || echo "AWS_PROFILE (unset)"
  [[ -n $AWS_CA_BUNDLE ]] && echo "AWS_CA_BUNDLE=$AWS_CA_BUNDLE"
}

# Backward compatibility
awsprofile_env() { awsprofile show; }