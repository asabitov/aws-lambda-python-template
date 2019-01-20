# aws-lambda-python-template
AWS Lambda template for a Python script.

### Deploy a Python script to AWS Lambda.
```
Usage: deploy.sh [-c schedule] script

The 'script' is a Python script to be deployed as a Lambda function.

  -c    This option sets a cron job. For example, use this command to set a job, which repeats every hour:
        deploy.sh script -c 'cron(0 * * * ? *)'

  -h    Print a help message and exit.

  -u    Update Lambda function's code if the function already exists.
```
### Delete an AWS Lambda function and its dependencies.
```
Usage: delete.sh [-c] function

The 'function' is an AWS Lambda function to be deleted.

  -c    Also delete a cron job of the function.

  -h    Print a help message and exit.
```
