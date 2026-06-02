const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();

const Review = require('../models/Review');
const Product = require('../models/Product');
const User = require('../models/User');

const auth = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    res.status(401).json({ msg: 'Token is not valid' });
  }
};

// Public: get approved reviews of product
router.get('/product/:productId', async (req, res) => {
  try {
    const reviews = await Review.find({
      productId: req.params.productId,
      status: 'Approved',
    })
      .populate('userId', 'name email')
      .sort({ createdAt: -1 });
    res.json(reviews);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Customer: add review (rating OR comment required)
router.post('/', auth, async (req, res) => {
  try {
    const { productId, rating, comment } = req.body || {};
    if (!productId) return res.status(400).json({ msg: 'productId is required' });
    const hasRating = typeof rating === 'number' && rating >= 1 && rating <= 5;
    const hasComment = typeof comment === 'string' && comment.trim().length > 0;
    if (!hasRating && !hasComment) {
      return res.status(400).json({ msg: 'Please provide rating or comment' });
    }

    const product = await Product.findById(productId).select('_id');
    if (!product) return res.status(404).json({ msg: 'Product not found' });

    const review = await Review.create({
      userId: req.user.id,
      productId,
      rating: hasRating ? rating : undefined,
      comment: hasComment ? comment.trim() : '',
      status: 'Pending',
    });

    res.status(201).json(review);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: list all reviews with user/product
router.get('/', async (req, res) => {
  try {
    const reviews = await Review.find({})
      .populate('userId', 'name email')
      .populate('productId', 'name')
      .sort({ createdAt: -1 });
    res.json(reviews);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: approve review
router.put('/:id/approve', async (req, res) => {
  try {
    const review = await Review.findByIdAndUpdate(
      req.params.id,
      { status: 'Approved' },
      { new: true }
    )
      .populate('userId', 'name email')
      .populate('productId', 'name');

    if (!review) return res.status(404).json({ msg: 'Review not found' });
    res.json(review);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: delete review
router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Review.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ msg: 'Review not found' });
    res.json({ msg: 'Review deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

