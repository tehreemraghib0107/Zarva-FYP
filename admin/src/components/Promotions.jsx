import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Tag, Send, Bell, Plus, Trash2 } from 'lucide-react';

const Promotions = () => {
    const [promotions, setPromotions] = useState([]);

    const [newPromo, setNewPromo] = useState({
        title: '',
        code: '',
        discountPercent: '',
        startsAt: '',
        expiresAt: '',
    });

    useEffect(() => {
        fetchPromotions();
    }, []);

    const fetchPromotions = async () => {
        try {
            const res = await axios.get('http://localhost:5000/api/promotions');
            setPromotions(res.data);
        } catch (err) {
            console.error('Failed to fetch promotions', err);
        }
    };

    const handleAdd = async (e) => {
        e.preventDefault();
        try {
            await axios.post('http://localhost:5000/api/promotions', {
                title: newPromo.title,
                code: newPromo.code,
                discountPercent: Number(newPromo.discountPercent),
                startsAt: newPromo.startsAt,
                expiresAt: newPromo.expiresAt,
            });
            setNewPromo({ title: '', code: '', discountPercent: '', startsAt: '', expiresAt: '' });
            fetchPromotions();
            alert('Promotion created and notification broadcasted.');
        } catch (err) {
            alert(err?.response?.data?.msg || 'Failed to create promotion');
        }
    };

    const handleDelete = async (id) => {
        try {
            await axios.delete(`http://localhost:5000/api/promotions/${id}`);
            fetchPromotions();
        } catch (err) {
            console.error('Failed to delete promotion', err);
        }
    };

    const now = new Date();
    const activePromotions = promotions.filter((p) => p.isActive && new Date(p.startsAt) <= now && new Date(p.expiresAt) >= now);

    return (
        <div>
            <h1 style={{ color: 'var(--primary-bg)', marginBottom: '30px' }}>Promotions & Offers</h1>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '30px' }}>
                <div className="premium-card">
                    <h3 style={{ marginBottom: '20px' }}>Create New Promo</h3>
                    <form onSubmit={handleAdd}>
                        <div className="form-group">
                            <label>Promotion Title</label>
                            <input type="text" className="form-control" value={newPromo.title} onChange={e => setNewPromo({...newPromo, title: e.target.value})} placeholder="e.g. Summer Sparks" required />
                        </div>
                        <div className="form-group">
                            <label>Coupon Code</label>
                            <input type="text" className="form-control" value={newPromo.code} onChange={e => setNewPromo({...newPromo, code: e.target.value})} placeholder="SUMMER20" required />
                        </div>
                        <div className="form-group">
                            <label>Discount Percent</label>
                            <input type="number" min="1" max="100" className="form-control" value={newPromo.discountPercent} onChange={e => setNewPromo({...newPromo, discountPercent: e.target.value})} placeholder="20" required />
                        </div>
                        <div className="form-group">
                            <label>Starts At</label>
                            <input type="datetime-local" className="form-control" value={newPromo.startsAt} onChange={e => setNewPromo({...newPromo, startsAt: e.target.value})} required />
                        </div>
                        <div className="form-group">
                            <label>Expires At</label>
                            <input type="datetime-local" className="form-control" value={newPromo.expiresAt} onChange={e => setNewPromo({...newPromo, expiresAt: e.target.value})} required />
                        </div>
                        <button type="submit" className="btn-primary" style={{ width: '100%', marginTop: '10px' }}>
                            <Plus size={18} style={{ marginRight: '8px' }} /> Create Promotion
                        </button>
                    </form>
                </div>

                <div className="premium-card">
                    <h3 style={{ marginBottom: '20px' }}>Active Promotions</h3>
                    <div style={{ display: 'grid', gap: '15px' }}>
                        {activePromotions.map(promo => (
                            <div key={promo._id} style={{ padding: '15px 20px', border: '1px solid #eee', borderRadius: '12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                                    <div style={{ backgroundColor: 'var(--primary-bg)', color: 'white', padding: '10px', borderRadius: '8px' }}>
                                        <Tag size={20} />
                                    </div>
                                    <div>
                                        <h4 style={{ margin: 0 }}>{promo.title}</h4>
                                        <span style={{ fontSize: '14px', color: '#666', fontWeight: 'bold' }}>CODE: {promo.code}</span>
                                        <div style={{ fontSize: '12px', color: '#888' }}>
                                            {new Date(promo.startsAt).toLocaleString()} - {new Date(promo.expiresAt).toLocaleString()}
                                        </div>
                                    </div>
                                </div>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                                    <span style={{ color: 'green', fontWeight: 'bold' }}>{promo.discountPercent}%</span>
                                    <button style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ff4d4d' }} onClick={() => handleDelete(promo._id)}>
                                        <Trash2 size={18} />
                                    </button>
                                </div>
                            </div>
                        ))}
                    </div>

                    <div style={{ marginTop: '40px', padding: '30px', backgroundColor: '#f0f4ff', borderRadius: '12px', textAlign: 'center' }}>
                        <Bell size={32} color="var(--primary-bg)" style={{ marginBottom: '15px' }} />
                        <h3>Push Notifications</h3>
                        <p style={{ color: '#666', marginBottom: '20px' }}>Notifications are broadcast automatically when a promotion is created.</p>
                        <button className="btn-primary" disabled>
                            <Send size={18} style={{ marginRight: '8px' }} /> Auto Broadcast Enabled
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Promotions;
