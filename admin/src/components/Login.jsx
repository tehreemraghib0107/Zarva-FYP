import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import { User, Lock, Mail, ArrowRight } from 'lucide-react';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleLogin = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');
        try {
            const res = await axios.post('http://localhost:5000/api/auth/login', { email, password });
            // In a real app, check for admin role here
            // For now, assume if login is successful they can enter, 
            // but we'll add the role check in the backend later.
            localStorage.setItem('adminToken', res.data.token);
            navigate('/dashboard');
        } catch (err) {
            setError(err.response?.data?.msg || 'Login failed. Please check your credentials.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: 'var(--primary-bg)',
            padding: '20px'
        }}>
            <div className="premium-card" style={{ width: '100%', maxWidth: '400px', textAlign: 'center' }}>
                <img src="/assets/new logo.png" alt="Zarva Logo" style={{ width: '120px', marginBottom: '20px' }} 
                     onError={(e) => e.target.style.display = 'none'} />
                <h2 style={{ marginBottom: '10px', fontWeight: 'bold' }}>Admin Portal</h2>
                <p style={{ color: '#666', marginBottom: '30px' }}>Sign in to manage your jewelry store</p>

                {error && <div style={{ 
                    color: 'white', 
                    backgroundColor: 'var(--error)', 
                    padding: '10px', 
                    borderRadius: '8px', 
                    marginBottom: '20px',
                    fontSize: '14px'
                }}>{error}</div>}

                <form onSubmit={handleLogin}>
                    <div className="form-group" style={{ textAlign: 'left' }}>
                        <label><Mail size={14} style={{ marginRight: '5px' }} /> Email Address</label>
                        <input 
                            type="email" 
                            className="form-control" 
                            placeholder="admin@zarva.com"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            required
                        />
                    </div>
                    <div className="form-group" style={{ textAlign: 'left' }}>
                        <label><Lock size={14} style={{ marginRight: '5px' }} /> Password</label>
                        <input 
                            type="password" 
                            className="form-control" 
                            placeholder="********"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                        />
                    </div>
                    <button type="submit" className="btn-primary" style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }} disabled={loading}>
                        {loading ? 'Authenticating...' : <>Login <ArrowRight size={18} style={{ marginLeft: '10px' }} /></>}
                    </button>
                </form>

                <div style={{ marginTop: '20px', fontSize: '14px' }}>
                    <span style={{ color: '#666' }}>Need an account? </span>
                    <Link to="/signup" style={{ color: 'var(--primary-bg)', fontWeight: 'bold', textDecoration: 'none' }}>Request Admin Access</Link>
                </div>
            </div>
        </div>
    );
};

export default Login;
