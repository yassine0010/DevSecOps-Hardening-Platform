import { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import { getPuzzleUrl } from '../lib/urls';

function PuzzleList() {
  const [puzzles, setPuzzles] = useState([]);

  useEffect(() => {
    const fetchPuzzles = async () => {
      try {
        const res = await axios.get(`${getPuzzleUrl()}/puzzles`);
        setPuzzles(res.data);
      } catch (err) {
        console.error('Failed to fetch puzzles', err);
      }
    };
    fetchPuzzles();
  }, []);

  return (
    <div className="puzzle-list">
      <h2>Puzzles</h2>
      <div className="grid">
        {puzzles.map(p => (
          <div key={p.id} className="puzzle-card">
            <h3>Puzzle #{p.id}</h3>
            <p>Type: {p.type}</p>
            <p className={`diff-${p.difficulty.toLowerCase()}`}>Difficulty: {p.difficulty}</p>
            <Link to={`/puzzles/${p.id}`} className="btn">Solve</Link>
          </div>
        ))}
        {puzzles.length === 0 && <p>No puzzles available currently. Run database seeders!</p>}
      </div>
    </div>
  );
}

export default PuzzleList;
