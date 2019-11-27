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

data "archive_file" "lambda_zip_inline" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
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
  })
}

exports.handler = async (event) => {
	try {
		var payload = new Buffer(event.awslogs.data, 'base64');
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

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

resource "aws_iam_policy" "lambda_logging" {
  name = "lambda_logging"
  path = "/"
  description = "IAM policy for logging/sending to SNS from a lambda"

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
      "Resource": "${aws_sns_topic.error_logs.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/test"
  retention_in_days = 14
}

resource "aws_lambda_function" "lambda_zip_inline" {
  filename         = data.archive_file.lambda_zip_inline.output_path
  source_code_hash = data.archive_file.lambda_zip_inline.output_base64sha256
  function_name    = "test"
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "nodejs8.10"
  handler          =  "exports.handler"
  depends_on       = [aws_iam_role_policy_attachment.lambda_logs, aws_cloudwatch_log_group.example]
  environment {
    variables = {
      SNS_TOPIC = aws_sns_topic.error_logs.arn
    }
  }
}

resource "aws_sns_topic" "error_logs" {
  name = "test-error-logs"
}

resource "aws_cloudwatch_log_group" "source" {
  name              = "/aws/lambda/testsource"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_zip_inline.function_name
  principal     = "logs.eu-central-1.amazonaws.com"
  source_arn    = aws_cloudwatch_log_group.source.arn
}

resource "aws_cloudwatch_log_subscription_filter" "test_lambdafunction_logfilter" {
  name            = "test_lambdafunction_logfilter"
  log_group_name  = aws_cloudwatch_log_group.source.name
  filter_pattern  = ""
  destination_arn = aws_lambda_function.lambda_zip_inline.arn
}
