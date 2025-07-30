/**
 * This is the main handler function that API Gateway will invoke.
 *
 * @param {object} event - Contains all the request data from API Gateway (headers, query params, etc.).
 * @param {object} context - Contains runtime information about the invocation, function, and execution environment.
 * @returns {object} A response object that API Gateway will convert into an HTTP response.
 */
exports.handler = async (event, context) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    // Your business logic goes here.
    // For example, you could query a database or call another service.

    const responseMessage = "Hello from Lambda! Your request was successful.";

    const imUrl = `https://d2ryl8hnh8mi25.cloudfront.net/week4.jpg`

    // The response object MUST have this structure for AWS_PROXY integration.
    const response = {
        // HTTP status code
        statusCode: 200,
        // CORS headers can be added here if needed
        headers: {
            "Content-Type": "application/json",
        },
        // The response body MUST be a JSON-stringified string.
        body: JSON.stringify({
            message: responseMessage,
            // You can access query string parameters like this:
            // example: /mydata?name=John
            imUrl
            // nameQueryParam: event.queryStringParameters ? event.queryStringParameters.name : 'No name provided',
        }),
    };

    return response;
};
