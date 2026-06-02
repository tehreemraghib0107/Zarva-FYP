const express = require('express');
const router = express.Router();
const Order = require('../models/Order');
const User = require('../models/User');
const Product = require('../models/Product');

// GET /api/analytics/dashboard
router.get('/dashboard', async (req, res) => {
    try {
        // Real-time metrics
        const orders = await Order.find();
        const pendingOrders = orders.filter(o => o.status === 'Pending').length;
        const totalSales = orders.reduce((sum, order) => sum + (order.totalAmount || 0), 0);
        
        const activeUsersCount = await User.countDocuments();

        // Calculate most sold item last month (approximate by checking all orders or you can filter by last 30 days)
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
        
        const recentOrders = await Order.find({ createdAt: { $gte: thirtyDaysAgo } });
        const productFrequency = {};
        
        recentOrders.forEach(order => {
            order.items.forEach(item => {
                const name = item.name;
                productFrequency[name] = (productFrequency[name] || 0) + item.quantity;
            });
        });

        let mostSoldLastMonth = null;
        let maxQty = 0;
        Object.entries(productFrequency).forEach(([name, count]) => {
            if (count > maxQty) {
                maxQty = count;
                mostSoldLastMonth = { name, count };
            }
        });

        res.json({
            totalSales,
            pendingOrders,
            activeUsers: activeUsersCount,
            mostSoldLastMonth
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error in Analytics');
    }
});

module.exports = router;
