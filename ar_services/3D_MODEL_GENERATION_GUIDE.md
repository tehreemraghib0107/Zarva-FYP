# 3D Jewelry Model Generation & AR Integration

This guide explains how to automatically generate 3D models from your 2D product images and integrate them into the AR try-on system.

---

## **Architecture Overview**

```
Product Images (2D)
       ↓
[Python: Image Processing + 3D Mesh Generation]
       ↓
3D Models (GLB format)
       ↓
[Node.js: Upload to Server + Update Database]
       ↓
Product Documents (with 3D model URLs)
       ↓
[Flutter Web AR: Fetch & Display 3D models]
       ↓
User AR Try-On Experience
```

---

## **Setup Instructions**

### **Step 1: Install Dependencies**

```bash
# Install Python dependencies for 3D generation
cd ai_services
pip install -r requirements.txt

# Verify trimesh installation
python -c "import trimesh; print('✓ trimesh installed')"
```

### **Step 2: Prepare Your Product Images**

Ensure product images are in:
```
backend/uploads/
├── 1R.png (Rings)
├── 2R.png
├── 1B.png (Bracelets)
├── 1C.png (Chokers)
└── ... (other jewelry images)
```

---

## **Step 3: Generate 3D Models**

### **Option A: Python Script Only**

```bash
cd ai_services
python scripts/generate_3d_models.py \
  --input-dir ../backend/uploads \
  --output-dir ./models/glb
```

**Output:**
- Generated GLB files in `ai_services/models/glb/`
- Metadata file: `ai_services/models/glb/models_metadata.json`

### **Option B: Full Pipeline (Python + Node.js)**

This automatically generates models, uploads to server, and updates database:

```bash
cd backend
npm run generate-3d-models
```

Or manually:

```bash
node scripts/generate_and_upload_3d_models.js
```

**What it does:**
1. Calls Python script to generate 3D models
2. Copies GLB files to `backend/public/models/glb/`
3. Updates MongoDB products with model URLs
4. Creates model metadata JSON

---

## **Step 4: Verify Generated Models**

Check metadata file:
```bash
cat ai_services/models/glb/models_metadata.json
```

Expected output:
```json
[
  {
    "product_name": "Sapphire Blue Whispers",
    "category": "Rings",
    "model_path": "ai_services/models/glb/sapphire_blue_whispers.glb",
    "model_url": "/models/glb/sapphire_blue_whispers.glb"
  }
]
```

---

## **Step 5: Test in Flutter Web**

### **Run Backend Server**
```bash
cd backend
npm start
```

Backend will serve models at:
```
http://localhost:3000/models/glb/[modelname].glb
```

### **Run Flutter Web App**
```bash
cd mobile_app
flutter run -d chrome
```

Navigate to AR try-on screen and verify:
- ✅ Camera initializes
- ✅ Face tracking works
- ✅ "Try Earrings" & "Try Necklace" buttons show 3D models
- ✅ Models anchor to face landmarks

---

## **3D Model Generation Details**

### **How It Works**

The Python script processes images using:

1. **Image Analysis**
   - Background removal via color thresholding
   - Depth estimation from image brightness
   - Silhouette extraction

2. **3D Mesh Generation**
   - **Rings**: Torus geometry with depth variation
   - **Earrings**: Elongated sphere (teardrop shape)
   - **Necklaces**: Pendant geometry with vertical stretch
   - **Bracelets**: Full torus (circular band)
   - **Generic**: Box geometry with depth scaling

3. **Texturing**
   - Average color from product image applied to vertices
   - Maintains visual fidelity with 2D source

4. **Export**
   - GLB format (binary glTF) for web compatibility
   - Optimized for mobile/AR performance

### **Customization**

Edit geometry parameters in `ai_services/scripts/generate_3d_models.py`:

```python
def _create_ring_mesh(self, image, mask, depth):
    major_radius = 2.0  # Adjust ring width
    minor_radius = 0.6  # Adjust ring thickness
    # ...
```

---

## **API Endpoints**

### **Get Product with AR Models**
```
GET /api/products/:id/ar-models
```

Response:
```json
{
  "productId": "...",
  "productName": "Gold Earrings",
  "category": "Earrings",
  "earringsModelUrl": "http://localhost:3000/models/glb/gold_earrings.glb",
  "necklaceModelUrl": null,
  "genericModelUrl": null
}
```

### **List All Products with Models**
```
GET /api/products
```

Each product includes `earringsModel3dUrl`, `necklaceModel3dUrl`, `model3dUrl`.

---

## **Troubleshooting**

### **❌ `trimesh not installed`**
```bash
pip install trimesh
```

### **❌ Model files not generated**
Check permissions:
```bash
ls -la ai_services/models/
chmod 755 ai_services/models/glb
```

### **❌ Models not loading in AR**
1. Verify backend is running:
   ```bash
   curl http://localhost:3000/models/glb/
   ```

2. Check browser console for CORS errors

3. Verify model URLs in database:
   ```bash
   # In MongoDB
   db.products.findOne({ name: "Sapphire Blue Whispers" })
   # Should show: earringsModel3dUrl: "http://..."
   ```

### **❌ AR app can't fetch models**
Update `ar_product_model_service.dart`:
```dart
static const String _baseUrl = 'http://YOUR_BACKEND_IP:3000/api/products';
```

---

## **Advanced: Using External 3D Models**

Instead of auto-generated models, use professional GLB files:

1. Download models from:
   - [Sketchfab](https://sketchfab.com) (free with license)
   - [TurboSquid](https://www.turbosquid.com) (free tier)
   - [CGTrader](https://www.cgtrader.com) (free models)

2. Upload to CDN:
   ```bash
   # Upload to Vercel, Netlify, or AWS S3
   gsutil cp models/*.glb gs://your-bucket/models/
   ```

3. Update product URLs manually or via script:
   ```bash
   db.products.updateOne(
     { name: "Gold Earrings" },
     { $set: { earringsModel3dUrl: "https://cdn.example.com/gold_earrings.glb" } }
   )
   ```

---

## **Performance Optimization**

### **Reduce GLB File Size**
```bash
# Use gltf-pipeline to optimize
npx gltf-pipeline -i model.glb -o model-optimized.glb
```

### **Enable Model Caching**
Flutter automatically caches downloaded GLB files. No additional config needed.

### **Load Models on Demand**
Models are only loaded when user clicks "Try Earrings" or "Try Necklace":
```dart
// In ar_jewelry_tryon_screen.dart
if (visible.earrings && !modelsLoaded.earrings) {
  ensureModels();
}
```

---

## **Next Steps**

✅ Generated 3D models from product images
✅ Integrated into Flutter Web AR
✅ Database-driven model URLs
✅ Real-time face-tracked jewelry fitting

**Future Enhancements:**
- Upload to cloud CDN (AWS S3, Cloudinary)
- AI-powered pose estimation for better anchor accuracy
- Shadow mapping and advanced lighting
- Animation support for animated jewelry

---

## **Support**

For issues or questions:
1. Check troubleshooting section above
2. Review generated `models_metadata.json`
3. Verify database product documents
4. Check Flutter web console for errors
