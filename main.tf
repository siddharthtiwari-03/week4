################################################################################
# PROVIDER (Updated region to ap-south-1)
################################################################################

provider "aws" {
  region = "ap-south-1" # Mumbai region
}


################################################################################
# 1. IAM ROLE FOR LAMBDA
################################################################################

resource "aws_iam_role" "lambda_exec_role" {
  name = "api-gateway-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


################################################################################
# 2. LAMBDA FUNCTION
################################################################################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_lambda_function" "api_handler_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "MyApiHandlerFunction"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}


################################################################################
# 3. API GATEWAY & INTEGRATION
################################################################################

resource "aws_api_gateway_rest_api" "app_api" {
  name        = "ServerlessAppApi"
  description = "API for handling application requests"
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.app_api.id
  resource_id   = aws_api_gateway_rest_api.app_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.app_api.id
  resource_id             = aws_api_gateway_rest_api.app_api.root_resource_id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # Allow all methods from all stages
  source_arn = "${aws_api_gateway_rest_api.app_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.app_api.root_resource_id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.lambda_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.app_api.id
  stage_name    = "v1"
}


################################################################################
# 4. OUTPUT
################################################################################

output "api_invoke_url" {
  description = "The base URL to invoke the API stage."
  value       = aws_api_gateway_stage.api_stage.invoke_url
}
