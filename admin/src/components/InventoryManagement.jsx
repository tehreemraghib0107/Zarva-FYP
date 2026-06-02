import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Package, Edit2, AlertCircle } from 'lucide-react';

const InventoryManagement = () => {
    const [inventoryItems, setInventoryItems] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchInventory();
    }, []);

    const fetchInventory = async () => {
        try {
            const res = await axios.get('http://localhost:5000/api/inventory');
            setInventoryItems(res.data);
            setLoading(false);
        } catch (err) {
            console.error('Error fetching inventory:', err);
            setLoading(false);
        }
    };

    const handleUpdateQuantity = async (id, currentQty) => {
        const newQty = prompt("Enter new total quantity:", currentQty);
        if (newQty && !isNaN(newQty)) {
            try {
                await axios.put(`http://localhost:5000/api/inventory/${id}`, { quantity: Number(newQty) });
                fetchInventory();
            } catch (err) {
                console.error('Failed to update quantity', err);
                alert("Failed to update quantity.");
            }
        }
    };

    const handleSyncInventory = async () => {
        try {
            setLoading(true);
            const res = await axios.post('http://localhost:5000/api/inventory/sync');
            alert(`Inventory Synced! Added ${res.data.addedCount} new records.`);
            fetchInventory();
        } catch (err) {
            console.error('Failed to sync inventory', err);
            alert("Failed to sync inventory.");
            setLoading(false);
        }
    };

    if (loading) return <div>Loading...</div>;

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1 style={{ color: 'var(--primary-bg)' }}>Inventory Management</h1>
                <button 
                    onClick={handleSyncInventory}
                    className="btn btn-primary"
                    style={{ background: 'var(--primary-bg)', color: 'white', border: 'none', padding: '10px 20px', borderRadius: '5px' }}
                >
                    Sync Missing Inventory
                </button>
            </div>

            <div className="premium-card">
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ backgroundColor: '#f8f9fa', borderBottom: '2px solid #dee2e6' }}>
                            <th style={{ padding: '15px', textAlign: 'left', color: '#495057' }}>Image</th>
                            <th style={{ padding: '15px', textAlign: 'left', color: '#495057' }}>Product Name</th>
                            <th style={{ padding: '15px', textAlign: 'left', color: '#495057' }}>Total Quantity</th>
                            <th style={{ padding: '15px', textAlign: 'left', color: '#495057' }}>Sold No.</th>
                            <th style={{ padding: '15px', textAlign: 'left', color: '#495057' }}>Remaining Items</th>
                            <th style={{ padding: '15px', textAlign: 'center', color: '#495057' }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {inventoryItems.map((item) => {
                            const prod = item.productId;
                            if (!prod) return null;
                            const remaining = item.quantity - item.sold;
                            const isLowStock = remaining < 10;

                            return (
                                <tr key={item._id} style={{ borderBottom: '1px solid #eee' }}>
                                    <td style={{ padding: '15px' }}>
                                        <img src={`http://localhost:5000/${prod.image}`} alt={prod.name} style={{ width: '50px', height: '50px', objectFit: 'cover', borderRadius: '5px' }} />
                                    </td>
                                    <td style={{ padding: '15px', fontWeight: '500' }}>
                                        {prod.name}
                                        {isLowStock && <span style={{ marginLeft: '10px', color: 'red', fontSize: '12px' }}><AlertCircle size={14}/> Low Stock</span>}
                                    </td>
                                    <td style={{ padding: '15px' }}>{item.quantity}</td>
                                    <td style={{ padding: '15px', color: '#28A745' }}>{item.sold}</td>
                                    <td style={{ padding: '15px', fontWeight: 'bold', color: isLowStock ? 'red' : 'inherit' }}>
                                        {remaining}
                                    </td>
                                    <td style={{ padding: '15px', textAlign: 'center' }}>
                                        <button 
                                            onClick={() => handleUpdateQuantity(item._id, item.quantity)}
                                            style={{ background: 'none', border: 'none', color: '#007BFF', cursor: 'pointer' }}
                                        >
                                            <Edit2 size={18} /> Edit Qty
                                        </button>
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>
        </div>
    );
};

export default InventoryManagement;
