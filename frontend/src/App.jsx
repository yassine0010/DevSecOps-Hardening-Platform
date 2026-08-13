import { BrowserRouter as Router, Routes, Route, Link, Navigate, useLocation } from 'react-router-dom';
import { useState, useEffect } from 'react';
import Login from './pages/Login';
import Register from './pages/Register';
import PuzzleList from './pages/PuzzleList';
import PuzzleSolve from './pages/PuzzleSolve';
import Leaderboard from './pages/Leaderboard';
import './App.css';

function RequireAuth({ children }) {
  const token = localStorage.getItem('token');
  const location = useLocation();
  if (!token) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }
  return children;
}

function App() {
  const [authenticated, setAuthenticated] = useState(!!localStorage.getItem('token'));

  useEffect(() => {
    const onStorage = () => setAuthenticated(!!localStorage.getItem('token'));
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('userId');
    setAuthenticated(false);
    window.location.href = '/login';
  };

  return (
    <Router>
      <div className="app-container">
        <nav className="navbar">
          <div className="logo">MindGrid</div>
          <div className="nav-links">
            <Link to="/puzzles">Puzzles</Link>
            <Link to="/leaderboard">Leaderboard</Link>
            {!authenticated && <Link to="/login">Login</Link>}
            {!authenticated && <Link to="/register">Register</Link>}
            {authenticated && <a href="#" onClick={e => { e.preventDefault(); handleLogout(); }}>Logout</a>}
          </div>
        </nav>
        <main className="main-content">
          <Routes>
            <Route path="/" element={authenticated ? <Navigate to="/puzzles" replace /> : <Navigate to="/login" replace />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/puzzles" element={<RequireAuth><PuzzleList /></RequireAuth>} />
            <Route path="/puzzles/:id" element={<RequireAuth><PuzzleSolve /></RequireAuth>} />
            <Route path="/leaderboard" element={<RequireAuth><Leaderboard /></RequireAuth>} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
