import { useState, useEffect } from 'react';
import axios from 'axios';
import { useParams } from 'react-router-dom';
import { getPuzzleUrl } from '../lib/urls';

function PuzzleSolve() {
  const { id } = useParams();
  const [puzzle, setPuzzle] = useState(null);
  const [answer, setAnswer] = useState('');
  const [result, setResult] = useState(null);

  useEffect(() => {
    const fetchPuzzle = async () => {
      try {
        const res = await axios.get(`${getPuzzleUrl()}/puzzles/${id}`);
        setPuzzle(res.data);
      } catch (err) {
        console.error('Failed to fetch puzzle', err);
      }
    };
    fetchPuzzle();
  }, [id]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const token = localStorage.getItem('token');
      const res = await axios.post(
        `${getPuzzleUrl()}/puzzles/${id}/submit`,
        { answer, time_taken: 120 }, // Hardcoded time for demo
        { headers: { Authorization: `Bearer ${token}` } }
      );
      setResult(res.data);
    } catch (err) {
      alert('Submission failed: ' + (err.response?.data?.error || err.message));
    }
  };

  return (
    <div className="puzzle-solve">
      <h2>Solve Puzzle #{id}</h2>
      <div className="puzzle-content">
        <p>Analyze the grid data from the server and submit your answer!</p>
        {puzzle ? (
          <div className="puzzle-data" style={{ background: '#f5f5f5', padding: '1rem', borderRadius: '8px', marginBottom: '1rem' }}>
            <p><strong>Type:</strong> {puzzle.type}</p>
            <p><strong>Difficulty:</strong> {puzzle.difficulty}</p>
            <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{puzzle.grid_data}</pre>
          </div>
        ) : (
          <p>Loading puzzle data...</p>
        )}
        <form onSubmit={handleSubmit}>
          <input type="text" placeholder="Your Answer" value={answer} onChange={e => setAnswer(e.target.value)} required />
          <button type="submit">Submit</button>
        </form>
        {result && (
          <div className={`result-box ${result.is_correct ? 'correct' : 'incorrect'}`}>
            {result.message}
          </div>
        )}
      </div>
    </div>
  );
}

export default PuzzleSolve;
