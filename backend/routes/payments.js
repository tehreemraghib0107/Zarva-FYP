const express = require('express');
const router = express.Router();
const axios = require('axios');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const Order = require('../models/Order');

// Auth middleware (same style as other routes)
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

function hmacSignature(secret, payloadObj) {
  // Stable signing: sort keys
  const keys = Object.keys(payloadObj).sort();
  const base = keys.map((k) => `${k}=${String(payloadObj[k] ?? '')}`).join('&');
  return crypto.createHmac('sha256', secret).update(base).digest('hex');
}

// Step A/B: Initiate Payment
// POST /api/payments/initiate
// body: { orderDbId, provider, phoneNumber }
router.post('/initiate', auth, async (req, res) => {
  try {
    const { orderDbId, provider, phoneNumber } = req.body || {};
    if (!orderDbId) return res.status(400).json({ msg: 'orderDbId is required' });
    if (!provider) return res.status(400).json({ msg: 'provider is required (EasyPaisa/JazzCash)' });
    if (!phoneNumber) return res.status(400).json({ msg: 'phoneNumber is required' });

    const order = await Order.findById(orderDbId);
    if (!order) return res.status(404).json({ msg: 'Order not found' });
    if (String(order.userId) !== String(req.user.id)) return res.status(403).json({ msg: 'Forbidden' });

    if (order.paymentStatus === 'Paid') {
      return res.json({ msg: 'Already paid', paymentStatus: order.paymentStatus, transactionId: order.transactionId });
    }

    // Configure aggregator via env (works for PayFast/Foree/Blink if you set these correctly)
    const baseUrl = process.env.AGGREGATOR_BASE_URL;
    const merchantId = process.env.AGGREGATOR_MERCHANT_ID;
    const secret = process.env.AGGREGATOR_SECRET;
    const callbackUrl = process.env.PAYMENT_CALLBACK_URL || 'http://localhost:5000/api/payments/callback';
    const initPath = process.env.AGGREGATOR_INIT_PATH || '/payments/initiate';

    if (!baseUrl || !merchantId || !secret) {
      // Safe dev mode (so app can still run)
      const tx = `TX-${Date.now()}`;
      order.paymentStatus = 'Pending';
      order.paymentProvider = String(provider);
      order.transactionId = tx;
      await order.save();
      return res.status(200).json({
        provider,
        transactionId: tx,
        paymentUrl: `https://example.com/pay?tx=${encodeURIComponent(tx)}`,
        callbackUrl,
        mode: 'mock',
      });
    }

    const transactionId = `ZARVA-${order.orderId}-${Date.now()}`;
    const payload = {
      merchantId,
      provider,
      transactionId,
      orderId: order.orderId,
      orderDbId: String(order._id),
      amount: order.totalAmount,
      phoneNumber,
      callbackUrl,
    };

    const signature = hmacSignature(secret, payload);
    const requestBody = { ...payload, signature };

    // Save pending transaction before redirect/handshake
    order.paymentStatus = 'Pending';
    order.paymentProvider = String(provider);
    order.transactionId = transactionId;
    await order.save();

    const resp = await axios.post(`${baseUrl}${initPath}`, requestBody, { timeout: 30000 });

    // Expected aggregator response: { paymentUrl, ... }
    const paymentUrl = resp.data?.paymentUrl || resp.data?.redirectUrl || resp.data?.url;
    if (!paymentUrl) {
      return res.status(502).json({ msg: 'Aggregator did not return paymentUrl', raw: resp.data });
    }

    return res.json({
      provider,
      transactionId,
      paymentUrl,
      raw: resp.data,
      mode: 'live',
    });
  } catch (err) {
    console.error('PAYMENT_INIT_ERR', err?.response?.data || err.message);
    return res.status(500).json({ msg: 'Failed to initiate payment' });
  }
});

// FREE/FYP: Mock confirm endpoint (no external gateway needed)
// POST /api/payments/mock/confirm (auth required)
// body: { orderDbId }
router.post('/mock/confirm', auth, async (req, res) => {
  try {
    const { orderDbId } = req.body || {};
    if (!orderDbId) return res.status(400).json({ msg: 'orderDbId is required' });

    // Only allow this when aggregator is NOT configured (so it can't be abused in real mode)
    const baseUrl = process.env.AGGREGATOR_BASE_URL;
    const merchantId = process.env.AGGREGATOR_MERCHANT_ID;
    const secret = process.env.AGGREGATOR_SECRET;
    if (baseUrl || merchantId || secret) {
      return res.status(400).json({ msg: 'Mock confirm disabled (aggregator configured)' });
    }

    const order = await Order.findById(orderDbId);
    if (!order) return res.status(404).json({ msg: 'Order not found' });
    if (String(order.userId) !== String(req.user.id)) return res.status(403).json({ msg: 'Forbidden' });

    order.paymentStatus = 'Paid';
    order.paidAt = new Date();
    if (order.status === 'Pending') order.status = 'Processing';
    await order.save();

    return res.json({ ok: true, paymentStatus: order.paymentStatus });
  } catch (err) {
    console.error('MOCK_CONFIRM_ERR', err.message);
    return res.status(500).json({ msg: 'Mock confirm failed' });
  }
});

// Step D: Callback / Webhook from aggregator
// POST /api/payments/callback
router.post('/callback', async (req, res) => {
  try {
    const secret = process.env.AGGREGATOR_SECRET;
    if (!secret) return res.status(500).json({ msg: 'Server not configured (AGGREGATOR_SECRET missing)' });

    const {
      transactionId,
      orderDbId,
      status, // expected: Paid/Failed/etc
      signature,
    } = req.body || {};

    if (!transactionId || !orderDbId || !status || !signature) {
      return res.status(400).json({ msg: 'Missing required callback fields' });
    }

    const expected = hmacSignature(secret, { transactionId, orderDbId, status });
    if (expected !== signature) {
      return res.status(401).json({ msg: 'Invalid signature' });
    }

    const order = await Order.findById(orderDbId);
    if (!order) return res.status(404).json({ msg: 'Order not found' });

    // Update payment status
    const normalizedStatus = String(status).toLowerCase();
    if (normalizedStatus === 'paid' || normalizedStatus === 'success') {
      order.paymentStatus = 'Paid';
      order.status = order.status === 'Pending' ? 'Processing' : order.status;
      order.paidAt = new Date();
    } else if (normalizedStatus === 'failed' || normalizedStatus === 'cancelled' || normalizedStatus === 'canceled') {
      order.paymentStatus = 'Failed';
    } else {
      order.paymentStatus = 'Pending';
    }

    order.transactionId = transactionId;
    await order.save();

    // Respond 200 so provider stops retrying
    return res.json({ ok: true });
  } catch (err) {
    console.error('PAYMENT_CB_ERR', err.message);
    return res.status(500).json({ msg: 'Callback handling failed' });
  }
});

module.exports = router;

