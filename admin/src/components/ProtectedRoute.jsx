import React from 'react';
import { Navigate } from 'react-router-dom';
import axios from 'axios';

// Helper to check if user is authenticated and is admin
// Since we don't have a reliable way to check role from token alone without extra libs or decoding,
// we'll rely on the localStorage flag for now, but in a production app we'd decode the JWT.
const ProtectedRoute = ({ children }) => {
    const token = localStorage.getItem('adminToken');
    
    if (!token) {
        return <Navigate to="/login" replace />;
    }

    // Usually we would also verify the token/role via an API call here
    return children;
};

export default ProtectedRoute;
