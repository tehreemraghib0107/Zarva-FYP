import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import { User, Lock, Mail, ArrowRight, ShieldCheck } from 'lucide-react';

const Signup = () => {
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [adminKey, setAdminKey] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleSignup = async (e) => {
        e.preventDefault();
        setLoading(true);
        setError('');
        
        // Simple security check for demo purposes
        if (adminKey !== 'ZARVA_ADMIN_2024') {
            setError('Invalid Admin Registration Key.');
            setLoading(false);
            return;
        }

        try {
            await axios.post('http://localhost:5000/api/auth/signup', { 
                name, 
                email, 
                password,
                role: 'admin' // We'll update the backend to handle this role assignment
            });
            alert('Signup request received. You can now login.');
            navigate('/login');
        } catch (err) {
            setError(err.response?.data?.msg || 'Signup failed. Please try again.');
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
                <h2 style={{ marginBottom: '10px', fontWeight: 'bold' }}>Admin Registration</h2>
                <p style={{ color: '#666', marginBottom: '30px' }}>Create an administrator account</p>

                {error && <div style={{ 
                    color: 'white', 
                    backgroundColor: 'var(--error)', 
                    padding: '10px', 
                    borderRadius: '8px', 
                    marginBottom: '20px',
                    fontSize: '14px'
                }}>{error}</div>}

                <form onSubmit={handleSignup}>
                    <div className="form-group" style={{ textAlign: 'left' }}>
                        <label><User size={14} style={{ marginRight: '5px' }} /> Full Name</label>
                        <input 
                            type="text" 
                            className="form-control" 
                            placeholder="John Doe"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            required
                        />
                    </div>
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
                    <div className="form-group" style={{ textAlign: 'left' }}>
                        <label><ShieldCheck size={14} style={{ marginRight: '5px' }} /> Admin Access Key</label>
                        <input 
                            type="text" 
                            className="form-control" 
                            placeholder="Enter security key"
                            value={adminKey}
                            onChange={(e) => setAdminKey(e.target.value)}
                            required
                        />
                    </div>
                    <button type="submit" className="btn-primary" style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }} disabled={loading}>
                        {loading ? 'Creating Account...' : <>Create Admin Account <ArrowRight size={18} style={{ marginLeft: '10px' }} /></>}
                    </button>
                </form>

                <div style={{ marginTop: '20px', fontSize: '14px' }}>
                    <span style={{ color: '#666' }}>Already have account? </span>
                    <Link to="/login" style={{ color: 'var(--primary-bg)', fontWeight: 'bold', textDecoration: 'none' }}>Login Here</Link>
                </div>
            </div>
        </div>
    );
};

export default Signup;
