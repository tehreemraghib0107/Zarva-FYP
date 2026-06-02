const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema({
  type: { type: String, default: 'general' }, // product | promotion | general
  title: { type: String, required: true },
  message: { type: String, required: true },
  metadata: { type: Object, default: {} },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('Notification', NotificationSchema);

