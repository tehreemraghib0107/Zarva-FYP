const mongoose = require('mongoose');

const OrderSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    orderId: { type: String, required: true }, // Custom readable Order ID
    items: [
        {
            productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product' },
            name: { type: String, required: true },
            price: { type: Number, required: true },
            quantity: { type: Number, required: true },
            size: { type: String, default: '' },
            image: { type: String }
        }
    ],
    totalAmount: { type: Number, required: true },
    shippingFee: { type: Number, default: 250 },
    promoCode: { type: String, default: '' },
    discountPercent: { type: Number, default: 0 },
    discountAmount: { type: Number, default: 0 },
    status: { type: String, default: 'Pending' },
    paymentMethod: { type: String, required: true }, // COD, EasyPaisa, JazzCash
    paymentStatus: { type: String, default: 'Unpaid' }, // Unpaid, Pending, Paid, Failed
    paymentProvider: { type: String, default: '' }, // aggregator/provider identifier
    transactionId: { type: String, default: '' }, // gateway transaction reference
    paidAt: { type: Date },
    customerName: { type: String, required: true },
    customerEmail: { type: String, required: true },
    phoneNumber: { type: String, required: true },
    shippingAddress: { type: String, required: true },
    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Order', OrderSchema);
