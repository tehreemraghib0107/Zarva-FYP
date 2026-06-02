import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Plus, Edit2, Trash2, X, Upload, Check } from 'lucide-react';

const ProductManagement = () => {
    const [products, setProducts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editingProduct, setEditingProduct] = useState(null);
    const [formData, setFormData] = useState({
        name: '',
        category: 'Rings',
        price: '',
        image: '', 
        description: ''
    });
    const [selectedFile, setSelectedFile] = useState(null);

    const categories = ['Rings', 'Bracelets', 'Chokers', 'Lockets', 'Necklaces', 'Earrings'];

    useEffect(() => {
        fetchProducts();
    }, []);

    const fetchProducts = async () => {
        try {
            const res = await axios.get('http://localhost:5000/api/products');
            setProducts(res.data);
        } catch (err) {
            console.error('Error fetching products', err);
        } finally {
            setLoading(false);
        }
    };

    const handleInputChange = (e) => {
        setFormData({ ...formData, [e.target.name]: e.target.value });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        try {
            let imagePath = formData.image || 'assets/1R.png';
            if (selectedFile) {
                const uploadData = new FormData();
                uploadData.append('image', selectedFile);
                const uploadRes = await axios.post('http://localhost:5000/api/upload', uploadData, {
                    headers: { 'Content-Type': 'multipart/form-data' }
                });
                imagePath = uploadRes.data.filePath;
            }

            const productData = { ...formData, image: imagePath };

            if (editingProduct) {
                await axios.put(`http://localhost:5000/api/products/${editingProduct._id}`, productData);
            } else {
                await axios.post('http://localhost:5000/api/products', productData);
            }
            setShowModal(false);
            setEditingProduct(null);
            setSelectedFile(null);
            resetForm();
            fetchProducts();
        } catch (err) {
            console.error('Error saving product', err);
            alert('Error saving product. Please check console.');
        }
    };

    const handleEdit = (product) => {
        setEditingProduct(product);
        setFormData({
            name: product.name,
            category: product.category,
            price: product.price,
            image: product.image,
            description: product.description || ''
        });
        setSelectedFile(null);
        setShowModal(true);
    };

    const handleDelete = async (id) => {
        if (window.confirm('Are you sure you want to delete this product?')) {
            try {
                await axios.delete(`http://localhost:5000/api/products/${id}`);
                fetchProducts();
            } catch (err) {
                console.error('Error deleting product', err);
            }
        }
    };

    const resetForm = () => {
        setFormData({ name: '', category: 'Rings', price: '', image: '', description: '' });
        setSelectedFile(null);
    };

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' }}>
                <h1 style={{ color: 'var(--primary-bg)' }}>Product Management</h1>
                <button className="btn-primary" onClick={() => { resetForm(); setEditingProduct(null); setShowModal(true); }}>
                    <Plus size={18} style={{ marginRight: '8px' }} /> Add New Product
                </button>
            </div>

            <div className="premium-card" style={{ padding: '0' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                        <tr style={{ textAlign: 'left', borderBottom: '1px solid #eee' }}>
                            <th style={{ padding: '20px' }}>Image</th>
                            <th style={{ padding: '20px' }}>Product Details</th>
                            <th style={{ padding: '20px' }}>Category</th>
                            <th style={{ padding: '20px' }}>Price</th>
                            <th style={{ padding: '20px' }}>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {products.map((product) => (
                            <tr key={product._id} style={{ borderBottom: '1px solid #f9f9f9' }}>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ 
                                        width: '60px', 
                                        height: '60px', 
                                        borderRadius: '8px', 
                                        overflow: 'hidden', 
                                        backgroundColor: '#f5f5f5',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                        boxShadow: '0 2px 4px rgba(0,0,0,0.05)'
                                    }}>
                                        <img src={`http://localhost:5000/${product.image}`} alt={product.name} 
                                             style={{ 
                                                 width: '100%', 
                                                 height: '100%', 
                                                 objectFit: 'contain', // Changed to contain for jewelry
                                                 transition: 'opacity 0.3s ease'
                                             }}
                                             onLoad={(e) => e.target.style.opacity = 1}
                                             onError={(e) => { 
                                                 e.target.style.opacity = 0.5;
                                                 e.target.src = 'https://via.placeholder.com/60?text=No+Img'; 
                                             }} />
                                    </div>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <h4 style={{ margin: 0 }}>{product.name}</h4>
                                    <p style={{ fontSize: '12px', color: '#888', marginTop: '4px' }}>
                                        {product.description?.substring(0, 50)}...
                                    </p>
                                </td>
                                <td style={{ padding: '15px 20px' }}>
                                    <span style={{ padding: '4px 12px', borderRadius: '20px', backgroundColor: '#f0f4ff', color: '#0B1C2D', fontSize: '12px', fontWeight: 'bold' }}>
                                        {product.category}
                                    </span>
                                </td>
                                <td style={{ padding: '15px 20px', fontWeight: '600' }}>{product.price}</td>
                                <td style={{ padding: '15px 20px' }}>
                                    <div style={{ display: 'flex', gap: '10px' }}>
                                        <button onClick={() => handleEdit(product)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#0B1C2D' }}>
                                            <Edit2 size={18} />
                                        </button>
                                        <button onClick={() => handleDelete(product._id)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#DC3545' }}>
                                            <Trash2 size={18} />
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {/* Modal Form */}
            {showModal && (
                <div style={{ position: 'fixed', top: 0, left: 0, width: '100%', height: '100%', backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 2000 }}>
                    <div className="premium-card" style={{ width: '100%', maxWidth: '600px', maxHeight: '90vh', overflowY: 'auto' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '25px' }}>
                            <h2>{editingProduct ? 'Edit Product' : 'Add New Product'}</h2>
                            <X size={24} style={{ cursor: 'pointer' }} onClick={() => setShowModal(false)} />
                        </div>

                        <form onSubmit={handleSubmit}>
                            <div className="form-group">
                                <label>Product Name</label>
                                <input type="text" name="name" className="form-control" value={formData.name} onChange={handleInputChange} required placeholder="e.g. Royal Sapphire Ring" />
                            </div>

                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
                                <div className="form-group">
                                    <label>Category</label>
                                    <select name="category" className="form-control" value={formData.category} onChange={handleInputChange}>
                                        {categories.map(c => <option key={c} value={c}>{c}</option>)}
                                    </select>
                                </div>
                                <div className="form-group">
                                    <label>Price</label>
                                    <input type="text" name="price" className="form-control" value={formData.price} onChange={handleInputChange} required placeholder="PKR 2500" />
                                </div>
                            </div>

                            <div className="form-group">
                                <label>Product Image</label>
                                <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                                    <input 
                                        type="file" 
                                        name="image" 
                                        className="form-control" 
                                        accept="image/*"
                                        onChange={(e) => {
                                            if (e.target.files && e.target.files[0]) {
                                                setSelectedFile(e.target.files[0]);
                                            }
                                        }} 
                                        style={{ display: 'none' }}
                                        id="product-image-upload"
                                    />
                                    <label htmlFor="product-image-upload" className="btn-primary" style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 15px', whiteSpace: 'nowrap' }}>
                                        <Upload size={18} /> {selectedFile ? 'Change Image' : 'Browser System'}
                                    </label>
                                    <span style={{ fontSize: '14px', color: '#555', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                        {selectedFile ? selectedFile.name : formData.image ? `Current: ${formData.image}` : 'No image selected'}
                                    </span>
                                </div>
                            </div>

                            <div className="form-group">
                                <label>Description & Details</label>
                                <textarea name="description" className="form-control" rows="4" value={formData.description} onChange={handleInputChange} placeholder="Describe the product details, materials, and features..." />
                            </div>

                            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '15px', marginTop: '20px' }}>
                                <button type="button" className="btn-primary" style={{ backgroundColor: '#666' }} onClick={() => setShowModal(false)}>Cancel</button>
                                <button type="submit" className="btn-primary">
                                    {editingProduct ? 'Update Changes' : 'Publish Product'}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default ProductManagement;
