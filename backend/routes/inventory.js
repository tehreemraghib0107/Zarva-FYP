const express = require('express');
const router = express.Router();
const Inventory = require('../models/Inventory');
const Product = require('../models/Product');
const Favorite = require('../models/Favorite');
const Notification = require('../models/Notification');

// GET all inventory items with product details
router.get('/', async (req, res) => {
    try {
        // Auto-sync missing inventory
        const products = await Product.find();
        for (const product of products) {
            const exists = await Inventory.findOne({ productId: product._id });
            if (!exists) {
                await Inventory.create({ productId: product._id, quantity: 100, sold: 0 });
            }
        }

        const inventory = await Inventory.find().populate('productId', 'name image category');
        res.json(inventory);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET inventory for a specific product
router.get('/product/:productId', async (req, res) => {
    try {
        const inventory = await Inventory.findOne({ productId: req.params.productId });
        if (!inventory) return res.status(404).json({ msg: "Inventory not found for this product" });
        res.json(inventory);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// UPDATE inventory quantity by Admin
router.put('/:id', async (req, res) => {
    try {
        const { quantity } = req.body;
        const existing = await Inventory.findById(req.params.id).populate('productId', 'name image category');
        if (!existing) return res.status(404).json({ msg: "Inventory record not found" });

        const prevRemaining = Number(existing.quantity || 0) - Number(existing.sold || 0);

        existing.quantity = Number(quantity);
        await existing.save();

        const inventory = await Inventory.findById(req.params.id).populate('productId', 'name image category');

        const newRemaining = Number(inventory.quantity || 0) - Number(inventory.sold || 0);

        // If product moved from out-of-stock to available, notify users and clear wishlist records
        if (prevRemaining <= 0 && newRemaining > 0 && inventory.productId) {
            await Notification.create({
                type: 'restock',
                title: 'Product Restocked',
                message: `${inventory.productId.name} is back in stock.`,
                metadata: {
                    productId: String(inventory.productId._id),
                    image: inventory.productId.image,
                    category: inventory.productId.category
                }
            });

            // Remove from all wishlists when restocked (as requested)
            await Favorite.deleteMany({ productId: inventory.productId._id });
        }

        res.json(inventory);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Seeding/Syncing inventory (adds missing inventory records for products without them)
router.post('/sync', async (req, res) => {
    try {
        const products = await Product.find();
        let addedCount = 0;
        for (const product of products) {
            const exists = await Inventory.findOne({ productId: product._id });
            if (!exists) {
                await Inventory.create({ productId: product._id, quantity: 100, sold: 0 }); // Default seed
                addedCount++;
            }
        }
        res.json({ msg: "Inventory synced", addedCount });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
