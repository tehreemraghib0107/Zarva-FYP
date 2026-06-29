# Zarva FYP - E-Commerce Jewelry Platform

A full-stack e-commerce application for buying and selling jewelry with mobile app, backend API, and AR/AI services. Built as a Final Year Project (FYP).

## 📋 Project Overview

Zarva is a comprehensive jewelry e-commerce platform that combines:
- **Flutter Mobile App** - Cross-platform mobile application for Android
- **Node.js Backend API** - RESTful API with MongoDB Atlas database
- **AI Services** - Machine learning features for product recommendations and image processing
- **AR Services** - Augmented Reality virtual try-on capabilities
- **Admin Portal** - Administrative management interface

## 🏗️ Project Structure

```
Zarva FYP/
├── backend/                 # Node.js Express API server
│   ├── models/             # MongoDB schema definitions
│   │   ├── User.js        # User authentication & profile
│   │   ├── Product.js     # Product catalog
│   │   ├── Favorite.js    # Favorite items
│   │   ├── Wishlist.js    # Wishlist items
│   │   ├── Order.js       # Order management
│   │   ├── Inventory.js   # Product inventory
│   │   ├── Notification.js # User notifications
│   │   ├── Review.js      # Product reviews
│   │   ├── Promotion.js   # Promotional offers
│   │   └── Chat.js        # Chat messages
│   ├── routes/            # API endpoints (14 route modules)
│   │   ├── auth.js        # Authentication endpoints
│   │   ├── products.js    # Product endpoints with smart search
│   │   ├── favorites.js   # Favorites endpoints
│   │   ├── wishlist.js    # Wishlist endpoints
│   │   ├── orders.js      # Order management
│   │   ├── payments.js    # Payment processing
│   │   ├── notifications.js # Notification system
│   │   ├── reviews.js     # Product reviews
│   │   ├── promotions.js  # Promotional campaigns
│   │   ├── upload.js      # File upload handling
│   │   ├── inventory.js   # Inventory management
│   │   ├── analytics.js   # Analytics & reporting
│   │   ├── ai.js          # AI service endpoints
│   │   └── chat.js        # Chatbot support
│   ├── server.js          # Express server entry point
│   ├── package.json       # Node.js dependencies
│   └── test-db.js         # Database connection testing
│
├── mobile_app/            # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart      # App entry point & routing (25+ screens)
│   │   ├── constants.dart # App-wide constants
│   │   ├── config/        # Configuration files
│   │   │   └── route_observer.dart # Navigation tracking
│   │   ├── features/      # Feature screens
│   │   │   ├── splash_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── product_details_screen.dart
│   │   │   ├── category_screen.dart
│   │   │   ├── favorites_screen.dart
│   │   │   ├── cart.dart
│   │   │   ├── notification.dart
│   │   │   ├── account.dart
│   │   │   ├── edit_profile.dart
│   │   │   ├── ChatbotScreen.dart
│   │   │   ├── history_screen.dart
│   │   │   ├── order_history_products_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── help_center_screen.dart
│   │   │   ├── about_us_screen.dart
│   │   │   ├── checkout_details_screen.dart
│   │   │   ├── payment_method_screen.dart
│   │   │   ├── online_payment_screen.dart
│   │   │   └── ar/                    # AR Virtual Try-On
│   │   │       ├── ar_camera_screen.dart
│   │   │       ├── ar_product_overlay.dart
│   │   │       ├── models/ar_landmarks.dart
│   │   │       ├── services/landmark_tracker.dart
│   │   │       ├── trackers/necklace_tracker.dart
│   │   │       ├── trackers/earring_tracker.dart
│   │   │       └── jewelry_renderer.dart
│   │   └── services/      # Business logic services
│   │       ├── auth_service.dart
│   │       └── theme_service.dart
│   ├── assets/            # 90+ image assets
│   ├── android/           # Android platform files
│   ├── ios/               # iOS platform files
│   ├── web/               # Web platform files
│   ├── windows/           # Windows platform files
│   ├── linux/             # Linux platform files
│   ├── macos/             # macOS platform files
│   ├── pubspec.yaml       # Flutter dependencies
│   └── README.md          # Flutter app documentation
│
├── ai_services/           # AI/ML services
│   ├── train_pipeline.py  # ML model training pipeline
│   ├── ar_processor.py    # AR asset processing
│   ├── requirements.txt   # Python dependencies
│   ├── yolov8s-world.pt   # YOLOv8 model weights
│   ├── models/            # Trained ML models
│   ├── weights/           # Model weights storage
│   └── Images/            # Training images
│
├── ar_services/           # Augmented Reality services
│   ├── pubspec.yaml       # Flutter AR dependencies
│   ├── AR/                # AR assets & processed images
│   ├── ar_services/       # AR service modules
│   ├── assets/            # AR-specific assets
│   ├── mobile_app_ar/     # Mobile AR integration
│   ├── 3D_MODEL_GENERATION_GUIDE.md
│   └── README.md
│
├── admin/                 # Admin dashboard (Vue.js)
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   └── src/
│
├── Zarva demo.mp4         # Project demo video
├── README.md              # This file
└── walkthrough.md         # Detailed technical walkthrough
```

