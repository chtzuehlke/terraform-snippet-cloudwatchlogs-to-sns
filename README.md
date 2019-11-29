Demo: How to automatically route ERROR messages from a CloudWatch log group to a SNS topic.

Steps:

    terraform init
    terraform apply --auto-approve

    ./subscribe.sh "your@email.com"
    #confirm your subscription

    ./send.sh "ERROR hello world"

    terraform destroy --auto-approve
