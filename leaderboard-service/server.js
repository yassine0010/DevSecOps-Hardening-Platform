require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3003;
const JWT_SECRET = process.env.JWT_SECRET;
const SHARED_SERVICE_KEY = process.env.SHARED_SERVICE_KEY;

const DB_HOST = process.env.DB_HOST;
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_NAME = process.env.DB_NAME;
const DB_PORT = process.env.DB_PORT;
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS; // comma separated
const PUZZLE_SERVICE_URL = process.env.PUZZLE_SERVICE_URL;

let pool;

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
    if (!PUZZLE_SERVICE_URL) missing.push('PUZZLE_SERVICE_URL');

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
        if (!origin) return callback(null, true);
        if (origins.indexOf(origin) !== -1) return callback(null, true);
        return callback(new Error('Origin not allowed by CORS'));
    }
}));

function authenticate(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const payload = jwt.verify(token, JWT_SECRET);
        req.user = payload;
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
}

// Service-to-service key validation middleware
function verifyServiceKey(req, res, next) {
    const key = req.headers['x-service-key'] || req.headers['x-api-key'];
    if (!key || key !== SHARED_SERVICE_KEY) {
        return res.status(403).json({ error: 'Forbidden - invalid service key' });
    }
    next();
}

const router = express.Router();

// Internal endpoint to validate service key (example)
router.get('/internal/validate', verifyServiceKey, (req, res) => {
    res.json({ status: 'ok', internal: true });
});

router.get('/leaderboard', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM leaderboard LIMIT 100');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Enriched leaderboard endpoint: returns leaderboard plus today's puzzle (internal call)
router.get('/leaderboard/enriched', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM leaderboard LIMIT 100');

        let currentPuzzle = null;
        try {
            // use global fetch (Node 18+); include shared service key header
            const resp = await fetch(`${PUZZLE_SERVICE_URL}/api/puzzle/internal/puzzles/daily`, {
                headers: { 'X-Service-Key': SHARED_SERVICE_KEY }
            });
            if (resp.ok) {
                currentPuzzle = await resp.json();
            } else {
                console.error('Puzzle service returned', resp.status);
            }
        } catch (err) {
            console.error('Error fetching puzzle service:', err);
        }

        res.json({ leaderboard: result.rows, currentPuzzle });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/leaderboard/:category', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM leaderboard WHERE category = $1 ORDER BY score DESC LIMIT 100', [req.params.category]);
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// INTENTIONAL IDOR VULNERABILITY
router.get('/submissions/:id', authenticate, async (req, res) => {
    try {
        const submissionId = req.params.id;
        const result = await pool.query('SELECT * FROM submissions WHERE id = $1', [submissionId]);
        
        if (result.rows.length === 0) return res.status(404).json({ error: 'Submission not found' });
        
        // VULNERABILITY: returning submission regardless of who it belongs to
        res.json(result.rows[0]);
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.put('/submissions/:id', authenticate, async (req, res) => {
    try {
        const submissionId = req.params.id;
        const { time_taken } = req.body;
        
        // VULNERABILITY: updating submission regardless of who it belongs to
        const result = await pool.query(
            'UPDATE submissions SET time_taken = $1 WHERE id = $2',
            [time_taken, submissionId]
        );
        
        if (result.rowCount === 0) return res.status(404).json({ error: 'Submission not found' });
        res.json({ message: 'Submission updated successfully' });
    } catch (err) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

router.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api/leaderboard', router);
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
        console.log(`Leaderboard Service running on port ${PORT}`);
    });
}

start();
