const express = require('express');
const router = express.Router();

const Promotion = require('../models/Promotion');
const Notification = require('../models/Notification');

async function expireOldPromotions() {
  const now = new Date();
  await Promotion.updateMany(
    { isActive: true, expiresAt: { $lt: now } },
    { $set: { isActive: false } }
  );
}

function normalizeCode(code = '') {
  return String(code).trim().toUpperCase();
}

// Mobile/customer: get active promotions
router.get('/active', async (_req, res) => {
  try {
    await expireOldPromotions();
    const now = new Date();
    const active = await Promotion.find({
      isActive: true,
      startsAt: { $lte: now },
      expiresAt: { $gte: now },
    }).sort({ createdAt: -1 });
    res.json(active);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Mobile/customer: validate promo code
router.get('/validate/:code', async (req, res) => {
  try {
    await expireOldPromotions();
    const now = new Date();
    const code = normalizeCode(req.params.code);
    const promo = await Promotion.findOne({
      code,
      isActive: true,
      startsAt: { $lte: now },
      expiresAt: { $gte: now },
    });
    if (!promo) return res.status(404).json({ msg: 'Promo code is invalid or expired' });
    res.json(promo);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: list all promotions
router.get('/', async (_req, res) => {
  try {
    await expireOldPromotions();
    const all = await Promotion.find({}).sort({ createdAt: -1 });
    res.json(all);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Admin: create promotion
router.post('/', async (req, res) => {
  try {
    const { title, code, discountPercent, startsAt, expiresAt } = req.body || {};
    if (!title || !code || !discountPercent || !startsAt || !expiresAt) {
      return res.status(400).json({ msg: 'title, code, discountPercent, startsAt, expiresAt are required' });
    }

    const starts = new Date(startsAt);
    const ends = new Date(expiresAt);
    if (Number.isNaN(starts.getTime()) || Number.isNaN(ends.getTime())) {
      return res.status(400).json({ msg: 'Invalid startsAt or expiresAt' });
    }
    if (ends <= starts) return res.status(400).json({ msg: 'expiresAt must be after startsAt' });

    const promo = await Promotion.create({
      title: String(title).trim(),
      code: normalizeCode(code),
      discountPercent: Number(discountPercent),
      startsAt: starts,
      expiresAt: ends,
      isActive: true,
    });

    // Create broadcast notification for mobile users
    await Notification.create({
      type: 'promotion',
      title: 'New Promotion',
      message: `${promo.title} is live! Use code ${promo.code} for ${promo.discountPercent}% OFF.`,
      metadata: {
        code: promo.code,
        discountPercent: promo.discountPercent,
        startsAt: promo.startsAt,
        expiresAt: promo.expiresAt,
      },
    });

    res.status(201).json(promo);
  } catch (err) {
    if (err.code === 11000) {
      return res.status(400).json({ msg: 'Promo code already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// Admin: deactivate / delete
router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Promotion.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ msg: 'Promotion not found' });

    // Remove corresponding promotion notification so it disappears from mobile feed
    await Notification.deleteMany({
      type: 'promotion',
      'metadata.code': deleted.code,
    });

    res.json({ msg: 'Promotion deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

