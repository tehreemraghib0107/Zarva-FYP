const express = require('express');
const router = express.Router();

const Notification = require('../models/Notification');
const Promotion = require('../models/Promotion');

// GET latest notifications (mobile app)
// GET /api/notifications?limit=50
router.get('/', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || '50', 10) || 50, 200);
    const now = new Date();
    const activePromos = await Promotion.find({
      isActive: true,
      startsAt: { $lte: now },
      expiresAt: { $gte: now },
    }).select('code');
    const activeCodes = new Set(activePromos.map((p) => p.code));

    const raw = await Notification.find({}).sort({ createdAt: -1 }).limit(limit * 3);
    const filtered = raw.filter((n) => {
      if (n.type !== 'promotion') return true;
      const code = n.metadata?.code;
      return !!code && activeCodes.has(String(code).toUpperCase());
    }).slice(0, limit);

    res.json(filtered);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create/broadcast a notification (admin portal can call this)
// POST /api/notifications
router.post('/', async (req, res) => {
  try {
    const { type, title, message, metadata } = req.body || {};
    if (!title || !message) return res.status(400).json({ msg: 'title and message are required' });

    const notif = await Notification.create({
      type: type || 'general',
      title,
      message,
      metadata: metadata || {},
    });

    res.status(201).json(notif);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

