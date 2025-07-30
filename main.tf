################################################################################
# 1. IAM ROLE FOR LAMBDA
#
# This section creates the basic execution role for the Lambda function.
# Note: Logging permissions have been removed as requested.
################################################################################

resource "aws_iam_role" "lambda_exec_role" {
  name = "api-gateway-lambda-exec-role"

  # The trust policy allows the Lambda service to assume this role.
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
#
# This defines the Lambda function itself.
# It references the IAM role and packages the Node.js code from a local
# directory.
################################################################################

# This data source archives your Node.js code into a .zip file, which is
# the required format for Lambda deployment.
data "archive_file" "lambda_zip" {
  type = "zip"
  # This points to your Node.js handler file.
  # Create a folder named 'app' and place your 'index.js' inside it.
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/lambda_payload.zip"
}

resource "aws_lambda_function" "api_handler_lambda" {
  # The .zip file created above.
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "MyApiHandlerFunction"
  role          = aws_iam_role.lambda_exec_role.arn
  # The handler value is "file.export". For Node.js, this means the 'handler'
  # function exported from the 'index.js' file.
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Specify the Node.js runtime.
  runtime = "nodejs18.x"

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}


################################################################################
# 3. API GATEWAY & INTEGRATION (ON ROOT PATH)
#
# This section creates the public-facing REST API and connects a GET route
# directly to the Lambda function at the root '/' level.
################################################################################

# Create the main REST API container.
resource "aws_api_gateway_rest_api" "app_api" {
  name        = "ServerlessAppApi"
  description = "API for handling application requests"
}

# Define the GET method on the root ("/") resource of the API.
resource "aws_api_gateway_method" "get_method" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id
  # Point directly to the API's root resource ID.
  resource_id   = aws_api_gateway_rest_api.app_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE" # No authorization required for this endpoint.
}

# This is the core integration that connects the GET method to the Lambda function.
# It uses AWS_PROXY integration for full control in the Lambda code.
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id
  # Point directly to the API's root resource ID.
  resource_id = aws_api_gateway_rest_api.app_api.root_resource_id
  http_method = aws_api_gateway_method.get_method.http_method

  integration_http_method = "POST" # Must be POST for Lambda integration
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler_lambda.invoke_arn
}

# This permission allows API Gateway to invoke your Lambda function.
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The source ARN is updated to grant permission from the root path's GET method.
  source_arn = "${aws_api_gateway_rest_api.app_api.execution_arn}/*/${aws_api_gateway_method.get_method.http_method}"
}

# A deployment is required to make the API changes live.
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.app_api.id

  # The trigger ensures that a new deployment happens whenever the API definition changes.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.app_api.root_resource_id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# A stage is a snapshot of your deployment (e.g., dev, staging, prod).
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.app_api.id
  stage_name    = "v1"
}


################################################################################
# 4. OUTPUTS
#
# This output will display the final URL of your API endpoint after you run
# 'terraform apply'.
################################################################################

output "api_invoke_url" {
  description = "The base URL to invoke the API stage."
  # The URL now points to the root of the stage.
  value = aws_api_gateway_stage.api_stage.invoke_url
}
