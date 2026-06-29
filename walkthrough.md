# Zarva FYP - Complete Project Walkthrough

This document provides a comprehensive guide to the Zarva jewelry e-commerce platform, covering project architecture, setup procedures, feature implementations, and development workflows.

---

## 📑 Table of Contents

1. [Project Architecture](#project-architecture)
2. [Complete Setup Guide](#complete-setup-guide)
3. [Backend Deep Dive](#backend-deep-dive)
4. [Mobile App Deep Dive](#mobile-app-deep-dive)
5. [AR/AI Services](#arai-services)
6. [Testing & Verification](#testing--verification)
7. [Deployment Guide](#deployment-guide)
8. [Common Issues & Solutions](#common-issues--solutions)

---

## 1. Project Architecture

### System Overview

Zarva is a microservices-based e-commerce platform with the following architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                     Zarva E-Commerce Platform                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Flutter App  │  │  Admin Panel │  │   Web Client     │  │
│  │ (Mobile)     │  │  (Vue.js)    │  │   (Future)       │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                  │                    │            │
│         └──────────────────┼────────────────────┘            │
│                            │                                 │
│                    ┌───────▼────────┐                       │
│                    │  Load Balancer │                       │
│                    │   (Nginx)      │                       │
│                    └───────┬────────┘                       │
│                            │                                 │
│         ┌──────────────────┼──────────────────┐            │
│         │                  │                  │            │
│  ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐      │
│  │   API       │   │    API      │   │    API      │      │
│  │  Server 1   │   │   Server 2  │   │   Server 3  │      │
│  │  (Node.js)  │   │  (Node.js)  │   │  (Node.js)  │      │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘      │
│         │                  │                  │            │
│         └──────────────────┼──────────────────┘            │
│                            │                                 │
│                    ┌───────▼────────┐                       │
│                    │  MongoDB       │                       │
│                    │  Atlas         │                       │
│                    │  (Database)    │                       │
│                    └────────────────┘                       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              AI/AR Services (Python/Flutter)          │  │
│  │  - Image Processing  - Face Detection  - AR Render   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

```
User Action (Mobile App)
    ↓
API Request (HTTP/HTTPS)
    ↓
Express Server (Backend)
    ↓
Middleware (Auth, Validation)
    ↓
Route Handler
    ↓
MongoDB Query (Mongoose)
    ↓
Response (JSON)
    ↓
Mobile App UI Update
```

---

## 2. Complete Setup Guide

### 2.1 Environment Preparation

#### Required Software
- **Node.js** v14+ ([Download](https://nodejs.org/))
- **Flutter SDK** v3.0.0+ ([Download](https://flutter.dev/docs/get-started/install))
- **MongoDB Atlas** Account ([Sign Up](https://www.mongodb.com/atlas/database))
- **Python** 3.8+ (for AI/AR services)
- **Git** ([Download](https://git-scm.com/downloads))
- **Android Studio** or **Xcode** (for mobile development)

#### Verify Installations
```bash
# Check Node.js
node --version  # Should be v14+
npm --version

# Check Flutter
flutter --version  # Should be 3.0.0+
flutter doctor  # Check for any issues

# Check Python
python --version  # Should be 3.8+
pip --version

# Check Git
git --version
```

### 2.2 Backend Setup (Step-by-Step)

#### Step 1: Clone Repository
```bash
git clone https://github.com/tehreemraghib0107/Zarva-FYP.git
cd Zarva FYP
```

#### Step 2: Backend Configuration
```bash
cd backend

# Install dependencies
npm install

# Create .env file (copy from .env.example if exists)
# On Windows:
copy NUL .env

# On Mac/Linux:
touch .env
```

#### Step 3: Configure Environment Variables
Edit `.env` file with your credentials:

```env
# MongoDB Configuration
MONGO_URI=mongodb+srv://<username>:<password>@cluster0.mongodb.net/zarva?retryWrites=true&w=majority

# Server Configuration
PORT=5000
NODE_ENV=development

# JWT Configuration
JWT_SECRET=your_super_secret_jwt_key_here_make_it_long_and_random_123456789

# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_google_client_id.apps.googleusercontent.com

# File Upload Configuration
MAX_FILE_SIZE=10485760  # 10MB in bytes
ALLOWED_FILE_TYPES=image/jpeg,image/png,image/jpg

# CORS Configuration
CORS_ORIGIN=http://localhost:3000,http://localhost:5000,http://10.0.2.2:5000
```

**Getting MongoDB Atlas Connection String:**
1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Create a cluster (free tier is fine)
3. Click "Connect" → "Connect your application"
4. Copy the connection string
5. Replace `<password>` with your database user password
6. Replace `<dbname>` with `zarva`

**Getting Google Client ID:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable "Google+ API"
4. Go to "Credentials" → "Create Credentials" → "OAuth client ID"
5. Select "Web application"
6. Add authorized origins: `http://localhost:5000`
7. Copy the Client ID

#### Step 4: Start Backend Server
```bash
# Development mode (with auto-reload)
npm run dev  # If you have nodemon installed

# Production mode
npm start
```

Expected output:
```
✅ ZARVA Database Connected!
Server running on port 5000
```

#### Step 5: Seed Database (Optional)
```bash
# Using browser or Postman
GET http://localhost:5000/api/products/seed

# Or using curl
curl http://localhost:5000/api/products/seed
```

This adds 30 sample jewelry products across 6 categories.

### 2.3 Mobile App Setup

#### Step 1: Navigate to Mobile App Directory
```bash
cd mobile_app
```

#### Step 2: Install Dependencies
```bash
flutter pub get
```

#### Step 3: Configure API Endpoint

Create or edit `lib/config/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:5000'; // Android emulator
  // static const String baseUrl = 'http://localhost:5000'; // iOS simulator
  // static const String baseUrl = 'http://YOUR_PC_IP:5000'; // Physical device
  
  static const String authEndpoint = '/api/auth';
  static const String productsEndpoint = '/api/products';
  static const String favoritesEndpoint = '/api/favorites';
  static const String ordersEndpoint = '/api/orders';
  // ... other endpoints
}
```

**Finding Your PC IP Address:**
- **Windows**: `ipconfig` → Look for "IPv4 Address"
- **Mac/Linux**: `ifconfig` → Look for "inet" under en0 or wlan0

#### Step 4: Platform-Specific Setup

**For Android:**
1. Open `android/app/build.gradle`
2. Update `minSdkVersion` to 21 (if not already)
3. Add internet permission in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

**For iOS:**
1. Open `ios/Runner/Info.plist`
2. Add permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access for AR try-on feature</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access for profile pictures</string>
```

#### Step 5: Run the App
```bash
# Check connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in debug mode
flutter run

# Run in release mode
flutter run --release
```

### 2.4 AI Services Setup (Optional)

#### Step 1: Navigate to AI Services
```bash
cd ai_services
```

#### Step 2: Create Virtual Environment
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Mac/Linux
python3 -m venv venv
source venv/bin/activate
```

#### Step 3: Install Dependencies
```bash
pip install -r requirements.txt
```

**Key Dependencies:**
- `ultralytics` - YOLOv8 for object detection
- `rembg` - Background removal
- `opencv-python` - Image processing
- `flask` - API server
- `numpy` - Numerical operations

#### Step 4: Run Asset Processor
```bash
python ar_processor.py
```

This processes jewelry images for AR try-on:
1. Removes backgrounds
2. Strips skin/lip colors
3. Filters outliers
4. Generates metadata

### 2.5 AR Services Setup (Optional)

```bash
cd ar_services
flutter pub get
flutter run
```

---

## 3. Backend Deep Dive

### 3.1 Server Architecture

The backend follows a layered architecture:

```
server.js (Entry Point)
    ↓
Middleware Layer
    - CORS
    - JSON parsing
    - URL encoding
    - Static file serving
    ↓
Route Layer
    - auth.js
    - products.js
    - orders.js
    - ... (14 route modules)
    ↓
Model Layer
    - User.js
    - Product.js
    - Order.js
    - ... (8 models)
    ↓
Database Layer
    - MongoDB Atlas
    - Mongoose ODM
```

### 3.2 Authentication Flow

#### Registration Flow
```
1. Client sends POST /api/auth/signup
   { name, email, password, role }

2. Server validates input
   ↓
3. Checks if user exists
   ↓
4. Hashes password with bcrypt (10 salt rounds)
   ↓
5. Creates new User document
   ↓
6. Generates JWT token (1-day expiry)
   ↓
7. Returns token and user data
```

#### Google Login Flow
```
1. Client sends POST /api/auth/google
   { token, type: 'accessToken' | 'idToken' }

2. If accessToken:
   - Calls Google API to get user info
   ↓
3. If idToken:
   - Verifies token with Google Auth Library
   ↓
4. Extracts name, email, googleId
   ↓
5. Finds or creates user
   ↓
6. Generates JWT token
   ↓
7. Returns token and user data
```

### 3.3 Smart Search Implementation

The product search uses a three-tier matching system:

```javascript
// From backend/routes/products.js

// Tier 1: Synonym Mapping
const synonyms = {
    'jhumka': 'Earrings',
    'earring': 'Earrings',
    'pendant': 'Necklaces',
    'chain': 'Necklaces',
    'bangle': 'Bracelets'
};

// Tier 2: Prefix Matching
const categories = ['Rings', 'Bracelets', 'Chokers', 'Lockets', 'Necklaces', 'Earrings'];
matchedCategory = categories.find(c => c.toLowerCase().startsWith(term));

// Tier 3: Name Regex Search
query.name = { $regex: q, $options: 'i' };
```

**Examples:**
- Search "jhumka" → Maps to "Earrings" category
- Search "ring" → Matches "Rings" category (prefix)
- Search "sapphire" → Searches product names

### 3.4 Inventory Management

```javascript
// Products are joined with Inventory collection
const products = await Product.find(query).lean();
const inventories = await Inventory.find({ 
    productId: { $in: products.map(p => p._id) } 
});

// Merge inventory data with products
const productsWithStock = products.map(p => {
    const inv = invMap[p._id.toString()];
    return {
        ...p,
        inventory: {
            quantity: inv.quantity,
            sold: inv.sold,
            remaining: inv.quantity - inv.sold
        }
    };
});
```

### 3.5 Notification System

When a new product is added:
```javascript
// Broadcast to all users
await Notification.create({
    type: 'product',
    title: 'New Product Added',
    message: `${product.name} is now available in ${product.category}.`,
    metadata: {
        productId: String(product._id),
        category: product.category,
        image: product.image
    }
});
```

---

## 4. Mobile App Deep Dive

### 4.1 App Architecture

```
lib/
├── main.dart                    # App entry & routing
├── constants.dart               # App-wide constants
├── config/
│   └── route_observer.dart      # Navigation tracking
├── features/                    # Feature modules
│   ├── splash_screen.dart       # Initialization
│   ├── login_screen.dart        # Authentication
│   ├── signup_screen.dart       # Registration
│   ├── home_screen.dart         # Main dashboard
│   ├── category_screen.dart     # Category browsing
│   ├── product_details_screen.dart
│   ├── favorites_screen.dart    # Wishlist
│   ├── cart.dart                # Shopping cart
│   ├── notification.dart        # Notifications
│   ├── account.dart             # User account
│   ├── edit_profile.dart        # Profile editing
│   ├── ChatbotScreen.dart       # AI chatbot
│   ├── history_screen.dart      # Order history
│   ├── checkout_details_screen.dart
│   ├── payment_method_screen.dart
│   ├── online_payment_screen.dart
│   ├── settings_screen.dart
│   ├── help_center_screen.dart
│   ├── about_us_screen.dart
│   └── ar/                      # AR Virtual Try-On
│       ├── ar_camera_screen.dart
│       ├── ar_product_overlay.dart
│       ├── models/
│       │   └── ar_landmarks.dart
│       ├── services/
│       │   └── landmark_tracker.dart
│       ├── trackers/
│       │   ├── necklace_tracker.dart
│       │   └── earring_tracker.dart
│       └── jewelry_renderer.dart
└── services/
    ├── auth_service.dart        # Authentication logic
    └── theme_service.dart       # Theme management
```

### 4.2 State Management

The app uses **Provider** for state management:

```dart
// main.dart
ChangeNotifierProvider(
  create: (context) => ThemeService(),
  child: Consumer<ThemeService>(
    builder: (context, themeService, child) {
      return MaterialApp(
        theme: themeService.getLightTheme(),
        darkTheme: themeService.getDarkTheme(),
        themeMode: themeService.isDarkMode 
            ? ThemeMode.dark 
            : ThemeMode.light,
      );
    },
  ),
)
```

### 4.3 Authentication Service

```dart
// services/auth_service.dart
class AuthService {
  // Store token securely
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
  
  // Login with email/password
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      body: {'email': email, 'password': password},
    );
    return json.decode(response.body);
  }
  
  // Google Sign-In
  Future<Map<String, dynamic>> googleSignIn() async {
    // Trigger Google Sign-In flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication googleAuth = 
        await googleUser!.authentication;
    
    // Send token to backend
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/google'),
      body: {
        'token': googleAuth.idToken,
        'type': 'idToken'
      },
    );
    return json.decode(response.body);
  }
}
```

### 4.4 Navigation System

```dart
// Using named routes with arguments
Navigator.pushNamed(
  context,
  '/product_details',
  arguments: {
    'id': product.id,
    'name': product.name,
    'price': product.price,
    'image': product.image,
    'description': product.description,
  },
);

// Receiving arguments
class ProductDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)!.settings.arguments 
        as Map<String, dynamic>;
    return Scaffold(
      appBar: AppBar(title: Text(product['name'])),
      body: ProductDetails(product: product),
    );
  }
}
```

### 4.5 Protected Routes

```dart
// widgets/auth_gate.dart
class LoginRequiredGate extends StatelessWidget {
  final Widget child;
  
  const LoginRequiredGate({required this.child});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }
        if (snapshot.data == true) {
          return child;
        }
        return LoginScreen();
      },
    );
  }
}

// Usage in routes
'/home': (context) => const LoginRequiredGate(child: HomeScreen()),
```

---

## 5. AR/AI Services

### 5.1 AR Virtual Try-On Architecture

```
Camera Stream
    ↓
Google ML Kit Face Detection
    ↓
Landmark Extraction (468 points)
    ↓
One Euro Filter (Smoothing)
    ↓
Category Detection (Earrings/Necklaces)
    ↓
Specialized Tracker
    ├─ NecklaceTracker (neck position, pitch/yaw)
    └─ EarringTracker (ear position, occlusion)
    ↓
Jewelry Renderer
    ├─ Shadow rendering
    ├─ Color filtering
    └─ Scale adjustment
    ↓
Canvas Output with Overlay
```

### 5.2 One Euro Filter Implementation

The One Euro Filter eliminates jitter from face tracking:

```dart
// services/landmark_tracker.dart
class OneEuroFilter {
  double minCutoff = 1.0;      // Minimum cutoff frequency
  double beta = 0.007;         // Speed coefficient
  double dCutoff = 1.0;        // Cutoff for derivative
  
  double _x;                   // Previous value
  double _dx;                  // Previous derivative
  DateTime _lastTime;
  
  double filter(double x, DateTime timestamp) {
    final dt = timestamp.difference(_lastTime).inMilliseconds / 1000.0;
    
    // Calculate derivative
    final dx = (x - _x) / dt;
    
    // Calculate alpha (smoothing factor)
    final alpha = alpha(dx, dCutoff, dt);
    
    // Smooth derivative
    final edx = _dx + alpha * (dx - _dx);
    
    // Calculate cutoff frequency based on speed
    final cutoff = minCutoff + beta * edx.abs();
    
    // Smooth value
    final alpha2 = alpha(edx, cutoff, dt);
    final ex = _x + alpha2 * (x - _x);
    
    // Update state
    _x = ex;
    _dx = edx;
    _lastTime = timestamp;
    
    return ex;
  }
}
```

**Parameters:**
- `minCutoff`: Lower = smoother but more lag
- `beta`: Higher = more responsive to fast movements
- `dCutoff`: Derivative smoothing

### 5.3 Necklace Tracker

```dart
// trackers/necklace_tracker.dart
class NecklaceTracker {
  // Calculate neck center from face landmarks
  Point<double> calculateNeckCenter(List<FaceLandmark> landmarks) {
    // Use chin and face bottom points
    final chin = landmarks[152];
    final leftJaw = landmarks[234];
    final rightJaw = landmarks[454];
    
    final centerX = (leftJaw.x + rightJaw.x) / 2;
    final centerY = chin.y + (chin.y - landmarks[10].y) * 0.3;
    
    return Point(centerX, centerY);
  }
  
  // Compensate for head pitch (tilting)
  double calculatePitchCompensation(List<FaceLandmark> landmarks) {
    final nose = landmarks[1];
    final chin = landmarks[152];
    final forehead = landmarks[10];
    
    // Calculate vertical angle
    final verticalDist = (forehead.y - chin.y).abs();
    final horizontalDist = (forehead.x - chin.x).abs();
    
    return (verticalDist / horizontalDist) * 0.5;
  }
  
  // Compensate for head yaw (turning)
  double calculateYawCompensation(List<FaceLandmark> landmarks) {
    final nose = landmarks[1];
    final leftCheek = landmarks[234];
    final rightCheek = landmarks[454];
    
    final leftDist = (nose.x - leftCheek.x).abs();
    final rightDist = (nose.x - rightCheek.x).abs();
    
    // Perspective compression
    return cos((leftDist - rightDist) * 0.01);
  }
}
```

### 5.4 Earring Tracker with Occlusion

```dart
// trackers/earring_tracker.dart
class EarringTracker {
  // Calculate earring position
  Point<double> calculateEarringPosition(
    List<FaceLandmark> landmarks,
    bool isLeftEar
  ) {
    final earCanal = isLeftEar ? landmarks[377] : landmarks[152];
    final earLobe = isLeftEar ? landmarks[381] : landmarks[148];
    
    // Extrapolate from ear canal along head axis
    final dx = earLobe.x - earCanal.x;
    final dy = earLobe.y - earCanal.y;
    
    return Point(
      earLobe.x + dx * 0.3,
      earLobe.y + dy * 0.3
    );
  }
  
  // Check if earring should be visible (occlusion)
  bool shouldShowEarring(List<FaceLandmark> landmarks, bool isLeftEar) {
    final nose = landmarks[1];
    final ear = isLeftEar ? landmarks[377] : landmarks[152];
    
    // Calculate yaw angle
    final yaw = (nose.x - ear.x).abs();
    
    // Hide if head turned too far (> 22 degrees)
    return yaw < 22;
  }
  
  // Apply gravity dangle effect
  double calculateGravityDangle(double rollAngle) {
    // Counteract roll by 85%
    return rollAngle * 0.85;
  }
}
```

### 5.5 Jewelry Renderer

```dart
// jewelry_renderer.dart
class JewelryRenderer {
  // Render jewelry with shadow
  void renderJewelry(
    Canvas canvas,
    Image jewelryImage,
    Point<double> position,
    double scale,
  ) {
    // Save canvas state
    canvas.save();
    
    // Translate to position
    canvas.translate(position.x, position.y);
    canvas.scale(scale, scale);
    
    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawImage(
      jewelryImage,
      Offset(5, 5), // Shadow offset
      shadowPaint,
    );
    
    // Draw jewelry
    final jewelryPaint = Paint()
      ..colorFilter = ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      );
    
    canvas.drawImage(jewelryImage, Offset.zero, jewelryPaint);
    
    // Restore canvas
    canvas.restore();
  }
}
```

### 5.6 AR Product Overlay

```dart
// widgets/ar_product_overlay.dart
class ARProductOverlay extends StatelessWidget {
  final Map<String, dynamic> product;
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout
        if (constraints.maxWidth > 650) {
          // Tablet: Floating card on right
          return Positioned(
            right: 16,
            top: 100,
            child: _buildProductCard(),
          );
        } else {
          // Phone: Bottom sheet
          return Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: _buildProductCard(),
          );
        }
      },
    );
  }
  
  Widget _buildProductCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  product['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  product['price'],
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Rating stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < 4 ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Add to cart or view details
                  },
                  child: Text('Add to Cart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### 5.7 AI Asset Processing Pipeline

```python
# ai_services/ar_processor.py

# Step 1: Background Removal
def remove_background(image_path):
    # Use rembg (U2-Net)
    output = remove(
        Image.open(image_path),
        alpha_matting=True,
        alpha_matting_foreground_threshold=240,
        alpha_matting_background_threshold=10
    )
    return output

# Step 2: Skin and Lip Stripping
def strip_skin_and_lips(image):
    # Convert to HSV and YCbCr
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    ycbcr = cv2.cvtColor(image, cv2.COLOR_BGR2YCrCb)
    
    # Define skin color ranges
    lower_skin_hsv = np.array([0, 20, 70])
    upper_skin_hsv = np.array([20, 170, 255])
    
    lower_skin_ycbcr = np.array([80, 135, 85])
    upper_skin_ycbcr = np.array([255, 180, 135])
    
    # Create masks
    mask_hsv = cv2.inRange(hsv, lower_skin_hsv, upper_skin_hsv)
    mask_ycbcr = cv2.inRange(ycbcr, lower_skin_ycbcr, upper_skin_ycbcr)
    
    # Combine masks
    skin_mask = cv2.bitwise_or(mask_hsv, mask_ycbcr)
    
    # Exclude specular/metallic values
    specular_mask = detect_specular(image)
    skin_mask = cv2.bitwise_and(skin_mask, cv2.bitwise_not(specular_mask))
    
    # Set alpha to 0 for skin pixels
    image[:, :, 3] = np.where(skin_mask > 0, 0, image[:, :, 3])
    
    return image

# Step 3: Outlier Filtering
def filter_outliers(image, jewelry_type):
    if jewelry_type == 'necklace':
        # Keep largest connected component
        return keep_largest_component(image)
    elif jewelry_type == 'earrings':
        # Isolate side-by-side components
        return isolate_earrings(image)
    return image

# Step 4: Metadata Generation
def generate_metadata(image_path, jewelry_type):
    image = Image.open(image_path)
    width, height = image.size
    
    metadata = {
        'width': width,
        'height': height,
        'jewelryType': jewelry_type,
        'anchorType': determine_anchor_type(jewelry_type),
        'aspectRatio': width / height,
        'recommendedScale': calculate_scale(image)
    }
    
    return metadata
```

---

## 6. Testing & Verification

### 6.1 Backend Testing

#### Test Database Connection
```bash
node test-db.js
```

Expected output:
```
✅ MongoDB Connected Successfully!
📊 Database: zarva
📦 Collections: users, products, favorites, ...
```

#### Test API Endpoints with curl

**Test User Signup:**
```bash
curl -X POST http://localhost:5000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "password": "password123"
  }'
```

**Test User Login:**
```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

**Test Get Products:**
```bash
curl http://localhost:5000/api/products
```

**Test Smart Search:**
```bash
# Search by synonym
curl "http://localhost:5000/api/products?q=jhumka"

# Search by prefix
curl "http://localhost:5000/api/products?q=ring"

# Filter by category
curl "http://localhost:5000/api/products?category=Earrings"
```

**Test Seed Products:**
```bash
curl http://localhost:5000/api/products/seed
```

#### Test with Postman/Thunder Client

Import this collection:
```json
{
  "info": {
    "name": "Zarva API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "Signup",
          "request": {
            "method": "POST",
            "url": "http://localhost:5000/api/auth/signup",
            "body": {
              "mode": "raw",
              "raw": "{\"name\":\"Test\",\"email\":\"test@test.com\",\"password\":\"123456\"}"
            }
          }
        },
        {
          "name": "Login",
          "request": {
            "method": "POST",
            "url": "http://localhost:5000/api/auth/login",
            "body": {
              "mode": "raw",
              "raw": "{\"email\":\"test@test.com\",\"password\":\"123456\"}"
            }
          }
        }
      ]
    },
    {
      "name": "Products",
      "item": [
        {
          "name": "Get All Products",
          "request": {
            "method": "GET",
            "url": "http://localhost:5000/api/products"
          }
        },
        {
          "name": "Search Products",
          "request": {
            "method": "GET",
            "url": "http://localhost:5000/api/products?q=jhumka"
          }
        }
      ]
    }
  ]
}
```

### 6.2 Mobile App Testing

#### Flutter Static Analysis
```bash
cd mobile_app
flutter analyze
```

Expected: No errors or warnings

#### Run Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/auth_test.dart

# Run with coverage
flutter test --coverage
```

#### Device Testing

**Test on Multiple Devices:**
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run with device preview
flutter run -d chrome --web-renderer html
```

**Test Scenarios:**
1. ✅ User can sign up with email/password
2. ✅ User can login with Google
3. ✅ User can browse products by category
4. ✅ User can search for products
5. ✅ User can add items to favorites
6. ✅ User can add items to cart
7. ✅ User can view order history
8. ✅ User can edit profile
9. ✅ User can receive notifications
10. ✅ User can chat with bot

### 6.3 AI/AR Services Testing

#### Test Python Scripts
```bash
cd ai_services

# Compile check
python -m py_compile ar_processor.py
python -m py_compile train_pipeline.py

# Run asset processor
python ar_processor.py

# Check output
ls backend/uploads/processed/
```

#### Test AR Features
```bash
cd ar_services
flutter test
flutter analyze
```

---

## 7. Deployment Guide

### 7.1 Backend Deployment (Render/Railway/Heroku)

#### Prepare for Deployment

1. **Update package.json:**
```json
{
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
```

2. **Create .gitignore:**
```
node_modules/
.env
uploads/
*.log
.DS_Store
```

3. **Create Procfile (for Heroku):**
```
web: node server.js
```

#### Deploy to Render

1. Push code to GitHub
2. Go to [Render](https://render.com/)
3. Create new Web Service
4. Connect GitHub repository
5. Configure:
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Environment Variables**: Add all from `.env`
6. Deploy

#### Deploy to Railway

1. Go to [Railway](https://railway.app/)
2. New Project → Deploy from GitHub
3. Select repository
4. Add environment variables
5. Deploy

### 7.2 Mobile App Deployment

#### Android Deployment

1. **Generate Keystore:**
```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

2. **Configure signing in `android/app/build.gradle`:**
```gradle
android {
    signingConfigs {
        release {
            storeFile file('upload-keystore.jks')
            storePassword 'your-store-password'
            keyAlias 'upload'
            keyPassword 'your-key-password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt')
        }
    }
}
```

3. **Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

4. **Build App Bundle (for Google Play):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

5. **Upload to Google Play Console**

#### iOS Deployment

1. **Open iOS project in Xcode:**
```bash
open ios/Runner.xcworkspace
```

2. **Configure signing:**
   - Select Runner target
   - Signing & Capabilities
   - Select your team

3. **Build for release:**
```bash
flutter build ios --release
```

4. **Archive in Xcode:**
   - Product → Archive
   - Upload to App Store Connect

### 7.3 Database Deployment

MongoDB Atlas is already cloud-hosted, but ensure:

1. **Cluster Configuration:**
   - M10+ cluster for production
   - Enable backups
   - Set up alerts

2. **Network Access:**
   - Whitelist deployment IPs
   - Or use 0.0.0.0/0 (not recommended for production)

3. **Database Users:**
   - Create dedicated production user
   - Use strong password
   - Grant minimal required permissions

---

## 8. Common Issues & Solutions

### 8.1 Backend Issues

#### Issue: MongoDB Connection Timeout
**Symptoms:**
```
❌ Connection Error: Server selection timed out after 30000 ms
```

**Solutions:**
1. Check MongoDB Atlas cluster is running
2. Verify IP whitelist includes your IP
3. Check connection string format
4. Increase timeout in `server.js`:
```javascript
mongoose.connect(process.env.MONGO_URI, {
  serverSelectionTimeoutMS: 60000, // 60 seconds
})
```

#### Issue: JWT Token Not Working
**Symptoms:**
```
Token is not valid
```

**Solutions:**
1. Ensure `JWT_SECRET` is set in `.env`
2. Check token hasn't expired (1-day expiry)
3. Verify token is sent in Authorization header:
```javascript
headers: {
  'Authorization': `Bearer ${token}`
}
```

#### Issue: CORS Errors
**Symptoms:**
```
Access to fetch at 'http://localhost:5000' has been blocked by CORS policy
```

**Solutions:**
1. Ensure CORS middleware is added:
```javascript
app.use(cors({
  origin: process.env.CORS_ORIGIN.split(','),
  credentials: true
}));
```

2. Add client URL to whitelist

### 8.2 Mobile App Issues

#### Issue: HTTP Connection Failed
**Symptoms:**
```
SocketException: OS Error: Connection refused, errno = 111
```

**Solutions:**
1. Ensure backend is running
2. Check API URL is correct:
   - Android emulator: `http://10.0.2.2:5000`
   - iOS simulator: `http://localhost:5000`
   - Physical device: `http://YOUR_PC_IP:5000`
3. For physical device, run:
```bash
adb reverse tcp:5000 tcp:5000
```

#### Issue: Google Sign-In Not Working
**Symptoms:**
```
Google Sign-In failed
```

**Solutions:**
1. Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is added
2. Check SHA-1 fingerprint is added in Firebase Console
3. Ensure Google Client ID matches in backend `.env`
4. Enable Google Sign-In in Firebase Console

#### Issue: Assets Not Loading
**Symptoms:**
```
Unable to load asset: assets/1R.png
```

**Solutions:**
1. Run `flutter pub get`
2. Verify asset paths in `pubspec.yaml`
3. Check assets folder exists
4. Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

#### Issue: Camera Permission Denied
**Symptoms:**
```
Camera permission not granted
```

**Solutions:**
1. Add permissions to `AndroidManifest.xml` (Android) or `Info.plist` (iOS)
2. Request permission at runtime:
```dart
final status = await Permission.camera.request();
if (status != PermissionStatus.granted) {
  // Handle denial
}
```

### 8.3 AR/AI Issues

#### Issue: Background Removal Fails
**Symptoms:**
```
ModuleNotFoundError: No module named 'rembg'
```

**Solutions:**
1. Activate virtual environment:
```bash
source venv/bin/activate  # Mac/Linux
venv\Scripts\activate     # Windows
```

2. Reinstall requirements:
```bash
pip install -r requirements.txt
```

#### Issue: ML Kit Not Detecting Face
**Symptoms:**
```
No faces detected
```

**Solutions:**
1. Ensure good lighting
2. Face camera directly
3. Check Google Play Services (Android)
4. Update ML Kit dependencies

### 8.4 Performance Issues

#### Issue: App is Slow
**Solutions:**
1. Use `const` widgets where possible
2. Implement pagination for product lists
3. Optimize images (compress, resize)
4. Use caching:
```dart
CachedNetworkImage(
  imageUrl: product.image,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

#### Issue: Memory Leaks
**Solutions:**
1. Dispose controllers in `dispose()` method
2. Use `StatefulWidget` properly
3. Avoid memory-heavy operations in `build()`

---

## 9. Development Workflow

### 9.1 Git Workflow

```bash
# Create feature branch
git checkout -b feature/user-authentication

# Make changes and commit
git add .
git commit -m "feat: implement Google Sign-In"

# Push to remote
git push origin feature/user-authentication

# Create Pull Request on GitHub
# After review, merge to main
```

### 9.2 Code Style Guidelines

#### Backend (JavaScript)
```javascript
// Use async/await
async function getProducts(req, res) {
  try {
    const products = await Product.find();
    res.json(products);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

// Use meaningful variable names
const user = await User.findById(req.user.id); // ✅ Good
const u = await User.findById(req.user.id);    // ❌ Bad
```

#### Mobile App (Dart)
```dart
// Use const constructors
const Text('Hello World');  // ✅ Good
Text('Hello World');        // ❌ Bad

// Use meaningful names
class ProductDetailsScreen extends StatelessWidget { // ✅ Good
class PDScreen extends StatelessWidget {             // ❌ Bad
}

// Format code
flutter format .
```

### 9.3 Debugging Tips

#### Backend Debugging
```javascript
// Use console.log
console.log('User data:', user);
console.error('Error:', error);

// Use debugger
debugger; // Pauses execution in Node.js inspector
```

#### Mobile App Debugging
```dart
// Use print statements
print('Product data: $product');

// Use debugger
debugger(); // Pauses in Dart DevTools

// Use Flutter DevTools
// Run: flutter pub global activate devtools
// Then: flutter pub global run devtools
```

---

## 10. Project Milestones

### Completed Features ✅
- [x] User authentication (email/password + Google)
- [x] Product catalog (30+ items, 6 categories)
- [x] Smart search with synonym mapping
- [x] Favorites and wishlist
- [x] Shopping cart
- [x] Order management
- [x] Payment integration
- [x] Notification system
- [x] Review system
- [x] Chatbot support
- [x] AR virtual try-on (earrings, necklaces)
- [x] Face tracking with ML Kit
- [x] One Euro Filter for smooth tracking
- [x] Responsive UI design
- [x] Dark/Light theme support

### In Progress 🚧
- [ ] AI product recommendations
- [ ] Admin dashboard completion
- [ ] Advanced AR for all jewelry types
- [ ] Push notifications
- [ ] Multi-language support

### Planned 📋
- [ ] Payment gateway (Stripe, JazzCash)
- [ ] Order tracking
- [ ] Product reviews display
- [ ] Social media sharing
- [ ] Email notifications
- [ ] SMS alerts
- [ ] Analytics dashboard
- [ ] Product comparison
- [ ] Size guide

---

## 11. Contributing

### How to Contribute

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a Pull Request

### Code Review Checklist

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Documentation is updated
- [ ] No console.log or print statements left
- [ ] Error handling is implemented
- [ ] UI is responsive
- [ ] Performance is optimized

---

## 12. Resources & Documentation

### Official Documentation
- [Flutter Docs](https://flutter.dev/docs)
- [Node.js Docs](https://nodejs.org/docs)
- [MongoDB Docs](https://docs.mongodb.com/)
- [Express.js Guide](https://expressjs.com/en/guide/)
- [Google ML Kit](https://developers.google.com/ml-kit)

### Learning Resources
- [Flutter Tutorial](https://flutter.dev/docs/get-started/codelab)
- [MERN Stack Guide](https://www.mongodb.com/mern-stack)
- [AR Development](https://developers.google.com/ar)

### Community
- [GitHub Issues](https://github.com/tehreemraghib0107/Zarva-FYP/issues)
- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

---

## 13. License & Credits

### License
ISC License - See LICENSE file for details

### Credits
- **Development Team**: Zarva FYP Development Team
- **Academic Supervisor**: [Supervisor Name]
- **Institution**: [University Name]
- **Year**: 2024-2025

### Acknowledgments
- Flutter team for amazing framework
- MongoDB for database solutions
- Google for ML Kit and OAuth services
- Open source community for libraries and tools

---

## 14. Contact & Support

### Project Repository
**GitHub**: https://github.com/tehreemraghib0107/Zarva-FYP.git

### Demo Video
`Zarva demo.mp4` - Watch the complete project demonstration

### Getting Help
1. Check this documentation
2. Search existing GitHub issues
3. Create a new issue with:
   - Clear description
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots/logs

---

**Last Updated**: June 2026  
**Version**: 1.0.0  
**Status**: Active Development

---

## Quick Reference Card

### Start Development
```bash
# Terminal 1: Backend
cd backend
npm install
npm start

# Terminal 2: Mobile App
cd mobile_app
flutter pub get
flutter run
```

### Common Commands
```bash
# Backend
npm start              # Start server
npm run dev           # Start with auto-reload

# Mobile App
flutter pub get       # Install dependencies
flutter run           # Run app
flutter build apk     # Build Android APK
flutter clean         # Clean build
flutter analyze       # Check code quality

# Git
git status            # Check changes
git add .             # Stage all changes
git commit -m "msg"   # Commit
git push              # Push to remote
```

### Important URLs
- Backend API: `http://localhost:5000`
- API Docs: See [API Endpoints](#api-endpoints) section
- MongoDB Atlas: https://cloud.mongodb.com/
- Google Cloud: https://console.cloud.google.com/

---

**Happy Coding! 💎✨**