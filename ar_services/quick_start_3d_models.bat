@echo off
REM Quick Start: Generate 3D Models from Product Images (Windows)
REM 
REM This script runs the complete 3D model generation pipeline:
REM 1. Python: Convert 2D images → 3D GLB models
REM 2. Node.js: Upload to server + Update MongoDB
REM 3. Verification: Test AR with generated models

echo.
echo 🎨 3D Jewelry Model Generation Pipeline
echo ========================================
echo.

REM Check Python
echo [1/5] Checking prerequisites...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found. Install from https://www.python.org
    exit /b 1
)

REM Check Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js not found. Install from https://nodejs.org
    exit /b 1
)

echo ✓ Prerequisites OK
echo.

REM Install dependencies
echo [2/5] Installing Python dependencies...
cd ai_services
pip install -r requirements.txt -q
if errorlevel 1 (
    echo ❌ Failed to install dependencies
    exit /b 1
)
echo ✓ Dependencies installed
echo.

REM Generate models
echo [3/5] Generating 3D models from product images...
python scripts\generate_3d_models.py --input-dir ..\backend\uploads --output-dir .\models\glb
if errorlevel 1 (
    echo ❌ Model generation failed
    exit /b 1
)
echo ✓ 3D models generated
echo.

REM Upload and update
echo [4/5] Uploading models to server and updating database...
cd ..\backend
call npm run generate-3d-models
if errorlevel 1 (
    echo ❌ Upload/update failed
    exit /b 1
)
echo ✓ Models uploaded and linked
echo.

REM Verify
echo [5/5] Verifying setup...
if exist "..\ai_services\models\glb\models_metadata.json" (
    echo ✓ Models metadata found
) else (
    echo ⚠ Metadata file not found
)

echo.
echo ✅ Complete!
echo.
echo Next steps:
echo   1. Start backend:  cd backend ^&^& npm start
echo   2. Start app:      cd mobile_app ^&^& flutter run -d chrome
echo   3. Test AR:        Navigate to product ^-^> Try in AR
echo.
pause
