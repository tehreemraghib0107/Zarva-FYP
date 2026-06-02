import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Shield, ShieldAlert, UserX, UserCheck, Search, Trash2, Mail } from 'lucide-react';

const UserManagement = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');

    useEffect(() => {
        fetchUsers();
    }, []);

    const fetchUsers = async () => {
        try {
            // This endpoint needs to be created in the backend
            const res = await axios.get('http://localhost:5000/api/auth/users');
            setUsers(res.data);
        } catch (err) {
            console.error('Error fetching users', err);
        } finally {
            setLoading(false);
        }
    };

    const handleToggleRole = async (userId, currentRole) => {
        try {
            const newRole = currentRole === 'admin' ? 'customer' : 'admin';
            await axios.put(`http://localhost:5000/api/auth/users/${userId}/role`, { role: newRole });
            fetchUsers();
        } catch (err) {
            console.error('Error updating role', err);
        }
    };

    const handleDeleteUser = async (userId) => {
        if (window.confirm('Are you sure you want to remove this user? This action cannot be undone.')) {
            try {
                await axios.delete(`http://localhost:5000/api/auth/users/${userId}`);
                fetchUsers();
            } catch (err) {
                console.error('Error deleting user', err);
            }
        }
    };

    const filteredUsers = users.filter(user => 
        user.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
        user.email.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1 style={{ color: 'var(--primary-bg)' }}>User Management</h1>
                <div style={{ position: 'relative', width: '300px' }}>
                    <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#999' }} />
                    <input 
                        type="text" 
                        placeholder="Search users..." 
                        className="form-control" 
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        style={{ paddingLeft: '40px' }}
                    />
                </div>
            </div>

            <div className="premium-card" style={{ padding: '0' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ textAlign: 'left', borderBottom: '1px solid #eee' }}>
                            <th style={{ padding: '20px' }}>User</th>
                            <th style={{ padding: '20px' }}>Email</th>
                            <th style={{ padding: '20px' }}>Role</th>
                            <th style={{ padding: '20px' }}>Status</th>
                            <th style={{ padding: '20px' }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredUsers.map((user) => (
                            <tr key={user._id} style={{ borderBottom: '1px solid #f9f9f9' }}>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                        <div style={{ width: '40px', height: '40px', borderRadius: '50%', backgroundColor: user.role === 'admin' ? '#0B1C2D' : '#eee', display: 'flex', alignItems: 'center', justifyContent: 'center', color: user.role === 'admin' ? 'white' : '#666' }}>
                                            {user.name.charAt(0).toUpperCase()}
                                        </div>
                                        <span style={{ fontWeight: '600' }}>{user.name}</span>
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '5px', color: '#666' }}>
                                        <Mail size={14} /> {user.email}
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <span style={{ 
                                        padding: '4px 12px', 
                                        borderRadius: '20px', 
                                        backgroundColor: user.role === 'admin' ? '#0B1C2D' : '#f0f4ff', 
                                        color: user.role === 'admin' ? 'white' : '#0B1C2D', 
                                        fontSize: '12px', 
                                        fontWeight: 'bold' 
                                    }}>
                                        {user.role}
                                    </span>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '5px', color: 'green', fontSize: '14px' }}>
                                        <div style={{ width: '8px', height: '8px', borderRadius: '50%', backgroundColor: 'green' }}></div> Active
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', gap: '15px' }}>
                                        <button 
                                            title={user.role === 'admin' ? "Revoke Admin" : "Make Admin"}
                                            onClick={() => handleToggleRole(user._id, user.role)}
                                            style={{ border: 'none', background: 'none', cursor: 'pointer', color: user.role === 'admin' ? '#DC3545' : '#0B1C2D' }}
                                        >
                                            {user.role === 'admin' ? <ShieldAlert size={18} /> : <Shield size={18} />}
                                        </button>
                                        <button 
                                            title="Delete User"
                                            onClick={() => handleDeleteUser(user._id)}
                                            style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#DC3545' }}
                                        >
                                            <Trash2 size={18} />
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
                {filteredUsers.length === 0 && (
                    <div style={{ padding: '40px', textAlign: 'center', color: '#888' }}>
                        No users found matching your search.
                    </div>
                )}
            </div>
        </div>
    );
};

export default UserManagement;
