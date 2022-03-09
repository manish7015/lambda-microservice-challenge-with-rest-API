
data "archive_file" "lambda-zip" {
  type        = "zip"
  source_dir  = "lambda"
  output_path = "lambda.zip"
}

# Sending logs to CloudWatch
resource "aws_iam_role_policy" "cloudwatch" {
  name   = "cloudwatch"
  role   = aws_iam_role.lambda-iam-role.id
  policy = file("iam/lambda-cloudwatch-policy.json")
}

# SSM policy for get/put operations
resource "aws_iam_role_policy" "ssm" {
  name   = "ssm"
  role   = aws_iam_role.lambda-iam-role.id
  policy = file("iam/lambda-ssm-policy.json")
}

# Creating lambda assume role
resource "aws_iam_role" "lambda-iam-role" {
  name               = "lambda-iam-role-mk"
  assume_role_policy = file("iam/lambda-assume-policy.json")
}

# Creating lambda function
resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "lambda-function"
  role             = aws_iam_role.lambda-iam-role.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime          = "python3.8"

  tags = {
    CreatedBy = "Manish"
  }
}

# Creating REST API
resource "aws_api_gateway_rest_api" "lambda_api" {
  name        = "lambda-iac-api"
  description = "Terraform lambda-iac-api"
  tags = {
    CreatedBy = "Manish"
  }
}

# Creating API resource 
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  parent_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  path_part   = "{proxy+}"
}

# Creating method and secure API mentioning  api_key_required = true
resource "aws_api_gateway_method" "proxy" {
  rest_api_id      = aws_api_gateway_rest_api.lambda_api.id
  resource_id      = aws_api_gateway_resource.proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

# Integrate API
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Integrate API  method for root resoruce
resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  resource_id   = aws_api_gateway_rest_api.lambda_api.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

# Integrate API for root resoruce
resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Creating API Stage
resource "aws_api_gateway_stage" "development" {
  deployment_id = aws_api_gateway_deployment.lambda.id
  rest_api_id   = aws_api_gateway_rest_api.lambda_api.id
  stage_name    = "development"
}

# Deploy API
resource "aws_api_gateway_deployment" "lambda" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]
  rest_api_id = aws_api_gateway_rest_api.lambda_api.id
}


# Granting permission to lambda function
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lambda_api.execution_arn}/*/*"
}


# Creating usage plan 
resource "aws_api_gateway_usage_plan" "usage_plan" {
  name         = "my-usage-plan"
  description  = "my description"
  product_code = "MYCODE"

  api_stages {
    api_id = aws_api_gateway_rest_api.lambda_api.id
    stage  = aws_api_gateway_stage.development.stage_name
  }


  quota_settings {
    limit  = 20
    offset = 2
    period = "WEEK"
  }

  throttle_settings {
    burst_limit = 5
    rate_limit  = 10
  }
}

# Creating API Key
resource "aws_api_gateway_api_key" "api-key" {
  name = "demo"
}

# Attaching API Key to usage plan 
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.api-key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}