## 🎯 Key Features

### Mobile App Features
- **User Authentication**
  - Email/Password signup and login
  - Google Sign-In integration
  - JWT token-based authentication
  - Profile management with image upload

- **Product Browsing & Search**
  - Browse jewelry catalog by 6 categories (Rings, Bracelets, Chokers, Lockets, Necklaces, Earrings)
  - Smart search with synonym mapping (e.g., "jhumka" → Earrings)
  - Category-based browsing with 30+ products
  - Product details with inventory status
  - Search by name or category with prefix matching

- **Shopping Features**
  - Add items to cart
  - Mark products as favorites
  - Wishlist management
  - Real-time inventory tracking
  - Multiple checkout options

- **Order Management**
  - Order history with product details
  - Order status tracking
  - Payment method selection
  - Online payment integration

- **User Account**
  - User profile management
  - Edit profile information
  - View order history
  - Account settings
  - Help center & About us

- **Communication**
  - Notification system
  - Real-time chat support
  - WhatsApp integration
  - AI-powered chatbot

- **AR Features**
  - Virtual try-on for earrings and necklaces
  - Real-time face/body tracking using ML Kit
  - One Euro Filter for smooth tracking
  - Dynamic jewelry positioning with pitch/yaw compensation
  - Product info overlay cards
  - Responsive design for phones and tablets

### Backend API Features
- **Authentication System**
  - User registration with email/password
  - Email/password login
  - Google OAuth login (access token & ID token)
  - JWT token management (1-day expiry)
  - Password hashing with bcryptjs

- **Product Management**
  - Product listing with smart search
  - Category-based filtering
  - Product details with inventory
  - CRUD operations for admins
  - 30+ pre-seeded jewelry products
  - Image asset management

- **Inventory System**
  - Real-time stock tracking
  - Quantity and sold count
  - Remaining stock calculation
  - Inventory updates

- **Favorites & Wishlist**
  - Add/remove favorites
  - View favorite items
  - Wishlist management

- **Order Management**
  - Order creation and tracking
  - Order history
  - Status updates

- **Payment Processing**
  - Multiple payment methods
  - Online payment integration
  - Payment verification

- **Notification System**
  - Push notifications
  - Product addition alerts
  - Order updates

- **Review System**
  - Product reviews and ratings
  - Review management

- **Promotion System**
  - Promotional campaigns
  - Discount management

- **AI Services**
  - Product recommendations
  - Image processing
  - Background removal for AR assets

- **Chat Support**
  - Real-time chat messaging
  - Chatbot integration

## 🛠️ Tech Stack

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js v5.2.1
- **Database**: MongoDB Atlas
- **Authentication**: 
  - JWT (jsonwebtoken v9.0.3)
  - bcryptjs v3.0.3 (password hashing)
  - Google Auth Library v10.5.0
