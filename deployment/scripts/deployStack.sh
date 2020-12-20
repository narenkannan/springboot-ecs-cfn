#!/bin/bash

# This function validates input parameter ENV
validate_environment() {
    if ! [[ "$1" == "DEV" ]] ; then
        echo "Invalid ENV argument value, it should be DEV"
        show_script_usage_deploy
        exit 1
    fi
}

# This function validates input parameter IsActive
validate_active_flag() {
    if ! [[ "$1" == "true" || "$1" == "false" ]] ; then
        echo "Invalid IsActive argument value, it should be true or false"
        show_script_usage_deploy
        exit 1
    fi
}

# This function sets up all required variables
setup_env() {
    export app_name='HELLO-WORLD-CFN'
    export app_environment=$1
    export image_version=$2
    export is_active=$3
    echo "app_environment: $app_environment, app_name: $app_name, image_version: $image_version, is_active: $is_active"

    # Setup environment specific variables from <ENV>.json file
    local __env_file=$cfn_dir/env/$app_environment/$app_environment.json
    get_json_property_value $__env_file region aws_region
    export aws_region
    echo "aws_region: $aws_region"
}

# Check whether script is called from repository root
export scripts_dir='./deployment/scripts'
export cfn_dir='./deployment/cfn'
if [[ "`dirname $0`" != "$scripts_dir" ]]; then
    echo "This script must be called from repository root"
    exit 1
fi

# Load common functions
source ${scripts_dir}/helper/util.sh

# Check number of arguments
if [[ $# -ne 3 ]]
then
    show_script_usage_deploy
    exit 1
fi

# Validate input parameters
validate_environment $1
validate_active_flag $3

# Setup environment
setup_env $1 $2 $3

# Deploy stacks, If script execution fails, it will retry again
retry_counter=1
max_retry=1
delay_in_sec=10

while true; do
  deploy_stacks ${cfn_dir}/env/stacks.json && break || {
    if [[ ${retry_counter} -lt ${max_retry} ]]; then
      ((retry_counter++))
      echo "Command failed, Attempt ${retry_counter}/${max_retry}"
      sleep ${delay_in_sec}
    else
      echo "Command failed after ${retry_counter} attempts"
      exit 1
    fi
  }
done

echo "All stacks are deployed successfully"