const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');

// Create Secrets Manager client
const secretsManager = new AWS.SecretsManager();

// Cache connection to reuse across invocations
let cachedConnection = null;
let cachedDbConfig = null;

/**
 * Get database credentials from AWS Secrets Manager
 */
async function getDbCredentials() {
    if (cachedDbConfig) {
        return cachedDbConfig;
    }

    try {
        const secret = await secretsManager.getSecretValue({
            SecretId: process.env.DB_SECRET_ARN
        }).promise();

        cachedDbConfig = JSON.parse(secret.SecretString);
        return cachedDbConfig;
    } catch (error) {
        console.error('Error retrieving database credentials:', error);
        throw error;
    }
}

/**
 * Create or reuse database connection
 */
async function getDbConnection() {
    // Return cached connection if it exists and is still valid
    if (cachedConnection) {
        try {
            await cachedConnection.ping();
            return cachedConnection;
        } catch (error) {
            console.log('Cached connection is invalid, creating new connection');
            cachedConnection = null;
        }
    }

    try {
        const dbConfig = await getDbCredentials();
        
        // Create new connection
        cachedConnection = await mysql.createConnection({
            host: dbConfig.host,
            port: dbConfig.port,
            user: dbConfig.username,
            password: dbConfig.password,
            database: dbConfig.database,
            connectTimeout: 10000,
            acquireTimeout: 10000,
            timeout: 10000,
            // SSL configuration (recommended for RDS)
            ssl: {
                rejectUnauthorized: false
            }
        });

        console.log('Successfully connected to database');
        return cachedConnection;
    } catch (error) {
        console.error('Error connecting to database:', error);
        throw error;
    }
}

/**
 * Sample function to fetch a record from database
 * Replace this with your actual query logic
 */
async function fetchRecord(connection, recordId = null) {
    try {
        let query, params;
        
        if (recordId) {
            // Fetch specific record by ID
            query = 'SELECT * FROM your_table WHERE id = ?';
            params = [recordId];
        } else {
            // Fetch all records or add your custom logic
            query = 'SELECT * FROM your_table LIMIT 10';
            params = [];
        }

        const [rows] = await connection.execute(query, params);
        return rows;
    } catch (error) {
        console.error('Error executing query:', error);
        throw error;
    }
}

/**
 * Main Lambda handler function
 */
exports.handler = async (event, context) => {
    // Set context.callbackWaitsForEmptyEventLoop to false to prevent Lambda from waiting
    // for the database connection to close
    context.callbackWaitsForEmptyEventLoop = false;

    try {
        console.log('Received event:', JSON.stringify(event, null, 2));

        // Get database connection
        const connection = await getDbConnection();

        // Extract parameters from the event (query string, path parameters, etc.)
        const recordId = event.queryStringParameters?.id || null;

        // Fetch record(s) from database
        const records = await fetchRecord(connection, recordId);

        // Return successful response
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*', // Configure CORS as needed
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
            },
            body: JSON.stringify({
                success: true,
                data: records,
                count: records.length,
                message: recordId ? `Record with ID ${recordId}` : 'All records'
            })
        };

    } catch (error) {
        console.error('Lambda execution error:', error);

        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: false,
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : 'Something went wrong'
            })
        };
    }
};