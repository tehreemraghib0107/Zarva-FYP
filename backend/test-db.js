const mongoose = require('mongoose');
require('dotenv').config();

console.log("Testing connection from .env...");
mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 15000,
})
    .then(() => {
        console.log("✅ SUCCESS: Connected to MongoDB!");
        process.exit(0);
    })
    .catch(err => {
        console.error("❌ FAILURE:", err.message);
        process.exit(1);
    });