- **HTTP Client**: Axios v1.13.2
- **File Upload**: Multer v2.1.1, Form-Data v4.0.5
- **Middleware**: CORS v2.8.5
- **Environment**: dotenv v17.2.3
- **ODM**: Mongoose v9.1.5

### Mobile App
- **Framework**: Flutter (SDK >= 3.0.0 <4.0.0)
- **Platform Support**: iOS, Android, Web, Windows, Linux, macOS
- **State Management**: Provider v6.1.0
- **Key Dependencies**:
  - `google_sign_in` v6.1.0 - Google authentication
  - `http` v1.1.0 - HTTP requests
  - `shared_preferences` v2.2.2 - Local storage
  - `url_launcher` v6.3.2 - Deep linking & WhatsApp
  - `cupertino_icons` v1.0.8 - iOS design
  - `image_picker` v1.0.7 - Image selection
  - `intl` v0.20.2 - Internationalization
  - `uuid` v4.3.3 - Unique ID generation
  - `another_flushbar` v1.12.30 - Notifications
  - `camera` v0.10.5+9 - Camera access
  - `google_mlkit_face_detection` v0.11.0 - Face detection for AR
  - `google_mlkit_commons` v0.7.1 - ML Kit utilities
  - `permission_handler` v11.3.1 - Permissions
  - `device_preview` v1.2.0 - Device testing

### AI Services
- **Framework**: Python
- **ML Framework**: YOLOv8
- **Image Processing**: rembg (U2-Net)
- **Computer Vision**: OpenCV, ML Kit

### AR Services
- **Framework**: Flutter
- **AR Engine**: Custom AR implementation
- **Face Detection**: Google ML Kit
- **Tracking**: One Euro Filter algorithm

### Admin Portal
- **Framework**: Vue.js
- **Build Tool**: Vite

## 🚀 Getting Started

### Prerequisites
- Node.js v14+ and npm
- Flutter SDK (v3.0.0+)
- MongoDB Atlas account
- Python 3.8+ (for AI/AR services)
- Git

### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Create `.env` file**
   ```
   MONGO_URI=your_mongodb_atlas_connection_string
   PORT=5000
   JWT_SECRET=your_jwt_secret_key_here_make_it_long_and_secure
   GOOGLE_CLIENT_ID=your_google_client_id_from_console.cloud.google.com
   ```

4. **Start the server**
   ```bash
   npm start
   ```
   
   Server will run on `http://localhost:5000`

5. **Seed the database** (optional - adds 30 sample products)
   ```bash
   # In your browser or Postman:
   GET http://localhost:5000/api/products/seed
   ```

### Mobile App Setup

1. **Navigate to mobile app directory**
   ```bash
   cd mobile_app
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoint**
   - Update the API base URL in `lib/config/api_config.dart` or `lib/constants.dart`
   - For Android emulator: `http://10.0.2.2:5000`
   - For iOS simulator: `http://localhost:5000`
   - For physical device: `http://YOUR_PC_IP:5000`

4. **Setup Android Port Forwarding** (for physical device)
   ```bash
   adb reverse tcp:5000 tcp:5000
   ```

5. **Run the app**
   ```bash
   # For Android
   flutter run -d android
   
   # For iOS
   flutter run -d ios
   
   # For Web
   flutter run -d web
   
   # For Windows
   flutter run -d windows
   ```

### AI Services Setup (Optional)

1. **Navigate to ai_services directory**
   ```bash
   cd ai_services
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run asset processor**
   ```bash
   python ar_processor.py
   ```

### AR Services Setup (Optional)

1. **Navigate to ar_services directory**
   ```bash
   cd ar_services
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Run AR services**
   ```bash
   flutter run
   ```

### Admin Portal Setup (Optional)

