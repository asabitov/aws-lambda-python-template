#!/bin/bash


print_help() {

  echo
  echo "Deploy a Python script to AWS Lambda."
  echo 
  echo "Usage: deploy.sh [-c schedule] script"
  echo
  echo "The 'script' is a Python script to be deployed as a Lambda function."
  echo
  echo "  -c    This option sets a cron job. For example, use this command to set a job, which repeats every hour: "
  echo "        deploy.sh script -c 'cron(0 * * * ? *)'"
  echo
  echo "  -h    Print a help message and exit."
  echo
  echo "  -u    Update Lambda function's code if the function already exists."
  echo

}

deploy_function() {

  # Create the package to deploy

  pkg_name="${lambda_function_name}_pkg"
  rm -fr build/${pkg_name}
  mkdir -p build/"${pkg_name}"

  if [ -z ${python_modules_path} ]; then
    cp -a ${python_script} build/"${pkg_name}"
  else
    cp -a ${python_script} ${python_modules_path}/* build/"${pkg_name}"
  fi

  cd build/${pkg_name}
  zip -r "${pkg_name}.zip" ./ &>/dev/null

  functions=$(aws lambda list-functions --query 'Functions[].FunctionName' --output text)
 
  for f in ${functions}; do
    if [ "$f" = "${lambda_function_name}" ]; then
      if [ "${shall_update_code}" = "yes" ]; then

        # Update Lambda function's code if requested

        aws lambda update-function-code \
        --function-name ${lambda_function_name} \
        --zip-file fileb://"${pkg_name}.zip"

        updated_code="yes"
      fi
    fi 
  done

  if [ "${updated_code}" != "yes" ]; then

    # Create the role for the Lambda function

    aws iam create-role --role-name "${lambda_function_name}_role" --assume-role-policy-document file://${role_trust_policy_path}
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --role-name "${lambda_function_name}_role"
    lambda_role_arn=$(aws iam list-roles | jq -r ".Roles[] | select(.RoleName==\"${lambda_function_name}_role\") | .Arn")
    sleep 10

    # Create the Lambda function

    aws lambda create-function \
    --function-name ${lambda_function_name} \
    --runtime "python3.6" \
    --role ${lambda_role_arn} \
    --handler ${lambda_function_name}.handler \
    --timeout 180 \
    --zip-file fileb://"${pkg_name}.zip"

  fi

  cd ${current_dir}
  rm -fr "${current_dir}/build"

}

set_cron() {

  # Set schedule

  aws events put-rule \
  --name "${lambda_function_name}_rule" \
  --schedule-expression "${schedule}"

  event_rule_arn=$(aws events list-rules | jq -r ".Rules[] | select(.Name==\"${lambda_function_name}_rule\") | .Arn")

  aws lambda add-permission \
  --function-name "${lambda_function_name}" \
  --statement-id "${lambda_function_name}_event" \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com \
  --source-arn "${event_rule_arn}"

  lambda_function_arn=$(aws lambda list-functions | jq -r ".Functions[] | select(.FunctionName==\"${lambda_function_name}\") | .FunctionArn")

  echo "[" > "${lambda_function_name}_rule_targets.json"
  echo "  {" >> "${lambda_function_name}_rule_targets.json"
  echo "    \"Id\": \"1\"," >> "${lambda_function_name}_rule_targets.json"
  echo "   \"Arn\": \"$lambda_function_arn\"" >> "${lambda_function_name}_rule_targets.json"
  echo "  }" >> "${lambda_function_name}_rule_targets.json"
  echo "]" >> "${lambda_function_name}_rule_targets.json"

  aws events put-targets \
  --rule "${lambda_function_name}_rule" \
  --targets file://"${lambda_function_name}_rule_targets.json"

  rm "${lambda_function_name}_rule_targets.json"

}


while getopts ":c:f:hu" opt; do
  case ${opt} in
    c) 
       schedule=${OPTARG}
       ;;
    h)
       print_help
       exit 0
       ;;
    u)
       shall_update_code="yes"
       ;;
    \?)
       echo "Invalid option: $OPTARG" 1>&2
       print_help
       exit 1
       ;;
    :)
       echo "Invalid option: $OPTARG requires an argument" 1>&2
       exit 1
       ;;
  esac
done

shift "$((OPTIND -1))"

if [ -z $1 ]; then
  print_help
  exit 1
fi

current_dir=$(pwd)
python_modules_path=$(find ${current_dir} -type d -name site-packages)
role_trust_policy_path="${current_dir}/role_trust_policy.json"

python_script=$1
lambda_function_name=$(echo ${python_script} | cut -d. -f1)

deploy_function

if [ "$(echo ${schedule} | cut -c 1-4)" = "cron" ]; then
  set_cron
fi

