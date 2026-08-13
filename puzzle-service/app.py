import os
import sys
import jwt
from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
PORT = int(os.environ.get('PORT', 3002))
JWT_SECRET = os.environ.get('JWT_SECRET')
SHARED_SERVICE_KEY = os.environ.get('SHARED_SERVICE_KEY')

# Database config (must be provided explicitly)
DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
DB_NAME = os.environ.get('DB_NAME')
DB_PORT = os.environ.get('DB_PORT')
ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS')

# Fail fast if crucial secrets or config are missing
missing = []
if not JWT_SECRET:
    missing.append('JWT_SECRET')
if not SHARED_SERVICE_KEY:
    missing.append('SHARED_SERVICE_KEY')
if not DB_HOST:
    missing.append('DB_HOST')
if not DB_USER:
    missing.append('DB_USER')
if not DB_PASSWORD:
    missing.append('DB_PASSWORD')
if not DB_NAME:
    missing.append('DB_NAME')
if not DB_PORT:
    missing.append('DB_PORT')
if not ALLOWED_ORIGINS:
    missing.append('ALLOWED_ORIGINS')

if missing:
    print('FATAL: Missing required environment variables: ' + ', '.join(missing), file=sys.stderr)
    sys.exit(1)

# Configure CORS using allowed origins
origins = [o.strip() for o in ALLOWED_ORIGINS.split(',') if o.strip()]
CORS(app, origins=origins)

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        dbname=DB_NAME,
        port=int(DB_PORT)
    )

def init_db_with_retry(retries=3, delay_secs=0.5):
    import time
    attempt = 0
    while attempt < retries:
        try:
            conn = get_db_connection()
            conn.close()
            return True
        except Exception as e:
            attempt += 1
            print(f'DB connection attempt {attempt} failed: {e}', file=sys.stderr)
            time.sleep(delay_secs * attempt)
    return False

def authenticate():
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    token = auth_header.split(' ')[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def verify_service_key():
    key = request.headers.get('X-Service-Key') or request.headers.get('X-API-Key')
    return key and key == SHARED_SERVICE_KEY

@app.route('/puzzles', methods=['GET'])
@app.route('/api/puzzle/puzzles', methods=['GET'])
def get_puzzles():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT id, type, difficulty, grid_data FROM puzzles')
    puzzles = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(puzzles)

@app.route('/puzzles/daily', methods=['GET'])
@app.route('/api/puzzle/puzzles/daily', methods=['GET'])
def get_daily_puzzle():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT id, type, difficulty, grid_data FROM puzzles ORDER BY id DESC LIMIT 1')
    puzzle = cursor.fetchone()
    cursor.close()
    conn.close()
    if puzzle:
        return jsonify(puzzle)
    return jsonify({'error': 'No puzzles found'}), 404

@app.route('/puzzles/<puzzle_id>', methods=['GET'])
@app.route('/api/puzzle/puzzles/<puzzle_id>', methods=['GET'])
def get_puzzle(puzzle_id):
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT id, type, difficulty, grid_data FROM puzzles WHERE id = %s', (puzzle_id,))
    puzzle = cursor.fetchone()
    cursor.close()
    conn.close()
    if puzzle:
        return jsonify(puzzle)
    return jsonify({'error': 'Puzzle not found'}), 404

@app.route('/puzzles/<puzzle_id>/submit', methods=['POST'])
@app.route('/api/puzzle/puzzles/<puzzle_id>/submit', methods=['POST'])
def submit_answer(puzzle_id):
    user = authenticate()
    if not user:
        return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.json
    submitted_answer = data.get('answer', '')
    time_taken = data.get('time_taken', 0)
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # INTENTIONAL SQL INJECTION VULNERABILITY
    query = f"SELECT id FROM puzzles WHERE id = {puzzle_id} AND correct_answer = '{submitted_answer}'"
    
    try:
        cursor.execute(query)
        result = cursor.fetchone()
        is_correct = bool(result)
        
        cursor.execute(
            'INSERT INTO submissions (user_id, puzzle_id, submitted_answer, is_correct, time_taken) VALUES (%s, %s, %s, %s, %s)',
            (user['userId'], puzzle_id, submitted_answer, is_correct, time_taken)
        )
        conn.commit()
    except Exception as e:
        cursor.close()
        conn.close()
        return jsonify({'error': str(e)}), 500
        
    cursor.close()
    conn.close()
    
    return jsonify({
        'is_correct': is_correct,
        'message': 'Correct answer!' if is_correct else 'Incorrect answer'
    })

@app.route('/health', methods=['GET'])
@app.route('/api/puzzle/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})


@app.route('/internal/validate', methods=['GET'])
@app.route('/api/puzzle/internal/validate', methods=['GET'])
def internal_validate():
    if not verify_service_key():
        return jsonify({'error': 'Forbidden - invalid service key'}), 403
    return jsonify({'status': 'ok', 'internal': True})


@app.route('/internal/puzzles/daily', methods=['GET'])
@app.route('/api/puzzle/internal/puzzles/daily', methods=['GET'])
def internal_get_daily_puzzle():
    # Internal-only endpoint returning the daily puzzle (protected by service key)
    if not verify_service_key():
        return jsonify({'error': 'Forbidden - invalid service key'}), 403

    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT id, type, difficulty, grid_data FROM puzzles ORDER BY id DESC LIMIT 1')
    puzzle = cursor.fetchone()
    cursor.close()
    conn.close()
    if puzzle:
        return jsonify(puzzle)
    return jsonify({'error': 'No puzzles found'}), 404

if __name__ == '__main__':
    ok = init_db_with_retry(retries=5, delay_secs=0.5)
    if not ok:
        print('FATAL: Could not connect to database after retries. Exiting.', file=sys.stderr)
        sys.exit(1)
    app.run(host='0.0.0.0', port=PORT)
