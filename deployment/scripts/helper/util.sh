#!/bin/bash

# This function returns JSON property value
# It takes 3 arguments
# (1) JSON filename with path
# (2) JSON property name
# (3) Variable name in which value to be assigned
get_json_property_value() {
    local __result_var=$3
    local _param_value=$( envsubst < $1 |  jq -r .$2 )
    eval $__result_var=$_param_value
}

# This function returns JSON property value of groupStacks array in stacks.json
# It takes 5 arguments
# (1) JSON filename with path
# (2) Stack Index
# (3) Group Stack Index
# (4) JSON property name
# (5) Variable name in which value to be assigned
get_group_stack_property_value() {
    local __result_var=$5
    local _property_value=$( envsubst < $1 | jq -r --argjson stack_index $2 --argjson group_index $3 --arg property $4 '.stacks[$stack_index].groupStacks[$group_index][$property]' )
    eval $__result_var=$_property_value
}

# This function converts CFN parameter JSON file key and value into key=value separated by space
# It takes 1 argument
# (1) JSON filename with path
get_parameter_values() {
    local _parameters=$( envsubst < $1 | jq -r '. | to_entries | map("\(.key)=\(.value | tostring)") | join(" ")' )
    echo "${_parameters}"
}

# This function installs required python dependencies and upload Lambda code into S3 bucket
# It takes 5 arguments
# (1) Directory in which Lambda python code available
# (2) Stack parameter file with path
# (3) Lambda package directory
# (4) Lambda zip filename prefix
cfn_package() {
    local _lambda_dir=$1 _parameter_file=$2 _pkg_dir=$3 _zip_prefix=$4
    get_json_property_value ${_parameter_file} LambdaS3Bucket lambda_s3_bucket
    get_json_property_value ${_parameter_file} LambdaS3Prefix lambda_s3_prefix
    echo "lambda_s3_bucket: ${lambda_s3_bucket}, lambda_s3_prefix: ${lambda_s3_prefix}"
    # Generate lambda zip filename by appending uuid
    lambda_zip_filename=${_zip_prefix}-$(uuidgen).zip
    export lambda_zip_filename
    echo "lambda_zip_filename: ${lambda_zip_filename}"
    # Update umask so that user, group and others have read access, it is required by Lambda
    umask 002
    # Remove Lambda package directory if exists already
    rm -rf ${_pkg_dir}
    # Create Lambda package directory and src directory underneath
    mkdir -p ${_pkg_dir}/src
    # Install Python requests package in src directory
    pip3 install requests -t ${_pkg_dir}/src
    # Copy Lambda python code into package src directory
    cp ${_lambda_dir}/*.py ${_pkg_dir}/src
    chmod 744 ${_pkg_dir}/src/*.py
    # Zip src directory
    (cd ${_pkg_dir}/src; zip -r ../${lambda_zip_filename} .)
    chmod u+x ${_pkg_dir}/${lambda_zip_filename}
    # Upload zip file into S3
    aws s3 cp ${_pkg_dir}/${lambda_zip_filename} s3://${lambda_s3_bucket}/${lambda_s3_prefix}/${lambda_zip_filename}
    # Exit if upload to S3 bucket fails
    local _exit_code=$?
    if [[ "${_exit_code}" != "0" ]]; then
        echo "Lambda code upload to S3 bucket failed with exit code ${_exit_code}, so exiting"
        exit 1
    fi
}

# This function executes given CFN deploy command
# It takes 1 argument
# (1) AWS cloudformation deploy/package command
execute_cfn() {
    echo "Executing $1 command"
    eval $1
}

# This function waits for child processes to complete
# It takes 3 arguments
# (1) Child pids array length
# (2) Array of child pids
# (3) Array of stack names
# It returns 0 only if all stacks executed without failure
function wait_and_get_exit_codes() {
    local -a _children=( "${@:2:$1}" ) _stacks=( "${@:$1+2}" )
    local _failed_stacks=()
    for i in "${!_children[@]}"; do
        job="${_children[$i]}"
        echo "Waiting for ${_stacks[$i]} stack to complete ${job}..."
        local _code=0
        wait ${job} || _code=$?
        if [[ "${_code}" != "0" ]]; then
            echo "${_stacks[$i]} stack failed with exit code ${_code}"
            _failed_stacks+=("${_stacks[$i]}")
        fi
    done
    local _exit_code=0
    if (( ${#_failed_stacks[@]} > 0 )); then
        _exit_code=1
        echo "Following stacks failed: ${_failed_stacks[@]}"
    fi
    return "${_exit_code}"
}

# This function deploy stacks, it picks one stack group at a time and run all stacks in that group in parallel
# It does not process next group if any stack failed in current group
# If IsActive is false it processes group in reverse order
# It takes 1 argument
# (1) stacks.json filename with path
deploy_stacks() {
    local _stack_file=$1
    local _length=$( jq -r '.stacks | length' ${_stack_file} )
    let _length=_length-1
    echo "_length: ${_length}"

    local _start=0
    local _end=${_length}
    local _increment=1
    if [ "${is_active}" = "false" ]; then
        _start=${_length}
        _end=0
        _increment=-1
    fi
    echo "_start: $_start, _increment: $_increment, _end: $_end"

    for i in `seq ${_start} ${_increment} ${_end}`;
    do
        deploy_stack_group_parallel ${_stack_file} $i
        if [[ "$?" != "0" ]]; then
          echo "Group $i stack failed"
          return 1
        fi
    done
}

# This function deploys CFN templates in given group stacks in parallel
# It takes 2 arguments
# (1) stacks.json filename with path
# (2) Group stacks array index
deploy_stack_group_parallel() {
    local _stack_file=$1
    local _index=$2
    local _length=$( jq -r --argjson index ${_index} '.stacks[$index].groupStacks | length' ${_stack_file} )
    let _length=_length-1
    echo "_grp_length: ${_length}"

    local _group_child_pids=()
    local _group_stacks=()
    for j in `seq 0 ${_length}`;
    do
        get_group_stack_property_value ${_stack_file} ${_index} $j "stackName" stack_name
        get_group_stack_property_value ${_stack_file} ${_index} $j "isLambdaStack" is_lambda_stack
        get_group_stack_property_value ${_stack_file} ${_index} $j "templateFile" template_file
        get_group_stack_property_value ${_stack_file} ${_index} $j "paramFile" param_file
        get_group_stack_property_value ${_stack_file} ${_index} $j "lambdaDir" lambda_directory
        get_group_stack_property_value ${_stack_file} ${_index} $j "lambdaPackageDir" lambda_package_directory
        get_group_stack_property_value ${_stack_file} ${_index} $j "lambdaZipFileNamePrefix" lambda_zip_filename_prefix
        echo stackIndex: ${_index}, groupIndex: $j, stack_name: $stack_name, is_lambda_stack: $is_lambda_stack, \
            template_file: $template_file, param_file: $param_file, lambda_directory: $lambda_directory, \
            lambda_package_directory: $lambda_package_directory, lambda_zip_filename_prefix: $lambda_zip_filename_prefix

        # If it is Lambda stack and it is invoked from maintenance script, then skip stack
        if [ "${is_lambda_stack}" = "true" ] && [ "${is_maintenance}" = "true" ]; then
            echo "Skipping ${stack_name} stack because it is Lambda stack and invoked from maintenance script"
            continue
        fi

        # If it is Lambda stack, upload python code to S3
        if [ "${is_lambda_stack}" = "true" ]; then
            cfn_package ${lambda_directory} ${param_file} ${lambda_package_directory} ${lambda_zip_filename_prefix}
        fi

        # Get parameter overrides for given stack
        param_values="$(get_parameter_values ${param_file})"
        # Run deploy command in parallel and collect child pid
        local _deploy_command="aws --region $aws_region cloudformation deploy --template-file ${template_file} --stack-name ${stack_name} --parameter-overrides ${param_values} --no-fail-on-empty-changeset --capabilities CAPABILITY_NAMED_IAM"
        execute_cfn "${_deploy_command}" &
        _group_child_pids+=("$!")
        _group_stacks+=("${stack_name}")
        sleep 3
    done

    local _pid_array_length=${#_group_child_pids[@]}
    echo "_pid_array_length: ${_pid_array_length}"
    #  Wait for for group stacks to complete
    if [ "${_pid_array_length}" -gt 0 ]; then
        wait_and_get_exit_codes "${#_group_child_pids[@]}" "${_group_child_pids[@]}" "${_group_stacks[@]}"
        local _group_stacks_return_code=$?
        # If any stack failed then exit
        if [ "${_group_stacks_return_code}" -ne "0" ]; then
            echo "Group ${_index} stacks failed so exiting, please look for failed stacks"
            return 1
        fi
    fi
    return 0
}

# This function find image version from deployed stack parameter
# First it finds stack from JSON based on stack index and stack group index
# It takes 3 arguments
# (1) stacks.json filename with path
# (2) Stack index
# (3) Stack group index
# (4) Variable name in which value to be returned
get_image_version() {
    local __result_var=$4
    get_group_stack_property_value $1 $2 $3 "stackName" stack_name
    echo "stack_name: ${stack_name}"
    local _image_version=$(aws --region $aws_region cloudformation describe-stacks --stack-name ${stack_name} --query "Stacks[0].Parameters[?ParameterKey=='ImageVersion'].ParameterValue" --output text)
    echo "_image_version: ${_image_version}"
    if [[ "${_image_version}" == "" ]]; then
        echo "Not able to find image version, so exiting, please check ${stack_name} stack parameter ImageVersion"
        exit 1
    fi
    eval $__result_var=${_image_version}
}

# It returns active flag based on action, returns true if action is start, otherwise returns false
# It takes 1 argument
# (1) Action
get_active_flag() {
    local _is_active='true'
    if [ "$1" = "stop" ]; then
        _is_active='false'
    fi
    echo "${_is_active}"
}

# This function deletes given CFN template stack
# It takes 1 argument
# (1) AWS cloudformation stack name
delete_cfn_stack() {
    echo "Deleting $1 stack..."
    aws --region $aws_region cloudformation delete-stack --stack-name $1
    echo "Waiting for $1 stack to be deleted, this may take few minutes..."
    aws --region $aws_region cloudformation wait stack-delete-complete --stack-name $1
}

# This function deletes CFN template stacks in given group stacks in parallel
# It takes 2 arguments
# (1) stacks.json filename with path
# (2) Group stacks array index
delete_stack_group_parallel() {
    local _stack_file=$1
    local _index=$2
    local _length=$( jq -r --argjson index ${_index} '.stacks[$index].groupStacks | length' ${_stack_file} )
    let _length=_length-1
    echo "_grp_length: ${_length}"

    local _group_child_pids=()
    local _group_stacks=()
    for j in `seq 0 ${_length}`;
    do
        get_group_stack_property_value ${_stack_file} ${_index} $j "stackName" stack_name
        get_group_stack_property_value ${_stack_file} ${_index} $j "canBeDeleted" can_be_deleted
        echo "stackIndex: ${_index}, groupIndex: $j, stack_name: $stack_name, can_be_deleted: $can_be_deleted"

        # If stack marked as can not be deleted, skip it
        if [ "${can_be_deleted}" = "No" ]; then
            echo "Skipping ${stack_name} stack deletion because it is marked as can not be deleted"
            continue
        fi

        # Run delete stack command in parallel and collect child pid
        delete_cfn_stack "${stack_name}" &
        _group_child_pids+=("$!")
        _group_stacks+=("${stack_name}")
        sleep 3
    done

    local _pid_array_length=${#_group_child_pids[@]}
    echo "_pid_array_length: ${_pid_array_length}"
    #  Wait for for group stacks to complete
    if [ "${_pid_array_length}" -gt 0 ]; then
        wait_and_get_exit_codes "${#_group_child_pids[@]}" "${_group_child_pids[@]}" "${_group_stacks[@]}"
        local _group_stacks_return_code=$?
        # If any stack failed then exit
        if [ "${_group_stacks_return_code}" -ne "0" ]; then
            echo "Group ${_index} stacks failed so exiting, please look for failed stacks"
            exit 1
        fi
    fi
}

# This function delete stacks, it picks one stack group at a time and run all stacks in that group in parallel
# It does not process next group if any stack failed in current group
# It processes group in reverse order
# It takes 1 argument
# (1) stacks.json filename with path
delete_stacks() {
    local _stack_file=$1
    local _length=$( jq -r '.stacks | length' ${_stack_file} )
    let _length=_length-1
    echo "_length: ${_length}"

    for i in `seq ${_length} -1 0`;
    do
        delete_stack_group_parallel ${_stack_file} $i
    done
}

# This function shows how to invoke deploy script
show_script_usage_deploy() {
    echo -e "\n************************************************************************************************"
    echo -e "`date` Script error : Incorrect usage"
    echo -e "Script Usage:"
    echo -e "\t ./deployStack.sh <ENV> <ImageVersion> <IsActive>\n"
    echo -e "Pass 2 arguments to create/update Cloudformation stack"
    echo -e "(1) Environment Name (DEV)"
    echo -e "(2) Version of docker image"
    echo -e "(3) Is Active Environment? <true/false> If true, then it starts task for all ECS services, otherwise it will not start any tasks"
    echo -e "************************************************************************************************"
}

# This function shows how to invoke maintenance script
show_script_usage_maintenance() {
    echo -e "\n************************************************************************************************"
    echo -e "`date` Script error : Incorrect usage"
    echo -e "Script Usage:"
    echo -e "\t ./maintenance.sh <ENV> <Action>\n"
    echo -e "Pass 2 arguments to start or stop all ECS service tasks"
    echo -e "(1) Environment Name (DEV)"
    echo -e "(2) Action (start/stop)"
    echo -e "************************************************************************************************"
}

# This function shows how to invoke this delete script
show_script_usage_delete()
{
    echo -e "\n************************************************************************************************"
    echo -e "`date` Script error : Incorrect usage"
    echo -e "Script Usage:"
    echo -e "\t ./deleteStack.sh <ENV>\n"
    echo -e "Pass 1 argument to delete Cloudformation stack"
    echo -e "(1) Environment Name (DEV)"
    echo -e "************************************************************************************************"
}
