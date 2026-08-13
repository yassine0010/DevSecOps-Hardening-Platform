require('dotenv').config();
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const cors = require('cors');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET;
const SHARED_SERVICE_KEY = process.env.SHARED_SERVICE_KEY;

// Database configuration must be provided explicitly in production
const DB_HOST = process.env.DB_HOST;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_NAME = process.env.DB_NAME;
const DB_PORT = process.env.DB_PORT;

// CORS: require explicit allowed origins in production
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS; // comma separated list

let pool;

// Validate critical configuration and fail fast
function validateConfig() {
    const missing = [];
    if (!JWT_SECRET) missing.push('JWT_SECRET');
    if (!SHARED_SERVICE_KEY) missing.push('SHARED_SERVICE_KEY');
    if (!DB_HOST) missing.push('DB_HOST');
    if (!DB_USER) missing.push('DB_USER');
    if (!DB_PASSWORD) missing.push('DB_PASSWORD');
    if (!DB_NAME) missing.push('DB_NAME');
    if (!DB_PORT) missing.push('DB_PORT');
    if (!ALLOWED_ORIGINS) missing.push('ALLOWED_ORIGINS');

    if (missing.length > 0) {
        console.error('FATAL: Missing required environment variables:', missing.join(', '));
        process.exit(1);
    }
}

// Validate config and configure CORS before any routes are registered
validateConfig();

const origins = ALLOWED_ORIGINS.split(',').map(s => s.trim()).filter(Boolean);
app.use(cors({
    origin: function(origin, callback) {
        // allow requests with no origin (like mobile apps or curl)
        if (!origin) return callback(null, true);
        if (origins.indexOf(origin) !== -1) {
            return callback(null, true);
        } else {
            return callback(new Error('Origin not allowed by CORS'));
        }
    }
}));

const router = express.Router();

router.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) return res.status(400).json({ error: 'Username and password required' });

        const hashedPassword = await bcrypt.hash(password, 10);
        
        const result = await pool.query(
            'INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id',
            [username, hashedPassword]
        );
        
        res.status(201).json({ message: 'User registered successfully', userId: result.rows[0].id });
    } catch (err) {
        if (err.code === '23505') return res.status(400).json({ error: 'Username already exists' });
        console.error('Registration error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Service-to-service key validation middleware
function verifyServiceKey(req, res, next) {
    const key = req.headers['x-service-key'] || req.headers['x-api-key'];
    if (!key || key !== SHARED_SERVICE_KEY) {
        return res.status(403).json({ error: 'Forbidden - invalid service key' });
    }
    next();
}

// Internal endpoint to validate service key (example)
router.get('/internal/validate', verifyServiceKey, (req, res) => {
    res.json({ status: 'ok', internal: true });
});

router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
        
        if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid credentials' });
        
        const user = result.rows[0];
        const match = await bcrypt.compare(password, user.password_hash);
        
        if (!match) return res.status(401).json({ error: 'Invalid credentials' });
        
        const token = jwt.sign({ userId: user.id, username: user.username }, JWT_SECRET, { expiresIn: '1h' });
        res.json({ token, userId: user.id, username: user.username });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }

});

router.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api/auth', router);
app.use('/', router);

// Initialize DB pool with retry logic (exponential backoff)
async function initDbWithRetry(retries = 3, delayMs = 500) {
    for (let attempt = 1; attempt <= retries; attempt++) {
        try {
            pool = new Pool({
                host: DB_HOST,
                user: DB_USER,
                password: DB_PASSWORD,
                database: DB_NAME,
                port: Number(DB_PORT),
                max: 10
            });

            // test a connection
            const client = await pool.connect();
            client.release();
            return;
        } catch (err) {
            console.error(`DB connection attempt ${attempt} failed:`, err.message || err);
            if (attempt === retries) throw err;
            await new Promise(r => setTimeout(r, delayMs * attempt));
        }
    }
}

// Start sequence: init DB then start listening
async function start() {
    try {
        await initDbWithRetry(5, 500);
    } catch (err) {
        console.error('FATAL: Could not initialize database connection. Exiting.');
        console.error(err);
        process.exit(1);
    }

    app.listen(PORT, () => {
        console.log(`Auth Service running on port ${PORT}`);
    });
}

start();