1. **Navigate to admin directory**
   ```bash
   cd admin
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Start development server**
   ```bash
   npm run dev
   ```

## 📱 Mobile App Navigation

The app uses route-based navigation with the following screens:

| Route | Screen | Purpose | Auth Required |
|-------|--------|---------|---------------|
| `/` | Splash Screen | App initialization | No |
| `/login` | Login Screen | User login | No |
| `/signup` | Sign Up Screen | New user registration | No |
| `/home` | Home Screen | Main dashboard | Yes |
| `/category` | Category Screen | Browse by category | Yes |
| `/product_details` | Product Details | View product info | Yes |
| `/favorites` | Favorites Screen | View bookmarked items | Yes |
| `/cart` | Cart Screen | Shopping cart | Yes |
| `/notifications` | Notifications | User notifications | Yes |
| `/account` | Account Menu | User account options | Yes |
| `/edit_profile` | Edit Profile | Update user profile | Yes |
| `/chatbot` | Chatbot | Customer support chat | Yes |
| `/history` | Order History | View past orders | Yes |
| `/order_history_products` | Order Products | Order product details | Yes |
| `/settings` | Settings | App settings | Yes |
| `/help_center` | Help Center | FAQ & support | Yes |
| `/about_us` | About Us | App information | Yes |
| `/checkout_details` | Checkout | Order checkout | Yes |
| `/payment_method` | Payment Method | Select payment | Yes |
| `/online_payment` | Online Payment | Process payment | Yes |

## 🔑 API Endpoints

### Authentication (`/api/auth`)
- `POST /api/auth/signup` - Register new user
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/google` - Login with Google (access token or ID token)
- `GET /api/auth/me` - Get current user info (protected)
- `PUT /api/auth/profile` - Update user profile (protected)
- `GET /api/auth/users` - Get all users (admin)
- `PUT /api/auth/users/:id/role` - Update user role (admin)
- `DELETE /api/auth/users/:id` - Delete user (admin)

### Products (`/api/products`)
- `GET /api/products` - Get all products (with search & filter)
- `GET /api/products/seed` - Seed database with sample products
- `GET /api/products/:id` - Get product details with inventory
- `POST /api/products` - Create product (admin)
- `PUT /api/products/:id` - Update product (admin)
- `DELETE /api/products/:id` - Delete product (admin)

**Smart Search Features:**
- Synonym mapping: "jhumka" → Earrings, "pendant" → Necklaces
- Prefix matching: "ring" → Rings
- Category filtering: `?category=Rings`
- Name search: `?q=sapphire`

### Favorites (`/api/favorites`)
- `GET /api/favorites` - Get user's favorite items (protected)
- `POST /api/favorites` - Add to favorites (protected)
- `DELETE /api/favorites/:id` - Remove from favorites (protected)

### Wishlist (`/api/wishlist`)
- `GET /api/wishlist` - Get user's wishlist (protected)
- `POST /api/wishlist` - Add to wishlist (protected)
- `DELETE /api/wishlist/:id` - Remove from wishlist (protected)

### Orders (`/api/orders`)
- `GET /api/orders` - Get user's orders (protected)
- `POST /api/orders` - Create new order (protected)
- `GET /api/orders/:id` - Get order details (protected)
- `PUT /api/orders/:id/status` - Update order status (admin)

### Payments (`/api/payments`)
- `POST /api/payments/initiate` - Initiate payment
- `POST /api/payments/verify` - Verify payment
- `GET /api/payments/history` - Payment history (protected)

### Notifications (`/api/notifications`)
- `GET /api/notifications` - Get user notifications (protected)
- `POST /api/notifications` - Create notification (admin)
- `PUT /api/notifications/:id/read` - Mark as read (protected)
- `DELETE /api/notifications/:id` - Delete notification (protected)

### Reviews (`/api/reviews`)
- `GET /api/reviews/product/:productId` - Get product reviews
- `POST /api/reviews` - Add review (protected)
- `PUT /api/reviews/:id` - Update review (protected)
- `DELETE /api/reviews/:id` - Delete review (protected)

### Promotions (`/api/promotions`)
- `GET /api/promotions` - Get active promotions
- `POST /api/promotions` - Create promotion (admin)
- `PUT /api/promotions/:id` - Update promotion (admin)
- `DELETE /api/promotions/:id` - Delete promotion (admin)

