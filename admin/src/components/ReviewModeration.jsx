import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Star, CheckCircle, Trash2, Filter } from 'lucide-react';

const ReviewModeration = () => {
    const [reviews, setReviews] = useState([]);

    useEffect(() => {
        fetchReviews();
    }, []);

    const fetchReviews = async () => {
        try {
            const res = await axios.get('http://localhost:5000/api/reviews');
            setReviews(res.data);
        } catch (err) {
            console.error('Failed to fetch reviews', err);
        }
    };

    const handleApprove = async (id) => {
        try {
            await axios.put(`http://localhost:5000/api/reviews/${id}/approve`);
            fetchReviews();
        } catch (err) {
            console.error('Failed to approve review', err);
        }
    };

    const handleDelete = async (id) => {
        try {
            await axios.delete(`http://localhost:5000/api/reviews/${id}`);
            fetchReviews();
        } catch (err) {
            console.error('Failed to delete review', err);
        }
    };

    return (
        <div>
            <h1 style={{ color: 'var(--primary-bg)', marginBottom: '30px' }}>Review Moderation</h1>

            <div className="premium-card">
                <div style={{ display: 'grid', gap: '20px' }}>
                    {reviews.map((review) => (
                        <div key={review._id} style={{ 
                            padding: '20px', 
                            border: '1px solid #eee', 
                            borderRadius: '12px',
                            display: 'flex',
                            flexDirection: 'column',
                            gap: '15px',
                            backgroundColor: review.status === 'Pending' ? '#fff9f0' : 'white'
                        }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                                <div>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                        <h4 style={{ margin: 0 }}>{review.userId?.name || review.userId?.email || 'Customer'}</h4>
                                        <span style={{ fontSize: '12px', color: '#666' }}>on {review.productId?.name || 'Product'}</span>
                                    </div>
                                    <div style={{ display: 'flex', color: '#FFD700', marginTop: '5px' }}>
                                        {[...Array(5)].map((_, i) => (
                                            <Star key={i} size={14} fill={i < (review.rating || 0) ? "#FFD700" : "none"} stroke={i < (review.rating || 0) ? "none" : "#FFD700"} />
                                        ))}
                                    </div>
                                </div>
                                <div style={{ 
                                    padding: '4px 12px', 
                                    borderRadius: '20px', 
                                    fontSize: '12px', 
                                    fontWeight: 'bold',
                                    backgroundColor: review.status === 'Approved' ? '#e6fffa' : '#fff4e6',
                                    color: review.status === 'Approved' ? '#28A745' : '#D97706'
                                }}>
                                    {review.status}
                                </div>
                            </div>

                            <p style={{ color: '#444', margin: 0, fontSize: '15px' }}>
                                "{review.comment || (review.rating ? 'Rating-only review' : 'No comment')}"
                            </p>

                            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '15px' }}>
                                {review.status === 'Pending' && (
                                    <button 
                                        onClick={() => handleApprove(review._id)}
                                        style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#28A745', display: 'flex', alignItems: 'center', gap: '5px', fontSize: '14px', fontWeight: '600' }}
                                    >
                                        <CheckCircle size={18} /> Approve
                                    </button>
                                )}
                                <button 
                                    onClick={() => handleDelete(review._id)}
                                    style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#DC3545', display: 'flex', alignItems: 'center', gap: '5px', fontSize: '14px', fontWeight: '600' }}
                                >
                                    <Trash2 size={18} /> Delete
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default ReviewModeration;
