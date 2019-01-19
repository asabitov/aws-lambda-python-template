#!/bin/bash

# Delete the Lambda function if needed

python_script=$1
lambda_function_name=$(echo ${python_script} | cut -d. -f1)

aws events remove-targets --rule "${lambda_function_name}_rule" --ids "1"
aws events delete-rule --name "${lambda_function_name}_rule"
aws lambda delete-function --function-name ${lambda_function_name}
aws iam detach-role-policy --role-name "${lambda_function_name}_role" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-role --role-name ${lambda_function_name}_role