### Inventory (`/api/inventory`)
- `GET /api/inventory` - Get all inventory (admin)
- `GET /api/inventory/:productId` - Get product inventory
- `PUT /api/inventory/:productId` - Update inventory (admin)

### Analytics (`/api/analytics`)
- `GET /api/analytics/sales` - Sales analytics (admin)
- `GET /api/analytics/products` - Product analytics (admin)
- `GET /api/analytics/users` - User analytics (admin)

### AI Services (`/api/ai`)
- `POST /api/ai/recommendations` - Get product recommendations
- `POST /api/ai/process-image` - Process product images

### Chat (`/api/chat`)
- `GET /api/chat/messages` - Get chat messages (protected)
- `POST /api/chat/messages` - Send message (protected)
- `POST /api/chat/bot` - Chatbot interaction

### File Upload (`/api/upload`)
- `POST /api/upload/image` - Upload image (protected)
- `POST /api/upload/product-image` - Upload product image (admin)

## 📦 Database Schema

### User
```javascript
{
  _id: ObjectId,
  name: String (required),
  email: String (required, unique),
  password: String (optional for Google users),
  googleId: String (for Google OAuth),
  role: String (default: 'customer', options: 'customer', 'admin'),
  profileImage: String (default: ""),
  createdAt: Date,
  updatedAt: Date
}
```

### Product
```javascript
{
  _id: ObjectId,
  name: String (required),
  category: String (required, e.g., 'Rings', 'Necklaces'),
  price: String (required, e.g., 'PKR 1500'),
  image: String (required, asset path),
  description: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Inventory
```javascript
{
  _id: ObjectId,
  productId: ObjectId (reference to Product),
  quantity: Number (total stock),
  sold: Number (items sold),
  remaining: Number (calculated: quantity - sold),
  updatedAt: Date
}
```

### Favorite
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  productId: ObjectId (reference to Product),
  createdAt: Date
}
```

### Wishlist
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  productId: ObjectId (reference to Product),
  createdAt: Date
}
```

### Order
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  products: [{
    productId: ObjectId,
    name: String,
    price: String,
    image: String,
    quantity: Number
  }],
  totalAmount: String,
  status: String (pending, processing, shipped, delivered, cancelled),
  shippingAddress: {
    address: String,
    city: String,
    postalCode: String,
    country: String
  },
  paymentMethod: String,
  paymentStatus: String (pending, completed, failed),
  createdAt: Date,
  updatedAt: Date
}
```

