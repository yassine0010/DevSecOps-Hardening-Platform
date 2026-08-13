import { useState, useEffect } from 'react';
import axios from 'axios';
import { getLeaderboardUrl } from '../lib/urls';

function Leaderboard() {
  const [leaders, setLeaders] = useState([]);

  useEffect(() => {
    const fetchLeaderboard = async () => {
      try {
        const res = await axios.get(`${getLeaderboardUrl()}/leaderboard`);
        setLeaders(res.data);
      } catch (err) {
        console.error('Failed to fetch leaderboard', err);
      }
    };
    fetchLeaderboard();
  }, []);

  return (
    <div className="leaderboard-container">
      <h2>Global Leaderboard</h2>
      <table className="leaderboard-table">
        <thead>
          <tr>
            <th>Rank</th>
            <th>Username</th>
            <th>Category</th>
            <th>Solved</th>
            <th>Score</th>
          </tr>
        </thead>
        <tbody>
          {leaders.map((l, idx) => (
            <tr key={idx}>
              <td>{idx + 1}</td>
              <td>{l.username}</td>
              <td>{l.category}</td>
              <td>{l.puzzles_solved}</td>
              <td>{l.score}</td>
            </tr>
          ))}
          {leaders.length === 0 && (
            <tr><td colSpan="5">No data available.</td></tr>
          )}
        </tbody>
      </table>
    </div>
  );
}

export default Leaderboard;
