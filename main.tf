provider "aws" {
    version = "~> 2.0"
    region  = "eu-central-1"
}

terraform {
    backend "s3" {
        bucket = "terraformchtzbucket"
        key    = "bucketsample/terraform.tfstate"
        region = "eu-central-1"
    }
}

resource "aws_sns_topic" "sample_error_log_destination_sns" {
  name = "sample_error_log_destination"
}

resource "aws_cloudwatch_log_group" "sample_error_log_source" {
  name              = "sample_error_log_source"
  retention_in_days = 14
}

module "example" {
    source = "./modules/cloudwatch2sns"
    log_group_source = aws_cloudwatch_log_group.sample_error_log_source.name
    sns_topic_target = aws_sns_topic.sample_error_log_destination_sns.arn
}

output "log_group" {
    value = aws_cloudwatch_log_group.sample_error_log_source.name
}

output "sns_topic" {
  value = aws_sns_topic.sample_error_log_destination_sns.arn
}