### Notification
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  type: String (product, order, promotion, system),
  title: String,
  message: String,
  metadata: {
    productId: String,
    category: String,
    image: String
  },
  read: Boolean (default: false),
  createdAt: Date
}
```

### Review
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  productId: ObjectId (reference to Product),
  rating: Number (1-5),
  comment: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Promotion
```javascript
{
  _id: ObjectId,
  title: String,
  description: String,
  discountPercentage: Number,
  validFrom: Date,
  validUntil: Date,
  applicableCategories: [String],
  active: Boolean (default: true),
  createdAt: Date
}
```

### Chat Message
```javascript
{
  _id: ObjectId,
  userId: ObjectId (reference to User),
  message: String,
  sender: String (user, bot),
  timestamp: Date
}
```

## 🔐 Security Features

- **Password Hashing**: bcryptjs with 10 salt rounds for secure password storage
- **JWT Authentication**: Token-based user sessions with 1-day expiry
- **Google OAuth**: Secure third-party authentication with ID token verification
- **CORS**: Cross-Origin Resource Sharing enabled for mobile/web clients
- **Environment Variables**: Sensitive data stored in `.env` file (not committed to git)
- **Protected Routes**: Middleware authentication for sensitive endpoints
- **Input Validation**: Request body validation on all endpoints

## 🎨 UI/UX Features

- **Theme Support**: Light and dark mode with persistent preference
- **Device Preview**: Test on multiple device sizes during development
- **Responsive Design**: Adaptive layouts for phones and tablets
- **Glassmorphic UI**: Modern backdrop blur effects
- **Smooth Animations**: Fluid transitions and loading states
- **Error Handling**: User-friendly error messages and toast notifications
- **Loading States**: Skeleton screens and progress indicators

## 🚧 Future Development

- [ ] AI-powered product recommendations based on browsing history
- [ ] Advanced AR try-on for rings, bracelets, and necklaces
- [ ] Admin dashboard for comprehensive product and order management
- [ ] Payment gateway integration (Stripe, JazzCash, EasyPaisa)
- [ ] Complete order management system with tracking
- [ ] Advanced search with filters (price, material, gemstone)
- [ ] Product reviews and ratings system
- [ ] Wishlist sharing via social media
- [ ] Push notifications for orders and promotions
- [ ] Multi-language support (English, Urdu)
- [ ] SMS notifications
- [ ] Email receipts and invoices
- [ ] Product comparison feature
- [ ] Recently viewed products
- [ ] Size guide for rings and bracelets

## 📝 Development Guidelines

### Backend
- Use Express middleware for request validation
- Implement error handling middleware
- Use environment variables for configuration
- Follow REST API conventions
- Document all endpoints with clear responses
- Test with Postman/Thunder Client

### Mobile App
- Use Flutter best practices and widget composition
- Implement proper state management with Provider
- Handle errors and loading states gracefully
- Use Dart linting (flutter_lints)
- Test on multiple device sizes
- Follow Material Design guidelines

### AI/AR Services
- Document model training process
- Version control model weights
- Test asset processing pipeline
- Optimize for mobile performance

## 🐛 Troubleshooting

### Backend Issues
- **MongoDB Connection Error**: Verify `MONGO_URI` in `.env` file and ensure MongoDB Atlas IP whitelist includes your IP address (0.0.0.0/0 for development)
- **Port Already in Use**: Change `PORT` in `.env` or kill the process using port 5000
- **JWT Token Error**: Ensure `JWT_SECRET` is set and consistent across restarts
- **Google Login Fails**: Verify `GOOGLE_CLIENT_ID` is correct and OAuth consent screen is configured

### Mobile App Issues
- **HTTP Connection Error**: Ensure backend is running and API URL is correct for your platform
- **Google Sign-In Error**: Verify Google credentials are configured in Firebase Console and `google-services.json` / `GoogleService-Info.plist` are added
- **Build Errors**: Run `flutter clean` and `flutter pub get`
- **Camera Permission Denied**: Check app permissions in device settings
- **AR Not Working**: Ensure device has Google Play Services (for ML Kit)
- **Assets Not Loading**: Verify asset paths in `pubspec.yaml` and run `flutter pub get`

### AI/AR Services Issues
- **Python Module Not Found**: Activate virtual environment and install requirements
- **Model Loading Error**: Ensure YOLOv8 weights file is in correct location
- **Background Removal Fails**: Check if `rembg` package is installed correctly

## 📊 Project Statistics

- **Total Lines of Code**: ~15,000+
- **Backend Routes**: 14 route modules
- **Mobile Screens**: 20+ screens
- **Database Models**: 8 MongoDB schemas
- **API Endpoints**: 40+ endpoints
- **Product Catalog**: 30+ jewelry items across 6 categories
- **Flutter Dependencies**: 15+ packages
- **Node.js Dependencies**: 10+ packages

## 📄 License

This project is licensed under the ISC License.

## 👥 Contributors

Zarva FYP Development Team

## 📞 Support

For issues, feature requests, or questions, please contact the development team.

## 🎓 Academic Context

This project was developed as a Final Year Project (FYP) for a Bachelor's degree in Computer Science. It demonstrates:
- Full-stack web development
- Mobile application development
- AI/ML integration
- Augmented Reality implementation
- RESTful API design
- Database design and optimization
- Modern UI/UX principles

---

**Last Updated**: June 2026  
**Version**: 1.0.0  
**Repository**: https://github.com/tehreemraghib0107/Zarva-FYP.git