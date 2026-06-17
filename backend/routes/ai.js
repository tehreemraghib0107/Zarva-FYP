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

/**
 * GET /api/ai/ar-asset?url=
 * Proxies product images with CORS headers for browser canvas extraction.
 */
router.get('/ar-asset', async (req, res) => {
  try {
    const targetUrl = req.query.url;
    if (!targetUrl || typeof targetUrl !== 'string') {
      return res.status(400).json({ success: false, error: 'url query param is required.' });
    }

    const response = await axios.get(targetUrl, {
      responseType: 'arraybuffer',
      timeout: 30000,
    });

    const contentType = response.headers['content-type'] || 'image/png';
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=3600');
    return res.send(Buffer.from(response.data));
  } catch (err) {
    console.error('[AI Proxy ar-asset]', err.message);
    return res.status(502).json({ success: false, error: 'Failed to proxy AR asset.' });
  }
});

/**
 * POST /api/ai/extract-jewelry
 * Proxies product image to Python YOLO extraction pipeline for AR overlays.
 */
router.post('/extract-jewelry', async (req, res) => {
  try {
    const { imageUrl, category } = req.body;
    if (!imageUrl) {
      return res.status(400).json({ success: false, error: 'imageUrl is required.' });
    }

    const form = new FormData();
    form.append('imageUrl', imageUrl);
    form.append('category', category || 'necklace');

    const mlResponse = await axios.post(
      `${AI_SERVICE_URL}/api/ai/extract-jewelry`,
      form,
      {
        headers: form.getHeaders(),
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
      'Jewelry extraction service unavailable';
    console.error('[AI Proxy extract-jewelry]', detail);
    return res.status(status).json({
      success: false,
      error: typeof detail === 'string' ? detail : JSON.stringify(detail),
    });
  }
});

module.exports = router;
