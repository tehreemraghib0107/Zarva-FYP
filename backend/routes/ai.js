const express = require('express');
const router = express.Router();
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 12 * 1024 * 1024 },
});

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

/**
 * POST /api/ai/recommend
 * Proxies multipart outfit analysis to the Python FastAPI ML service.
 */
router.post('/recommend', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Image file is required.' });
    }

    const userId = req.body.userId || req.body.userid || 'guest';
    const dressColor = req.body.dressColor ?? req.body.dresscolor ?? '';
    const skinTone = req.body.skinTone ?? req.body.skintone ?? '';
    const manualNeckline = req.body.manualNeckline ?? req.body.manualneckline ?? '';
    const userQuery = req.body.userQuery ?? req.body.userquery ?? req.body.message ?? '';

    const form = new FormData();
    form.append('image', req.file.buffer, {
      filename: req.file.originalname || 'outfit.jpg',
      contentType: req.file.mimetype || 'image/jpeg',
    });
    form.append('userId', userId);
    form.append('dressColor', dressColor);
    form.append('skinTone', skinTone);
    form.append('manualNeckline', manualNeckline);
    form.append('userQuery', userQuery);

    const mlResponse = await axios.post(
      `${AI_SERVICE_URL}/api/ai/recommend`,
      form,
      {
        headers: form.getHeaders(),
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
        timeout: 120000,
      }
    );

    return res.status(mlResponse.status).json(mlResponse.data);
  } catch (err) {
    const status = err.response?.status || 502;
    const detail =
      err.response?.data?.error ||
      err.response?.data?.detail ||
      err.message ||
      'AI service unavailable';
    console.error('[AI Proxy recommend]', detail);
    return res.status(status).json({
      success: false,
      error: typeof detail === 'string' ? detail : JSON.stringify(detail),
    });
  }
});

module.exports = router;
