const mongoose = require('mongoose');

const InventorySchema = new mongoose.Schema({
    productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true, unique: true },
    quantity: { type: Number, default: 0 },
    sold: { type: Number, default: 0 }
    // remaining can be computed as quantity - sold, or stored explicitly. We'll compute it dynamically for accuracy.
});

module.exports = mongoose.model('Inventory', InventorySchema);
