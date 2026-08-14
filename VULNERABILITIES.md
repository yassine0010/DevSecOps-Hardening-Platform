# Intentional Vulnerabilities

This document details the vulnerabilities intentionally planted in the MindGrid application for DevSecOps scanning and demo purposes.

## 1. SQL Injection (SQLi)
*   **Service:** `puzzle-service`
*   **Location:** `puzzle-service/app.py`, `submit_answer` endpoint (approx. line 62).
*   **Vulnerability Type:** SQL Injection (CWE-89)
*   **Severity:** Critical
*   **Description:** The endpoint validates submitted answers by directly concatenating the user input (`submitted_answer`) into the SQL query string rather than using parameterized queries. This allows an attacker to manipulate the SQL statement, potentially bypassing logic or reading arbitrary database tables.
*   **Snippet:** 
    ```python
    query = f"SELECT id FROM puzzles WHERE id = {puzzle_id} AND correct_answer = '{submitted_answer}'"
    cursor.execute(query)
    ```

## 2. Insecure Direct Object Reference (IDOR
*   **Service:** `leaderboard-service`
*   **Location:** `leaderboard-service/server.js`, `/submissions/:id` GET and PUT endpoints (approx. lines 63 and 78).
*   **Vulnerability Type:** Insecure Direct Object Reference (IDOR) / Broken Access Control (CWE-284)
*   **Severity:** High
*   **Description:** The endpoints to retrieve and update submissions check if the user is authenticated via JWT, but they completely fail to verify if the requesting user actually owns the submission they are trying to access or modify. An attacker can enumerate `submissionId` values and read or modify other users' submission records (e.g., tampering with the `time_taken` to manipulate leaderboard rankings).
*   **Snippet:**
    ```javascript
    const submissionId = req.params.id;
    const [rows] = await pool.execute('SELECT * FROM submissions WHERE id = ?', [submissionId]);
    // Missing check: if (rows[0].user_id !== req.user.userId) return error;
    res.json(rows[0]);
    ```
