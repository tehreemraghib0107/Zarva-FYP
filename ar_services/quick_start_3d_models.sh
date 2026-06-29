#!/bin/bash
# Quick Start: Generate 3D Models from Product Images
# 
# This script runs the complete 3D model generation pipeline:
# 1. Python: Convert 2D images → 3D GLB models
# 2. Node.js: Upload to server + Update MongoDB
# 3. Verification: Test AR with generated models

set -e

echo "🎨 3D Jewelry Model Generation Pipeline"
echo "========================================"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo "${YELLOW}[1/5]${NC} Checking prerequisites..."

if ! command -v python3 &> /dev/null; then
    echo "${RED}❌ Python 3 not found. Install from https://www.python.org${NC}"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "${RED}❌ Node.js not found. Install from https://nodejs.org${NC}"
    exit 1
fi

echo "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Install Python dependencies
echo "${YELLOW}[2/5]${NC} Installing Python dependencies..."
cd ai_services
pip install -r requirements.txt -q
echo "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Generate 3D models
echo "${YELLOW}[3/5]${NC} Generating 3D models from product images..."
python scripts/generate_3d_models.py \
    --input-dir ../backend/uploads \
    --output-dir ./models/glb
echo "${GREEN}✓ 3D models generated${NC}"
echo ""

# Upload and update database
echo "${YELLOW}[4/5]${NC} Uploading models to server and updating database..."
cd ../backend
npm run generate-3d-models
echo "${GREEN}✓ Models uploaded and linked${NC}"
echo ""

# Final verification
echo "${YELLOW}[5/5]${NC} Verifying setup..."

if [ -f "ai_services/models/glb/models_metadata.json" ]; then
    MODEL_COUNT=$(grep -c "product_name" ai_services/models/glb/models_metadata.json || echo "0")
    echo "${GREEN}✓ Generated $MODEL_COUNT 3D models${NC}"
else
    echo "${YELLOW}⚠ Metadata file not found${NC}"
fi

echo ""
echo "${GREEN}✅ Complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Start backend:  cd backend && npm start"
echo "  2. Start app:      cd mobile_app && flutter run -d chrome"
echo "  3. Test AR:        Navigate to product → Try in AR"
echo ""
