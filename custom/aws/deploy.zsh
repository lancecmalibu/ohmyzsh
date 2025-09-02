# Lambda Deployment Function
# Deploys Lambda services by finding the project root with Makefile

deploy() {
  local current_dir="$PWD"
  local project_root=""
  local service tmp profile AWS_ACCOUNT_ID
  local max_depth=10  # Prevent infinite climbing
  local depth=0

  # 1) Find project root by climbing up to find Makefile
  while [[ $depth -lt $max_depth ]]; do
    if [[ -f "$current_dir/Makefile" ]]; then
      project_root="$current_dir"
      break
    fi
    
    # Go up one directory
    current_dir=$(dirname "$current_dir")
    
    # Stop if we've reached the filesystem root
    if [[ "$current_dir" == "/" ]]; then
      break
    fi
    
    ((depth++))
  done

  # Check if we found a Makefile
  if [[ -z "$project_root" ]]; then
    echo "deploy: no Makefile found in current directory or any parent directory" >&2
    return 1
  fi

  # 2) Are we in a lambdas/<Service>/… subtree relative to project root?
  case $PWD in
    "$project_root"/functions/*)
      # strip up through "…/lambdas/"
      tmp=${PWD#"$project_root"/functions/}
      # grab just the first path element → Service name
      service=${tmp%%/*}
      ;;
    *)
      echo "deploy: not under $project_root/functions/<Service>" >&2
      echo "deploy: project root found at: $project_root" >&2
      return 1
      ;;
  esac

  # 3) Figure out which AWS_PROFILE to use
  profile=${AWS_PROFILE:-default}

  # 4) Fetch the AWS Account ID for that profile
  AWS_ACCOUNT_ID=$(
    aws sts get-caller-identity \
      --profile "$profile" \
      --query Account \
      --output text 2>/dev/null
  )
  if [[ -z $AWS_ACCOUNT_ID ]]; then
    echo "deploy: failed to get AWS account for profile '$profile'" >&2
    return 1
  fi

  echo "deploy: deploying service '$service' from project root '$project_root'"
  
  # 5) Run make in the project root, passing our vars + any extra args
  make -C "$project_root" update-lambda \
    LAMBDA="$service" \
    AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
    "$@"
}
