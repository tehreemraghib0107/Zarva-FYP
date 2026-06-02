const express = require('express');
const router = express.Router();
const axios = require('axios');
const FormData = require('form-data');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

/**
 * POST /api/chat/text
 */
router.post('/text', express.urlencoded({ extended: true }), async (req, res) => {
  try {
    const userId = req.body.userId || req.body.userid || 'guest';
    const userQuery = req.body.userQuery || req.body.userquery || req.body.message || '';

    const form = new FormData();
    form.append('userId', userId);
    form.append('userQuery', userQuery);

    const mlResponse = await axios.post(`${AI_SERVICE_URL}/api/chat/text`, form, {
      headers: form.getHeaders(),
      timeout: 30000,
    });

    return res.status(mlResponse.status).json(mlResponse.data);
  } catch (err) {
    const status = err.response?.status || 502;
    const detail =
      err.response?.data?.error ||
      err.response?.data?.detail ||
      err.message ||
      'AI text service unavailable';
    console.error('[Chat Proxy text]', detail);
    return res.status(status).json({
      success: false,
      error: typeof detail === 'string' ? detail : JSON.stringify(detail),
    });
  }
});

module.exports = router;
