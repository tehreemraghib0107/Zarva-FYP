const express = require('express');
const router = express.Router();
const Wishlist = require('../models/Wishlist');
const jwt = require('jsonwebtoken');

// Middleware to authenticate
const auth = (req, res, next) => {
    const token = req.header('x-auth-token');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (e) {
        res.status(400).json({ msg: 'Token is not valid' });
    }
};

// GET user wishlist items
router.get('/', auth, async (req, res) => {
    try {
        const wishlist = await Wishlist.find({ userId: req.user.id }).populate('productId');
        res.json(wishlist);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ADD wishlist item
router.post('/', auth, async (req, res) => {
    try {
        const { productId } = req.body;
        let item = await Wishlist.findOne({ userId: req.user.id, productId });

        if (item) {
            return res.status(400).json({ msg: 'Product already in wishlist' });
        }

        item = new Wishlist({ userId: req.user.id, productId });
        await item.save();
        res.json(item);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// REMOVE wishlist item
router.delete('/:productId', auth, async (req, res) => {
    try {
        await Wishlist.findOneAndDelete({ userId: req.user.id, productId: req.params.productId });
        res.json({ msg: 'Removed from wishlist' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
