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

module "bucket_a" {
    source = "./modules/cloudwatch2sns"
    log_group_source_name = aws_cloudwatch_log_group.sample_error_log_source.name
    log_group_source_arn = aws_cloudwatch_log_group.sample_error_log_source.arn
    sns_topic_target = aws_sns_topic.sample_error_log_destination_sns.arn
}

output "log_group" {
    value = aws_cloudwatch_log_group.sample_error_log_source.name
}
