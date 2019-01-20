#!/bin/bash

print_help() {

  echo
  echo "Delete an AWS Lambda function and its dependencies."
  echo
  echo "Usage: delete.sh [-c] function"
  echo
  echo "The 'function' is an AWS Lambda function to be deleted."
  echo
  echo "  -c    Also delete a cron job of the function."
  echo
  echo "  -h    Print a help message and exit."
  echo

}


while getopts ":ch" opt; do
  case ${opt} in
    c)
       shall_delete_cron="yes"
       ;;
    h)
       print_help
       exit 0
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

lambda_function_name=$1

if [ -z $1 ]; then
  print_help
  exit 1
fi

if [ "${shall_delete_cron}" = "yes" ]; then
  aws events remove-targets --rule "${lambda_function_name}_rule" --ids "1"
  aws events delete-rule --name "${lambda_function_name}_rule"
fi

aws lambda delete-function --function-name ${lambda_function_name}
aws iam detach-role-policy --role-name "${lambda_function_name}_role" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-role --role-name ${lambda_function_name}_role

