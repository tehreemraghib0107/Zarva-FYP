const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const Order = require('../models/Order');
const Inventory = require('../models/Inventory');
const mongoose = require('mongoose');
const User = require('../models/User');

// Middleware to protect routes
const auth = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        if (!token) return res.status(401).json({ msg: "No token, authorization denied" });

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        res.status(401).json({ msg: "Token is not valid" });
    }
};

function coerceNumber(value, fallback = 0) {
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (typeof value === 'string') {
        const cleaned = value.replace(/[^0-9.]/g, '');
        const parsed = Number(cleaned);
        if (Number.isFinite(parsed)) return parsed;
    }
    return fallback;
}

function normalizeOrderItems(items) {
    const arr = Array.isArray(items) ? items : [];
    return arr.map((raw) => {
        const productId = raw?.productId || raw?.id || raw?._id;
        const quantity = Math.max(1, parseInt(raw?.quantity, 10) || 1);
        return {
            productId: productId ? new mongoose.Types.ObjectId(productId) : undefined,
            name: String(raw?.name ?? '').trim(),
            price: coerceNumber(raw?.price, 0),
            quantity,
            size: raw?.size ? String(raw.size) : '',
            image: raw?.image ? String(raw.image) : undefined,
        };
    });
}

// @route   POST /orders
// @desc    Create a new order
router.post('/', auth, async (req, res) => {
    try {
        const {
            items,
            totalAmount,
            shippingFee,
            orderId,
            paymentMethod,
            customerName,
            customerEmail,
            phoneNumber,
            shippingAddress,
            promoCode,
            discountPercent,
            discountAmount
        } = req.body;

        // Force customer identity to match the logged-in account
        const user = await User.findById(req.user.id).select('email');
        if (!user) return res.status(401).json({ msg: "User not found" });
        const accountEmail = String(user.email || '').trim();
        if (!accountEmail) return res.status(401).json({ msg: "User email not found" });

        const normalizedItems = normalizeOrderItems(items).filter(i => i.name && i.price > 0 && i.quantity > 0);
        if (!orderId || typeof orderId !== 'string') return res.status(400).json({ msg: "orderId is required" });
        if (!paymentMethod) return res.status(400).json({ msg: "paymentMethod is required" });
        if (!phoneNumber || !shippingAddress) return res.status(400).json({ msg: "Customer details are required" });
        if (normalizedItems.length === 0) return res.status(400).json({ msg: "Order items are required" });

        const shipping = coerceNumber(shippingFee, 250);
        const grandTotal = coerceNumber(totalAmount, 0);
        if (grandTotal <= 0) return res.status(400).json({ msg: "totalAmount must be > 0" });

        // NOTE: Transactions require replica set / Atlas. To keep ordering reliable in all environments,
        // we do an atomic conditional decrement first (quantity >= qty), then save the order.

        const productIds = normalizedItems
            .map(i => i.productId)
            .filter(Boolean)
            .map(id => id.toString());

        if (productIds.length !== normalizedItems.length) {
            return res.status(400).json({ msg: 'Missing productId for one or more items' });
        }

        // 1) Atomic decrement inventory & increment sold
        const bulkOps = normalizedItems.map(item => ({
            updateOne: {
                // Inventory model semantics:
                // - quantity: total stock set by admin
                // - sold: cumulative sold count
                // remaining = quantity - sold
                filter: {
                    productId: item.productId,
                    $expr: { $gte: [{ $subtract: ["$quantity", "$sold"] }, item.quantity] }
                },
                update: { $inc: { sold: item.quantity } }
            }
        }));

        const bulkRes = await Inventory.bulkWrite(bulkOps);
        if (bulkRes.matchedCount !== normalizedItems.length) {
            return res.status(409).json({ msg: 'Stock changed or item out of stock, please try again' });
        }

        // 2) Save order (best-effort rollback if save fails)
        try {
            const isCod = String(paymentMethod).toLowerCase() === 'cash on delivery';
            const newOrder = new Order({
                userId: req.user.id,
                orderId,
                items: normalizedItems,
                totalAmount: grandTotal, // grand total (incl shipping)
                shippingFee: shipping,
                promoCode: promoCode ? String(promoCode).toUpperCase() : '',
                discountPercent: coerceNumber(discountPercent, 0),
                discountAmount: coerceNumber(discountAmount, 0),
                paymentMethod,
                paymentStatus: isCod ? 'Unpaid' : 'Pending',
                paymentProvider: isCod ? '' : String(paymentMethod),
                customerName: accountEmail,   // requirement: customer name == account email
                customerEmail: accountEmail,  // lock to account email
                phoneNumber,
                shippingAddress
            });

            const savedOrder = await newOrder.save();
            res.status(201).json(savedOrder);
        } catch (saveErr) {
            // Roll back inventory decrement if order save failed
            const rollbackOps = normalizedItems.map(item => ({
                updateOne: {
                    filter: { productId: item.productId },
                    update: { $inc: { sold: -item.quantity } }
                }
            }));
            await Inventory.bulkWrite(rollbackOps);
            throw saveErr;
        }
    } catch (err) {
        const statusCode = err.statusCode || 500;
        console.error(err.message);
        res.status(statusCode).json({ msg: err.message || 'Server Error' });
    }
});

// @route   GET /orders/history (For Mobile App)
router.get('/history', auth, async (req, res) => {
    try {
        const orders = await Order.find({ userId: req.user.id }).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ msg: err.message || 'Server Error' });
    }
});

// GET all orders (For Admin)
router.get('/', async (req, res) => {
    try {
        const orders = await Order.find({}).sort({ createdAt: -1 });
        res.json(orders);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET a single order (For Admin invoice/details)
router.get('/:id', async (req, res) => {
    try {
        const order = await Order.findById(req.params.id);
        if (!order) return res.status(404).json({ msg: "Order not found" });
        res.json(order);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Update Order status
router.put('/:id/status', async (req, res) => {
    try {
        const { status } = req.body;
        const order = await Order.findByIdAndUpdate(req.params.id, { status }, { new: true });
        res.json(order);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
