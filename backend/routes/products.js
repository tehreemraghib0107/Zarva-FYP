const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const Inventory = require('../models/Inventory');
const Notification = require('../models/Notification');

// GET all products (with optional search)
router.get('/', async (req, res) => {
    try {
        const { q, category } = req.query;
        let query = {};

        if (q) {
            const term = q.trim().toLowerCase();

            // 1. SYNONYM MAPPING (Custom Keywords)
            // Map specific user terms to categories
            const synonyms = {
                'jhumka': 'Earrings',
                'earring': 'Earrings',
                'pendant': 'Necklaces',
                'chain': 'Necklaces',
                'bangle': 'Bracelets'
            };

            let matchedCategory = synonyms[term];

            // 2. SMART PREFIX MATCHING
            // If no synonym found, check if input starts with a known category name
            if (!matchedCategory) {
                const categories = ['Rings', 'Bracelets', 'Chokers', 'Lockets', 'Necklaces', 'Earrings'];
                matchedCategory = categories.find(c => c.toLowerCase().startsWith(term));
            }

            if (matchedCategory) {
                // If we found a category match (direct, synonym, or prefix), filter by that Category
                console.log(`Smart Search: Mapped '${q}' to Category '${matchedCategory}'`);
                query.category = { $regex: matchedCategory, $options: 'i' };
            } else {
                // 3. Fallback: Search by Name regex
                query.name = { $regex: q, $options: 'i' };
            }
        }

        if (category) {
            query.category = { $regex: category, $options: 'i' };
        }

        const products = await Product.find(query).lean();
        
        // Fetch inventory to attach remaining counts
        const inventories = await Inventory.find({ productId: { $in: products.map(p => p._id) } });
        const invMap = {};
        inventories.forEach(inv => invMap[inv.productId.toString()] = inv);

        const productsWithStock = products.map(p => {
            const inv = invMap[p._id.toString()];
            const quantity = inv ? inv.quantity : 0;
            const sold = inv ? inv.sold : 0;
            return {
                ...p,
                inventory: {
                    quantity,
                    sold,
                    remaining: quantity - sold
                }
            };
        });

        res.json(productsWithStock);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// SEED DATA (Run once)
router.get('/seed', async (req, res) => {
    try {
        await Product.deleteMany({}); // Clear existing

        const seedProducts = [
            // RINGS
            { name: 'Sapphire Blue Whispers', category: 'Rings', price: 'PKR 1500', image: 'assets/1R.png', description: 'A delicate sapphire ring with shimmering blue highlights.' },
            { name: 'Vintage Rosé Glow', category: 'Rings', price: 'PKR 3000', image: 'assets/2R.png', description: 'Classic rose gold vintage ring with a radiant central stone.' },
            { name: 'Ruby Regal Spark', category: 'Rings', price: 'PKR 2000', image: 'assets/3R.png', description: 'Majestic ruby ring designed for a royal elegance.' },
            { name: 'Bold Ruby Majesty', category: 'Rings', price: 'PKR 2500', image: 'assets/4R.png', description: 'A bold statement piece featuring a deep crimson ruby.' },
            { name: 'Mughal Pearl Mandala', category: 'Rings', price: 'PKR 2800', image: 'assets/5R.png', description: 'Traditional Mughal-inspired pearl ring with intricate mandala patterns.' },
            { name: 'Emerald Baroque Bloom', category: 'Rings', price: 'PKR 1800', image: 'assets/6R.png', description: 'Elegant emerald ring with baroque-style floral accents.' },

            // BRACELETS
            { name: 'Crystal Gold Bracelet', category: 'Bracelets', price: 'PKR 1200', image: 'assets/1B.png', description: 'Exquisite gold bracelet adorned with sparkling crystals.' },
            { name: 'Golden Floral Bracelet', category: 'Bracelets', price: 'PKR 1800', image: 'assets/2B.png', description: 'Nature-inspired golden bracelet with delicate floral motifs.' },
            { name: 'Sunburst Charm Bracelet', category: 'Bracelets', price: 'PKR 2500', image: 'assets/3B.png', description: 'Radiant charm bracelet inspired by the morning sunburst.' },
            { name: 'Turquoise Flower Bracelet', category: 'Bracelets', price: 'PKR 1500', image: 'assets/4B.png', description: 'Vibrant turquoise stones set in a beautiful flower arrangement.' },
            { name: 'Gilded Floral Bracelet', category: 'Bracelets', price: 'PKR 1600', image: 'assets/5B.png', description: 'Gilded bracelet featuring hand-crafted floral designs.' },

            // CHOKERS
            { name: 'Emerald Riviera Line', category: 'Chokers', price: 'PKR 2500', image: 'assets/1C.png', description: 'Modern emerald choker with a clean, sophisticated riviera line.' },
            { name: 'Pastel Mughal Dreams', category: 'Chokers', price: 'PKR 1000', image: 'assets/2C.png', description: 'Soft pastel colors in a traditional Mughal choker design.' },
            { name: 'Emerald Ice Choker', category: 'Chokers', price: 'PKR 3000', image: 'assets/3C.png', description: 'Stunning ice-clear emeralds set in a premium choker base.' },
            { name: 'Parisian Emerald Kiss', category: 'Chokers', price: 'PKR 4500', image: 'assets/4C.png', description: 'Romantic Parisian-inspired emerald choker for special occasions.' },
            { name: 'Royal Rani Choker', category: 'Chokers', price: 'PKR 1200', image: 'assets/5C.png', description: 'Regal rani choker with deep green emerald accents.' },
            { name: 'Pearl Polki Empress', category: 'Chokers', price: 'PKR 1500', image: 'assets/6C.png', description: 'Empress-style choker featuring traditional polki and pearls.' },

            // LOCKETS
            { name: 'Mughal Midnight Elegance', category: 'Lockets', price: 'PKR 1600', image: 'assets/1L.png', description: 'Midnight-toned locket with intricate Mughal craftsmanship.' },
            { name: 'Vintage Polki Grandeur', category: 'Lockets', price: 'PKR 1800', image: 'assets/2L.png', description: 'Grand vintage locket with traditional polki settings.' },

            // NECKLACES
            { name: 'Royal Green Brilliance', category: 'Necklaces', price: 'PKR 5000', image: 'assets/2N.png', description: 'Luxurious royal green necklace with brilliant cut stones.' },
            { name: 'Antique Emerald Grace', category: 'Necklaces', price: 'PKR 3500', image: 'assets/3N.png', description: 'Graceful antique necklace featuring natural emeralds.' },
            { name: 'Modern Royal Sparkle', category: 'Necklaces', price: 'PKR 2800', image: 'assets/4N.png', description: 'A contemporary take on royal sparkle for the modern woman.' },
            { name: 'Classic Emerald Bloom', category: 'Necklaces', price: 'PKR 2000', image: 'assets/7N.png', description: 'Timeless emerald necklace with a blooming floral center.' },

            // EARRINGS
            { name: 'Emerald Noor Jhumka', category: 'Earrings', price: 'PKR 2200', image: 'assets/1E.png', description: 'Traditional Noor Jhumkas with radiant emerald drops.' },
            { name: 'Midnight Pearl', category: 'Earrings', price: 'PKR 1500', image: 'assets/2E.png', description: 'Elegant midnight pearl earrings for formal evenings.' },
            { name: 'Royal Blue', category: 'Earrings', price: 'PKR 1200', image: 'assets/3E.png', description: 'Classic royal blue earrings with a touch of gold.' },
            { name: 'Neelam Crescent', category: 'Earrings', price: 'PKR 1800', image: 'assets/4E.png', description: 'Traditional crescent-shaped earrings with Neelam stones.' },
            { name: 'Teal Gulnaar', category: 'Earrings', price: 'PKR 3000', image: 'assets/5E.png', description: 'Vibrant teal earrings in a traditional Gulnaar pattern.' },
            { name: 'Zamrud Royale', category: 'Earrings', price: 'PKR 1400', image: 'assets/6E.png', description: 'Royale Zamrud (Emerald) earrings with premium finishing.' },
            { name: 'Black Heirloom', category: 'Earrings', price: 'PKR 2500', image: 'assets/7E.png', description: 'Timeless black heirloom earrings inherited with grace.' },
            { name: 'Sapphire Noor', category: 'Earrings', price: 'PKR 2000', image: 'assets/8E.png', description: 'Exquisite sapphire earrings inspired by the morning light.' },
        ];

        await Product.insertMany(seedProducts);
        res.json({ msg: "Database seeded successfully", count: seedProducts.length });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ADD New Product
router.post('/', async (req, res) => {
    try {
        const { name, category, price, image, description } = req.body;
        const newProduct = new Product({ name, category, price, image, description });
        await newProduct.save();

        // Create associated empty inventory
        await Inventory.create({ productId: newProduct._id, quantity: 10, sold: 0 }); // Default 10 if not specified

        // Broadcast notification to mobile users
        await Notification.create({
            type: 'product',
            title: 'New Product Added',
            message: `${newProduct.name} is now available in ${newProduct.category}.`,
            metadata: {
                productId: String(newProduct._id),
                category: newProduct.category,
                image: newProduct.image
            }
        });
        
        res.status(201).json(newProduct);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// UPDATE Product
router.put('/:id', async (req, res) => {
    try {
        const product = await Product.findByIdAndUpdate(req.params.id, req.body, { new: true });
        if (!product) return res.status(404).json({ msg: "Product not found" });
        res.json(product);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET single product by id
router.get('/:id', async (req, res) => {
    try {
        const product = await Product.findById(req.params.id).lean();
        if (!product) return res.status(404).json({ msg: "Product not found" });

        const inv = await Inventory.findOne({ productId: product._id });
        const quantity = inv ? inv.quantity : 0;
        const sold = inv ? inv.sold : 0;
        res.json({
            ...product,
            inventory: {
                quantity,
                sold,
                remaining: quantity - sold
            }
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE Product
router.delete('/:id', async (req, res) => {
    try {
        const product = await Product.findByIdAndDelete(req.params.id);
        if (!product) return res.status(404).json({ msg: "Product not found" });
        res.json({ msg: "Product removed" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;
