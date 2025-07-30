exports.handler = async (event, context) => {
    console.log("Received event:", JSON.stringify(event, null, 2));

    const responseMessage = "Hello from Lambda! Your request was successful.";
    const imUrl = "https://d2ryl8hnh8mi25.cloudfront.net/week4.jpg";

    return {
        statusCode: 200,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify({
            message: responseMessage,
            imUrl
        }),
    };
};
