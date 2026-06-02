import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { ShoppingBag, Clock, CheckCircle, XCircle, Eye, Search, Filter } from 'lucide-react';

const OrderManagement = () => {
    const [orders, setOrders] = useState([]);
    const [loading, setLoading] = useState(true);
    const [statusFilter, setStatusFilter] = useState('All');
    const [selectedOrder, setSelectedOrder] = useState(null);
    const [invoiceOpen, setInvoiceOpen] = useState(false);

    useEffect(() => {
        fetchOrders();
    }, []);

    const fetchOrders = async () => {
        try {
            const res = await axios.get('http://localhost:5000/api/orders');
            setOrders(res.data);
        } catch (err) {
            console.error('Error fetching orders', err);
        } finally {
            setLoading(false);
        }
    };

    const handleUpdateStatus = async (orderId, newStatus) => {
        try {
            await axios.put(`http://localhost:5000/api/orders/${orderId}/status`, { status: newStatus });
            fetchOrders();
        } catch (err) {
            console.error('Error updating status', err);
        }
    };

    const openInvoice = async (orderDbId) => {
        try {
            const res = await axios.get(`http://localhost:5000/api/orders/${orderDbId}`);
            setSelectedOrder(res.data);
            setInvoiceOpen(true);
        } catch (err) {
            console.error('Error fetching order details', err);
            alert('Failed to load invoice.');
        }
    };

    const closeInvoice = () => {
        setInvoiceOpen(false);
        setSelectedOrder(null);
    };

    const formatPKR = (amount) => {
        const num = Number(amount);
        if (!Number.isFinite(num)) return 'PKR 0';
        return `PKR ${num.toFixed(0)}`;
    };

    const getStatusColor = (status) => {
        switch (status) {
            case 'Pending': return '#FFA500';
            case 'Processing': return '#007BFF';
            case 'Shipped': return '#17A2B8';
            case 'Delivered': return '#28A745';
            case 'Cancelled': return '#DC3545';
            default: return '#666';
        }
    };

    const filteredOrders = statusFilter === 'All' 
        ? orders 
        : orders.filter(order => order.status === statusFilter);

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1 style={{ color: 'var(--primary-bg)' }}>Order Management</h1>
                <div style={{ display: 'flex', gap: '15px' }}>
                    <div style={{ position: 'relative' }}>
                        <Filter size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#999' }} />
                        <select 
                            className="form-control" 
                            style={{ paddingLeft: '40px', width: '200px' }}
                            value={statusFilter}
                            onChange={(e) => setStatusFilter(e.target.value)}
                        >
                            <option value="All">All Orders</option>
                            <option value="Pending">Pending</option>
                            <option value="Processing">Processing</option>
                            <option value="Shipped">Shipped</option>
                            <option value="Delivered">Delivered</option>
                            <option value="Cancelled">Cancelled</option>
                        </select>
                    </div>
                </div>
            </div>

            <div className="premium-card" style={{ padding: '0' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ textAlign: 'left', borderBottom: '1px solid #eee' }}>
                            <th style={{ padding: '20px' }}>Order ID</th>
                            <th style={{ padding: '20px' }}>Customer</th>
                            <th style={{ padding: '20px' }}>Items</th>
                            <th style={{ padding: '20px' }}>Total Amount</th>
                            <th style={{ padding: '20px' }}>Status</th>
                            <th style={{ padding: '20px' }}>Date</th>
                            <th style={{ padding: '20px' }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredOrders.map((order) => (
                            <tr key={order._id} style={{ borderBottom: '1px solid #f9f9f9' }}>
                                <td style={{ padding: '15px 20px' }}>
                                    <span style={{ fontWeight: 'bold', color: '#0B1C2D' }}>
                                        #{order.orderId || String(order._id).slice(-6).toUpperCase()}
                                    </span>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div>
                                        <div style={{ fontWeight: '600' }}>{order.customerName}</div>
                                        <div style={{ fontSize: '12px', color: '#888' }}>{order.customerEmail}</div>
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px', fontSize: '13px', color: '#444' }}>
                                    {Array.isArray(order.items) && order.items.length > 0 ? (
                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                            {order.items.slice(0, 2).map((it, idx) => (
                                                <div key={`${order._id}-it-${idx}`}>
                                                    {it.name} x {it.quantity}
                                                </div>
                                            ))}
                                            {order.items.length > 2 && (
                                                <div style={{ fontSize: '12px', color: '#888' }}>
                                                    +{order.items.length - 2} more
                                                </div>
                                            )}
                                        </div>
                                    ) : (
                                        <span style={{ color: '#888' }}>—</span>
                                    )}
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ fontWeight: 'bold' }}>{formatPKR(order.totalAmount)}</div>
                                    <div style={{ fontSize: '10px', color: '#888' }}>Incl. Shipping</div>
                                    {order.paymentStatus && (
                                        <div style={{ fontSize: '10px', color: order.paymentStatus === 'Paid' ? '#28A745' : '#888' }}>
                                            Payment: {order.paymentStatus}
                                        </div>
                                    )}
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ 
                                        display: 'inline-flex', 
                                        alignItems: 'center', 
                                        padding: '4px 12px', 
                                        borderRadius: '20px', 
                                        backgroundColor: `${getStatusColor(order.status)}22`, 
                                        color: getStatusColor(order.status), 
                                        fontSize: '12px', 
                                        fontWeight: 'bold' 
                                    }}>
                                        {order.status}
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px', fontSize: '14px', color: '#666' }}>
                                    {new Date(order.createdAt).toLocaleDateString()}
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', gap: '10px' }}>
                                        <button
                                            onClick={() => openInvoice(order._id)}
                                            title="View Invoice"
                                            style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#0B1C2D' }}
                                        >
                                            <Eye size={18} />
                                        </button>
                                        <select 
                                            value={order.status} 
                                            onChange={(e) => handleUpdateStatus(order._id, e.target.value)}
                                            style={{ padding: '4px', borderRadius: '4px', fontSize: '12px' }}
                                        >
                                            <option value="Pending">Pending</option>
                                            <option value="Processing">Processing</option>
                                            <option value="Shipped">Shipped</option>
                                            <option value="Delivered">Delivered</option>
                                            <option value="Cancelled">Cancelled</option>
                                        </select>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
                {filteredOrders.length === 0 && (
                    <div style={{ padding: '40px', textAlign: 'center', color: '#888' }}>
                        No orders found.
                    </div>
                )}
            </div>

            {invoiceOpen && selectedOrder && (
                <div
                    onClick={closeInvoice}
                    style={{
                        position: 'fixed',
                        top: 0,
                        left: 0,
                        width: '100%',
                        height: '100%',
                        background: 'rgba(0,0,0,0.45)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        zIndex: 3000
                    }}
                >
                    <div
                        onClick={(e) => e.stopPropagation()}
                        className="premium-card"
                        style={{
                            width: '100%',
                            maxWidth: '900px',
                            maxHeight: '90vh',
                            overflowY: 'auto',
                            padding: '24px'
                        }}
                    >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
                            <div>
                                <div style={{ fontSize: '18px', fontWeight: 800, color: '#0B1C2D' }}>Invoice</div>
                                <div style={{ fontSize: '12px', color: '#666' }}>
                                    Order #{selectedOrder.orderId} • {new Date(selectedOrder.createdAt).toLocaleString()}
                                </div>
                            </div>
                            <div style={{ display: 'flex', gap: '10px' }}>
                                <button
                                    className="btn-primary"
                                    onClick={() => window.print()}
                                    style={{ padding: '10px 14px' }}
                                >
                                    Print
                                </button>
                                <button
                                    className="btn-primary"
                                    onClick={closeInvoice}
                                    style={{ padding: '10px 14px', backgroundColor: '#666' }}
                                >
                                    Close
                                </button>
                            </div>
                        </div>

                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px' }}>
                            <div style={{ border: '1px solid #eee', borderRadius: '12px', padding: '14px' }}>
                                <div style={{ fontWeight: 700, marginBottom: '10px' }}>Customer</div>
                                <div style={{ color: '#333' }}>{selectedOrder.customerName}</div>
                                <div style={{ color: '#666', fontSize: '13px' }}>{selectedOrder.customerEmail}</div>
                                <div style={{ color: '#666', fontSize: '13px' }}>{selectedOrder.phoneNumber}</div>
                            </div>
                            <div style={{ border: '1px solid #eee', borderRadius: '12px', padding: '14px' }}>
                                <div style={{ fontWeight: 700, marginBottom: '10px' }}>Shipping</div>
                                <div style={{ color: '#333', whiteSpace: 'pre-wrap' }}>{selectedOrder.shippingAddress}</div>
                                <div style={{ marginTop: '10px', fontSize: '13px', color: '#666' }}>
                                    Payment: <span style={{ fontWeight: 600, color: '#0B1C2D' }}>{selectedOrder.paymentMethod}</span>
                                </div>
                                <div style={{ marginTop: '6px', fontSize: '13px', color: '#666' }}>
                                    Payment Status:{' '}
                                    <span style={{ fontWeight: 700, color: selectedOrder.paymentStatus === 'Paid' ? '#28A745' : '#DC3545' }}>
                                        {selectedOrder.paymentStatus || 'Unpaid'}
                                    </span>
                                </div>
                                <div style={{ marginTop: '6px', fontSize: '13px', color: '#666' }}>
                                    Status: <span style={{ fontWeight: 600, color: getStatusColor(selectedOrder.status) }}>{selectedOrder.status}</span>
                                </div>
                            </div>
                        </div>

                        <div style={{ marginTop: '18px', border: '1px solid #eee', borderRadius: '12px', overflow: 'hidden' }}>
                            <div style={{ padding: '12px 14px', background: '#fafafa', fontWeight: 700 }}>Order Items</div>
                            <div style={{ padding: '12px 14px' }}>
                                {Array.isArray(selectedOrder.items) && selectedOrder.items.length > 0 ? (
                                    <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                                        <thead>
                                            <tr style={{ textAlign: 'left', borderBottom: '1px solid #eee' }}>
                                                <th style={{ padding: '10px 6px' }}>Item</th>
                                                <th style={{ padding: '10px 6px' }}>Qty</th>
                                                <th style={{ padding: '10px 6px' }}>Unit</th>
                                                <th style={{ padding: '10px 6px', textAlign: 'right' }}>Line Total</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {selectedOrder.items.map((it, idx) => (
                                                <tr key={`inv-it-${idx}`} style={{ borderBottom: '1px solid #f4f4f4' }}>
                                                    <td style={{ padding: '10px 6px' }}>{it.name}</td>
                                                    <td style={{ padding: '10px 6px' }}>{it.quantity}</td>
                                                    <td style={{ padding: '10px 6px' }}>{formatPKR(it.price)}</td>
                                                    <td style={{ padding: '10px 6px', textAlign: 'right', fontWeight: 700 }}>
                                                        {formatPKR(Number(it.price) * Number(it.quantity))}
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                ) : (
                                    <div style={{ color: '#888' }}>No items.</div>
                                )}
                            </div>
                        </div>

                        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '18px' }}>
                            <div style={{ width: '320px', border: '1px solid #eee', borderRadius: '12px', padding: '14px' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', color: '#666' }}>
                                    <span>Shipping</span>
                                    <span>{formatPKR(selectedOrder.shippingFee || 0)}</span>
                                </div>
                                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '16px', fontWeight: 800, color: '#0B1C2D' }}>
                                    <span>Total</span>
                                    <span>{formatPKR(selectedOrder.totalAmount)}</span>
                                </div>
                                {String(selectedOrder.paymentMethod || '').toLowerCase() === 'cash on delivery' && (
                                    <div style={{ marginTop: '10px', paddingTop: '10px', borderTop: '1px dashed #eee' }}>
                                        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 800 }}>
                                            <span>Cash to Collect (COD)</span>
                                            <span>{formatPKR(selectedOrder.totalAmount)}</span>
                                        </div>
                                        <div style={{ fontSize: '12px', color: '#666', marginTop: '4px' }}>
                                            Customer must pay this amount on delivery.
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default OrderManagement;
