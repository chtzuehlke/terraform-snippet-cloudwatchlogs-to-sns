variable "lambda_name" {
    type = string
    default = "cloudwatch_logs_to_sns"
}

variable "log_group_source" {
    type = string
}

variable "log_filter_pattern" {
    type = string
    default = "ERROR"
}

variable "sns_topic_target" {
    type = string
}

data "aws_cloudwatch_log_group" "log_group_source" {
  name = var.log_group_source
}

data "archive_file" "cloudwatch_logs_to_sns_lambda" {
  type        = "zip"
  output_path = "/tmp/cloudwatch_logs_to_sns_lambda.zip"
  source {
    content  = <<EOF
var AWS = require('aws-sdk');
var sns = new AWS.SNS();
var zlib = require('zlib');

const unzip = (payload) => {
  return new Promise((resolve, reject) => {
  	zlib.gunzip(payload, function(e, result) {
        if (e) { 
            return reject(e)
        } else {
            resolve(JSON.parse(result.toString('ascii')));
        }
    })
  });
}

exports.handler = async (event) => {
	try {
		let payload = new Buffer(event.awslogs.data, 'base64');
	  let result = await unzip(payload);		
		await sns.publish({
		    TopicArn: process.env.SNS_TOPIC,
		    Message: JSON.stringify(result, null, 2),
        Subject: "Message from CloudWatch Logs"
		}).promise();
	}
	catch (e) {
		console.log(e);
		return e;
	}
	return "ok";
};
EOF
    filename = "exports.js"
  }
}

resource "aws_iam_role" "cloudwatch_logs_to_sns_lambda_role" {
  name = "${var.lambda_name}_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "cloudwatch_logs_to_sns_lambda_policy" {
  name = "${var.lambda_name}_policy"
  path = "/"
  description = "IAM policy for logging and publishing to SNS"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:*"
      ],
      "Resource": "${var.sns_topic_target}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_to_sns_lambda_policy_attachment" {
  role = aws_iam_role.cloudwatch_logs_to_sns_lambda_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_to_sns_lambda_policy.arn
}

resource "aws_cloudwatch_log_group" "cloudwatch_logs_to_sns_lambda_logs" {
  name              = "/lambda/${var.lambda_name}"
  retention_in_days = 7
}

resource "aws_lambda_function" "cloudwatch_logs_to_sns_lambda" {
  filename         = data.archive_file.cloudwatch_logs_to_sns_lambda.output_path
  source_code_hash = data.archive_file.cloudwatch_logs_to_sns_lambda.output_base64sha256
  function_name    = var.lambda_name
  role             = aws_iam_role.cloudwatch_logs_to_sns_lambda_role.arn
  runtime          = "nodejs8.10"
  handler          =  "exports.handler"
  depends_on       = [aws_iam_role_policy_attachment.cloudwatch_logs_to_sns_lambda_policy_attachment, 
                      aws_cloudwatch_log_group.cloudwatch_logs_to_sns_lambda_logs]
  environment {
    variables = {
      SNS_TOPIC = var.sns_topic_target
    }
  }
}

data "aws_region" "current" {}

resource "aws_lambda_permission" "cloudwatch_logs_to_sns_lambda_cloudwatch_permissions" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_logs_to_sns_lambda.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn    = data.aws_cloudwatch_log_group.log_group_source.arn
}

resource "aws_cloudwatch_log_subscription_filter" "sample_error_log_filter" {
  name            = "${var.lambda_name}_logfilter"
  log_group_name  = data.aws_cloudwatch_log_group.log_group_source.name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_lambda_function.cloudwatch_logs_to_sns_lambda.arn
}
