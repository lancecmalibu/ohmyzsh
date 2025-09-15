# Docker → Apple Container shim for zsh/oh-my-zsh
# Drop-in function that intercepts `docker ...` and calls `container ...`

# Safety: if real `docker` is required, call `\docker` to bypass this shim.

docker() {
  # If no subcommand, just show container help/version as appropriate
  if [[ $# -eq 0 ]]; then
    command container --help
    return
  fi

  local cmd=$1
  shift

  case "$cmd" in
    -v|--version|version)
      set -- --version "$@"
      ;;
    -h|--help|help)
      set -- --help "$@"
      ;;

    # Containers
    ps)
      # docker ps [-a] → container list [-a]
      set -- list "$@"
      ;;
    run|build|create|start|stop|kill|exec|logs|inspect)
      # Direct pass-through; flags are largely compatible
      set -- "$cmd" "$@"
      ;;
    rm)
      # docker rm → container delete
      set -- delete "$@"
      ;;

    # Images (top-level docker shortcuts)
    images)
      # docker images → container image ls
      set -- image ls "$@"
      ;;
    pull)
      set -- image pull "$@"
      ;;
    push)
      set -- image push "$@"
      ;;
    rmi)
      set -- image delete "$@"
      ;;
    tag)
      set -- image tag "$@"
      ;;
    save)
      set -- image save "$@"
      ;;
    load)
      set -- image load "$@"
      ;;

    # docker image ...
    image)
      local sub=${1:-}
      if [[ -n $sub ]]; then shift; fi
      case "$sub" in
        ls|list)
          set -- image list "$@"
          ;;
        rm|rmi|delete)
          set -- image delete "$@"
          ;;
        pull|push|tag|save|load|inspect|prune)
          set -- image "$sub" "$@"
          ;;
        *)
          # Fallback: pass through unknown subcommand
          set -- image "$sub" "$@"
          ;;
      esac
      ;;

    # Networks (macOS 26+ only)
    network)
      local sub=${1:-}
      if [[ -n $sub ]]; then shift; fi
      case "$sub" in
        ls|list)
          set -- network list "$@"
          ;;
        rm|delete)
          set -- network delete "$@"
          ;;
        create|inspect)
          set -- network "$sub" "$@"
          ;;
        *)
          printf 'docker: network subcommand "%s" not supported by container\n' "$sub" >&2
          return 1
          ;;
      esac
      ;;

    # Volumes
    volume)
      local sub=${1:-}
      if [[ -n $sub ]]; then shift; fi
      case "$sub" in
        ls|list)
          set -- volume list "$@"
          ;;
        rm|delete)
          set -- volume delete "$@"
          ;;
        create|inspect)
          set -- volume "$sub" "$@"
          ;;
        *)
          printf 'docker: volume subcommand "%s" not supported by container\n' "$sub" >&2
          return 1
          ;;
      esac
      ;;

    # Registry auth
    login)
      set -- registry login "$@"
      ;;
    logout)
      set -- registry logout "$@"
      ;;

    # System
    system)
      local sub=${1:-}
      if [[ -n $sub ]]; then shift; fi
      case "$sub" in
        start|stop|status|logs)
          set -- system "$sub" "$@"
          ;;
        prune)
          # Best-effort: map to image prune
          set -- image prune "$@"
          ;;
        *)
          set -- system "$sub" "$@"
          ;;
      esac
      ;;

    # Not (yet) supported
    compose|docker-compose)
      printf 'docker compose is not supported by Apple "container" yet.\n' >&2
      return 1
      ;;
    cp)
      printf 'docker cp is not supported by Apple "container" (no equivalent).\n' >&2
      return 1
      ;;

    *)
      # Fallback: attempt to pass the subcommand through unchanged
      set -- "$cmd" "$@"
      ;;
  esac

  command container "$@"
}

# Convenience: short aliases similar to docker habits
alias d='docker'
alias dk='docker'

