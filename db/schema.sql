CREATE DATABASE mindgrid;

\c mindgrid;

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS puzzles (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL, -- e.g., 'sudoku', 'math_riddle', 'number_sequence'
    difficulty VARCHAR(20) NOT NULL, -- 'Easy', 'Medium', 'Hard'
    grid_data TEXT NOT NULL, -- JSON string or text representing the puzzle
    correct_answer TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS submissions (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    puzzle_id INT NOT NULL,
    submitted_answer TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    time_taken INT NOT NULL, -- Time taken in seconds
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (puzzle_id) REFERENCES puzzles(id)
);

CREATE OR REPLACE VIEW leaderboard AS
SELECT 
    u.username,
    p.type AS category,
    COUNT(s.id) AS puzzles_solved,
    SUM(s.time_taken) AS total_time_taken,
    (COUNT(s.id) * 1000 - SUM(s.time_taken)) AS score
FROM submissions s
JOIN users u ON s.user_id = u.id
JOIN puzzles p ON s.puzzle_id = p.id
WHERE s.is_correct = TRUE
GROUP BY u.username, p.type
ORDER BY score DESC;
