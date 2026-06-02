const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String }, // Optional for Google users
  googleId: { type: String }, // Used for Google Signup
  role: { type: String, default: 'customer' }, // Admin or Customer
  profileImage: { type: String, default: "" } // Base64 or Image URL
});

module.exports = mongoose.model('User', UserSchema); // This exports the model for auth.js to use