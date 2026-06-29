const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Create uploads folder if it doesn't exist
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir);
}

// Multer storage configuration
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        const originalName = file.originalname;
        const targetPath = path.join(uploadDir, originalName);
        if (!fs.existsSync(targetPath)) {
            cb(null, originalName);
        } else {
            const ext = path.extname(originalName);
            const base = path.basename(originalName, ext);
            cb(null, `${base}-${Date.now()}${ext}`);
        }
    }
});

const upload = multer({ storage: storage });

// POST endpoint for image upload
router.post('/', upload.single('image'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ msg: 'No file uploaded' });
        }
        // The return path that will be stored in database, e.g. "uploads/filename.png"
        const finalPath = `uploads/${req.file.filename}`;
        res.status(200).json({ filePath: finalPath });
    } catch (err) {
        console.error('Error uploading file:', err);
        res.status(500).json({ error: 'Server error during upload' });
    }
});

module.exports = router;
