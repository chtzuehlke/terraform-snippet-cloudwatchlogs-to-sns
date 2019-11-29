Demo: How to automatically route ERROR messages from a CloudWatch log group to a SNS topic.

Steps:

    terraform init
    terraform apply --auto-approve

    ./subscribe.sh "your@email.com"
    #go to your inbox and confirm your subscription

    ./send.sh "ERROR hello world"
    #go to your inbox and verify the notification mail

    terraform destroy --auto-approve
