const express = require('express');
const router = express.Router();
const Favorite = require('../models/Favorite');
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

// GET User Favorites
router.get('/', auth, async (req, res) => {
    try {
        const favorites = await Favorite.find({ userId: req.user.id }).populate('productId');
        res.json(favorites);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ADD Favorite
router.post('/', auth, async (req, res) => {
    try {
        const { productId } = req.body;

        // Check if already exists
        let fav = await Favorite.findOne({ userId: req.user.id, productId });
        if (fav) return res.status(400).json({ msg: 'Product already in favorites' });

        fav = new Favorite({ userId: req.user.id, productId });
        await fav.save();
        res.json(fav);

    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// REMOVE Favorite
router.delete('/:productId', auth, async (req, res) => {
    try {
        await Favorite.findOneAndDelete({ userId: req.user.id, productId: req.params.productId });
        res.json({ msg: 'Removed from favorites' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
