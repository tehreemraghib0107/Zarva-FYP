import React, { useState, useEffect } from 'react';
import { Routes, Route, useNavigate } from 'react-router-dom';
import Sidebar from './Sidebar';
import { Bell, Search, User } from 'lucide-react';
import axios from 'axios';

import ProductManagement from './ProductManagement';
import UserManagement from './UserManagement';
import OrderManagement from './OrderManagement';
import Analytics from './Analytics';
import ReviewModeration from './ReviewModeration';
import Promotions from './Promotions';
import InventoryManagement from './InventoryManagement';

const DashboardHome = () => {
    const [stats, setStats] = useState({ totalSales: 0, pendingOrders: 0, activeUsers: 0 });

    useEffect(() => {
        const fetchDashboardData = async () => {
            try {
                const [ordersRes, usersRes] = await Promise.all([
                    axios.get('http://localhost:5000/api/orders'),
                    axios.get('http://localhost:5000/api/auth/users')
                ]);
                
                const orders = ordersRes.data;
                const totalSales = orders.reduce((sum, order) => sum + (order.totalAmount || 0), 0);
                const pendingOrders = orders.filter(o => o.status === 'Pending').length;
                const activeUsers = usersRes.data.length;

                setStats({ totalSales, pendingOrders, activeUsers });
            } catch (err) {
                console.error("Error fetching dashboard data", err);
            }
        };
        fetchDashboardData();
    }, []);

    return (
    <div className="premium-card">
        <h1>Dashboard Overview</h1>
        <p>Welcome to the Zarva Admin Portal. Here you can manage your jewelry store operations.</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '20px', marginTop: '30px' }}>
            <div className="premium-card" style={{ backgroundColor: '#f0f4ff', border: 'none' }}>
                <h3 style={{ color: '#0B1C2D' }}>Total Sales</h3>
                <h2 style={{ fontSize: '28px', margin: '10px 0' }}>PKR {stats.totalSales.toLocaleString()}</h2>
                <p style={{ color: 'green', fontSize: '14px' }}>Real-time data</p>
            </div>
            <div className="premium-card" style={{ backgroundColor: '#fff4e6', border: 'none' }}>
                <h3 style={{ color: '#0B1C2D' }}>Pending Orders</h3>
                <h2 style={{ fontSize: '28px', margin: '10px 0' }}>{stats.pendingOrders}</h2>
                <p style={{ color: '#666', fontSize: '14px' }}>Needs your attention</p>
            </div>
            <div className="premium-card" style={{ backgroundColor: '#e6fffa', border: 'none' }}>
                <h3 style={{ color: '#0B1C2D' }}>Active Users</h3>
                <h2 style={{ fontSize: '28px', margin: '10px 0' }}>{stats.activeUsers}</h2>
                <p style={{ color: '#666', fontSize: '14px' }}>Growing community</p>
            </div>
        </div>
    </div>
    );
};

const Products = () => <div>Products Management (Coming in next step)</div>;
const AdminLayout = () => {
    const navigate = useNavigate();
    const [notifications, setNotifications] = useState(0);

    useEffect(() => {
        const fetchNotifications = async () => {
            try {
                const res = await axios.get('http://localhost:5000/api/orders');
                const pendingOrders = res.data.filter(o => o.status === 'Pending').length;
                setNotifications(pendingOrders);
            } catch (err) {
                console.error("Failed to fetch notifications", err);
            }
        };

        fetchNotifications();
        const interval = setInterval(fetchNotifications, 10000);
        return () => clearInterval(interval);
    }, []);

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('admin');
        navigate('/login');
    };

    return (
        <div style={{ display: 'flex', minHeight: '100vh', backgroundColor: 'var(--secondary-bg)' }}>
            <Sidebar />
            <div style={{ flex: 1, marginLeft: '260px', padding: '30px' }}>
                <div style={{ 
                    display: 'flex', 
                    justifyContent: 'space-between', 
                    alignItems: 'center', 
                    marginBottom: '30px' 
                }}>
                    <div style={{ position: 'relative', width: '300px' }}>
                        <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#999' }} />
                        <input 
                            type="text" 
                            placeholder="Search anything..." 
                            className="form-control" 
                            style={{ paddingLeft: '40px', backgroundColor: 'white', border: 'none', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' }} 
                        />
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                        <div 
                            style={{ position: 'relative', cursor: 'pointer' }}
                            onClick={() => navigate('/dashboard/orders')}
                        >
                            <Bell size={24} color="#0B1C2D" />
                            {notifications > 0 && (
                                <span style={{ 
                                    position: 'absolute', 
                                    top: '-5px', 
                                    right: '-5px', 
                                    background: 'red', 
                                    color: 'white', 
                                    borderRadius: '50%', 
                                    padding: '2px 6px', 
                                    fontSize: '10px',
                                    fontWeight: 'bold'
                                }}>
                                    {notifications}
                                </span>
                            )}
                        </div>
                        <div 
                            onClick={handleLogout}
                            style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', padding: '5px 15px', background: 'white', borderRadius: '30px', boxShadow: '0 2px 10px rgba(0,0,0,0.05)' }}
                        >
                            <div style={{ width: '35px', height: '35px', borderRadius: '50%', backgroundColor: '#0B1C2D', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white' }}>
                                <User size={20} />
                            </div>
                            <span style={{ fontWeight: '600', fontSize: '14px' }}>Logout</span>
                        </div>
                    </div>
                </div>

                <Routes>
                    <Route path="/" element={<DashboardHome />} />
                    <Route path="products" element={<ProductManagement />} />
                    <Route path="users" element={<UserManagement />} />
                    <Route path="orders" element={<OrderManagement />} />
                    <Route path="analytics" element={<Analytics />} />
                    <Route path="inventory" element={<InventoryManagement />} />
                    <Route path="reviews" element={<ReviewModeration />} />
                    <Route path="promotions" element={<Promotions />} />
                </Routes>
            </div>
        </div>
    );
};

export default AdminLayout;
