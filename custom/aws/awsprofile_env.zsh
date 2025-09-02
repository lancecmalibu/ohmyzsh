# AWS Profile Environment Management
# Sets up AWS profile and CA bundle from GOSSO temporary files

awsprofile_env() {
    export AWS_PROFILE=$(cat /tmp/gosso_last_profile 2>/dev/null || echo "")
    export AWS_SDK_LOAD_CONFIG=1
    
    if [ -f /tmp/gosso_ca_bundle ]; then
        export AWS_CA_BUNDLE=$(cat /tmp/gosso_ca_bundle)
    else
        unset AWS_CA_BUNDLE
    fi
}
