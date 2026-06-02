import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { TrendingUp, Award, DollarSign, Package, Users as UsersIcon } from 'lucide-react';

const Analytics = () => {
    const [stats, setStats] = useState({
        totalSales: 0,
        orderCount: 0,
        userCount: 0,
        productCount: 0,
        topProducts: []
    });

    useEffect(() => {
        // In a real app, we'd have a specific analytics endpoint
        // For now, we'll derive some data from existing endpoints
        fetchAnalytics();
    }, []);

    const fetchAnalytics = async () => {
        try {
            const [ordersRes, usersRes, productsRes] = await Promise.all([
                axios.get('http://localhost:5000/api/orders'),
                axios.get('http://localhost:5000/api/auth/users'),
                axios.get('http://localhost:5000/api/products')
            ]);

            const orders = ordersRes.data;
            const totalSales = orders.reduce((sum, order) => sum + (order.totalAmount || 0), 0);

            // Derive top products (simple frequency)
            const productFrequency = {};
            orders.forEach(order => {
                order.items.forEach(item => {
                    productFrequency[item.name] = (productFrequency[item.name] || 0) + item.quantity;
                });
            });

            const topProducts = Object.entries(productFrequency)
                .map(([name, count]) => ({ name, count }))
                .sort((a, b) => b.count - a.count)
                .slice(0, 5);

            setStats({
                totalSales,
                orderCount: orders.length,
                userCount: usersRes.data.length,
                productCount: productsRes.data.length,
                topProducts
            });
        } catch (err) {
            console.error('Error fetching analytics', err);
        }
    };

    return (
        <div>
            <h1 style={{ color: 'var(--primary-bg)', marginBottom: '30px' }}>Business Analytics</h1>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '20px', marginBottom: '40px' }}>
                <div className="premium-card" style={{ borderLeft: '5px solid #28A745' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                            <p style={{ color: '#666', fontSize: '14px', marginBottom: '5px' }}>Total Revenue</p>
                            <h2 style={{ fontSize: '28px' }}>PKR {stats.totalSales.toLocaleString()}</h2>
                        </div>
                        <DollarSign size={32} color="#28A745" />
                    </div>
                </div>
                <div className="premium-card" style={{ borderLeft: '5px solid #007BFF' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                            <p style={{ color: '#666', fontSize: '14px', marginBottom: '5px' }}>Total Orders</p>
                            <h2 style={{ fontSize: '28px' }}>{stats.orderCount}</h2>
                        </div>
                        <Package size={32} color="#007BFF" />
                    </div>
                </div>
                <div className="premium-card" style={{ borderLeft: '5px solid #6F42C1' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                            <p style={{ color: '#666', fontSize: '14px', marginBottom: '5px' }}>Total Customers</p>
                            <h2 style={{ fontSize: '28px' }}>{stats.userCount}</h2>
                        </div>
                        <UsersIcon size={32} color="#6F42C1" />
                    </div>
                </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '30px' }}>
                <div className="premium-card">
                    <h3 style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <Award color="gold" /> Top Selling Jewelry
                    </h3>
                    {stats.topProducts.length > 0 ? (
                        stats.topProducts.map((product, index) => (
                            <div key={product.name} style={{ display: 'flex', justifyContent: 'space-between', padding: '15px 0', borderBottom: index < stats.topProducts.length - 1 ? '1px solid #eee' : 'none' }}>
                                <span style={{ fontWeight: '500' }}>{product.name}</span>
                                <span style={{ color: '#666' }}>{product.count} sold</span>
                            </div>
                        ))
                    ) : (
                        <p style={{ textAlign: 'center', color: '#999', padding: '20px' }}>No sales data yet.</p>
                    )}
                </div>

                <div className="premium-card">
                    <h3 style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <TrendingUp color="#28A745" /> Recent Trends
                    </h3>
                    <div style={{ textAlign: 'center', padding: '20px' }}>
                        <div style={{ fontSize: '48px', color: '#28A745' }}>+15%</div>
                        <p style={{ color: '#666' }}>Increase in customer engagement this week</p>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Analytics;
