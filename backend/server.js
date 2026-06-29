const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const path = require('path');

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// Serve static assets from the mobile_app directory
const mobileAppPath = path.join(__dirname, '..', 'mobile_app');
app.use('/assets', express.static(path.join(mobileAppPath, 'assets')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Serve AR cropped assets from ar_services/AR
const arPath = path.join(__dirname, '..', 'ar_services', 'AR');
app.use('/ar', express.static(arPath));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/favorites', require('./routes/favorites'));
app.use('/api/wishlist', require('./routes/wishlist'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/reviews', require('./routes/reviews'));
app.use('/api/promotions', require('./routes/promotions'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/inventory', require('./routes/inventory'));
app.use('/api/analytics', require('./routes/analytics'));
app.use('/api/ai', require('./routes/ai'));
app.use('/api/chat', require('./routes/chat'));
// Connect to MongoDB Atlas
// PLACE YOUR MONGODB ATLAS CONNECTION STRING IN THE .env FILE UNDER 'MONGO_URI'
mongoose.connect(process.env.MONGO_URI, {
  serverSelectionTimeoutMS: 30000, // 30 seconds
  socketTimeoutMS: 45000,          // 45 seconds
})
  .then(() => console.log("✅ ZARVA Database Connected!"))
  .catch(err => {
    console.error("❌ Connection Error:", err.message);
    if (err.message.includes("whitelist")) {
      console.error("👉 TIP: Check your MongoDB Atlas Network Access. You might need to whitelist your current IP address.");
    }
  });

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));