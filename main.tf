provider "aws" {
    region = "us-east-1"
}

#--------------------------------STATE FILE------------------------------------------
terraform {
  cloud {
    organization = "humza3173"

    workspaces {
      tags = ["resume-backend"]
    }
  }
}

#---------------------------------LAMBDA-----------------------------------------------

# IAM Trust Policy Document for Lambda
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create IAM Role with Trust Relationship for Lambda
resource "aws_iam_role" "dynamo_full_access" {
  name               = "DynamoFullAccess"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Attach AmazonDynamoDBFullAccess Managed Policy to the Role
resource "aws_iam_role_policy_attachment" "dynamodb_full_access_attachment" {
  role       = aws_iam_role.dynamo_full_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}



resource "aws_lambda_function" "update_visits" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_update_visits.zip"
  function_name = "update_visits"
  role          = aws_iam_role.dynamo_full_access.arn
  handler       = "lambda_update_visits.lambda_handler"
  runtime = "python3.12"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_visits.function_name
  principal     = "apigateway.amazonaws.com"

  // The source ARN is the ARN of the API Gateway method/execution that will invoke the Lambda function.
  // In this case, it's constructed from the rest_api_id and the resource's path.
  // You may need to adjust the source_arn to match the path of your specific method.
  // Make sure to use stage variables or a specific stage if necessary.
  source_arn = "${aws_api_gateway_rest_api.MyPortfolioAPI.execution_arn}/*/*"
}

#----------------------------------API GATEWAY------------------------------------------

resource "aws_api_gateway_rest_api" "MyPortfolioAPI" {
  name        = "humza-resume-api"
  description = "This is a sample API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_method" "MyPortfolioMethod" {
  rest_api_id   = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id   = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "response_200" {
  depends_on = [
        aws_api_gateway_method.MyPortfolioMethod
  ]
    
  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioMethod.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration" "MyPortfolioIntegration" {
  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioMethod.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.update_visits.arn}/invocations"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
    depends_on = [
        aws_api_gateway_integration.MyPortfolioIntegration
    ]


  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_templates = {
    "application/json" = ""
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}


resource "aws_api_gateway_method" "MyPortfolioOptions" {
  rest_api_id   = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id   = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "MyPortfolioOptionsResponse200" {
  depends_on = [ aws_api_gateway_method.MyPortfolioOptions ]

  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioOptions.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}


resource "aws_api_gateway_integration" "MyPortfolioOptionsIntegration" {
  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioOptions.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}


resource "aws_api_gateway_integration_response" "MyPortfolioOptionsIntegrationResponse" {
  depends_on = [ aws_api_gateway_integration.MyPortfolioOptionsIntegration ]

  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  resource_id = aws_api_gateway_rest_api.MyPortfolioAPI.root_resource_id
  http_method = aws_api_gateway_method.MyPortfolioOptions.http_method
  status_code = aws_api_gateway_method_response.MyPortfolioOptionsResponse200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,PUT'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}


resource "aws_api_gateway_deployment" "my_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.MyPortfolioIntegration,
    aws_api_gateway_integration.MyPortfolioOptionsIntegration
  ]
  
  rest_api_id = aws_api_gateway_rest_api.MyPortfolioAPI.id
  
  # A unique string that changes on each redeployment
  stage_name  = "v1"
  
  # Optionally, include a description and/or stage description
  description = "Deployment for the MyPortfolioAPI"
  
  # Triggers redeployment when the Swagger file or a method changes
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.MyPortfolioAPI.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "api_gateway_stage_url" {
  depends_on = [ aws_api_gateway_deployment.my_api_deployment ]
  value = aws_api_gateway_deployment.my_api_deployment.invoke_url
}

#------------------------------DynamoDB---------------------------------------------
resource "aws_dynamodb_table" "db_visit_count" {
  name           = "db_visit_count"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "ref_id"

  attribute {
    name = "ref_id"
    type = "N"
  }
}

#--------------------------SNS-----------------------------------------------

resource "aws_sns_topic" "pagerduty-aws" {
  name = "pagerduty-aws-humza-resume2"
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  depends_on = [ aws_sns_topic.pagerduty-aws ]
  topic_arn = aws_sns_topic.pagerduty-aws.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/c5f6b2c1e6f44500c0949eb13f39da80/enqueue"
}

#-----------------------CloudWatch------------------------------------------

resource "aws_cloudwatch_metric_alarm" "update_counter_error_alarm" {
  alarm_name                = "update_counter_error2"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = 360
  statistic                 = "Sum"
  threshold                 = 0
  alarm_description         = "This metric monitors lambda update visitor function for errors and reports it go pagerduty"
  alarm_actions             = [aws_sns_topic.pagerduty-aws.arn]

  dimensions = {
    FunctionName = "update_visits"
  }
}

resource "aws_cloudwatch_metric_alarm" "update_counter_duration_alarm" {
  alarm_name                = "update_counter_duration2"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Duration"
  namespace                 = "AWS/Lambda"
  period                    = 360
  statistic                 = "Sum"
  threshold                 = 5000
  alarm_description         = "This metric monitors lambda update visitor function for how long it takes to execute, and if too long will report it to pagerduty"
  alarm_actions             = [aws_sns_topic.pagerduty-aws.arn]

  dimensions = {
    FunctionName = "update_visits"
  }
}

resource "aws_cloudwatch_metric_alarm" "update_counter_invocation_alarm" {
  alarm_name                = "update_counter_invocation2"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Invocations"
  namespace                 = "AWS/Lambda"
  period                    = 10
  statistic                 = "Sum"
  threshold                 = 10
  alarm_description         = "This metric monitors lambda update visitor function for how long it takes to execute, and if too long will report it to pagerduty"
  alarm_actions             = [aws_sns_topic.pagerduty-aws.arn]

  dimensions = {
    FunctionName = "update_visits"
  }
}