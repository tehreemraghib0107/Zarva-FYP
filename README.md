# Zarva FYP - E-Commerce Jewelry Platform

A full-stack e-commerce application for buying and selling jewelry with mobile app, backend API, and AR/AI services. Built as a Final Year Project (FYP).

## 📋 Project Overview

Zarva is a comprehensive jewelry e-commerce platform that combines:
- **Flutter Mobile App** - Cross-platform mobile application for iOS and Android
- **Node.js Backend API** - RESTful API with MongoDB database
- **AI Services** - Machine learning features (in development)
- **AR Services** - Augmented Reality capabilities (in development)
- **Admin Portal** - Administrative management interface (in development)

## 🏗️ Project Structure

```
Zarva FYP/
├── backend/                 # Node.js Express API server
│   ├── models/             # MongoDB schema definitions
│   │   ├── User.js        # User authentication & profile
│   │   ├── Product.js     # Product catalog
│   │   └── Favorite.js    # Favorite items
│   ├── routes/            # API endpoints
│   │   ├── auth.js        # Authentication endpoints
│   │   ├── products.js    # Product endpoints
│   │   └── favorites.js   # Favorites endpoints
│   ├── server.js          # Express server entry point
│   └── package.json       # Node.js dependencies
│
├── mobile_app/            # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart      # App entry point & routing
│   │   ├── constants.dart # App-wide constants
│   │   ├── config/        # Configuration files
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
│   │   │   └── ChatbotScreen.dart
│   │   └── services/      # Business logic services
│   │       └── auth_service.dart
│   ├── assets/            # Image and media assets
│   ├── android/           # Android platform files
│   ├── ios/               # iOS platform files
│   ├── web/               # Web platform files
│   ├── windows/           # Windows platform files
│   ├── linux/             # Linux platform files
│   ├── macos/             # macOS platform files
│   ├── pubspec.yaml       # Flutter dependencies
│   └── README.md          # Flutter app documentation
│
├── ai_services/           # AI/ML services (in development)
│
├── ar_services/           # Augmented Reality services (in development)
│
├── admin/                 # Admin dashboard (in development)
│
└── README.md              # This file
```

## 🎯 Key Features

### Mobile App
- **User Authentication**
  - Email/Password signup and login
  - Google Sign-In integration
  - JWT token-based authentication

- **Product Browsing**
  - Browse jewelry catalog by categories
  - View product details with images
  - Search and filter functionality
  - Category-based browsing (Rings, Necklaces, etc.)

- **Shopping Features**
  - Add items to cart
  - Mark products as favorites
  - View wishlist

- **User Account**
  - User profile management
  - Edit profile information
  - View order history
  - Account settings

- **Communication**
  - Notification system
  - Chatbot for customer support
  - WhatsApp integration

- **AR Features** (planned)
  - Virtual try-on for jewelry

### Backend API
- **Authentication Endpoints**
  - User registration
  - Email/password login
  - Google OAuth login
  - JWT token management

- **Product Management**
  - Product listing and filtering
  - Category browsing
  - Product details retrieval

- **Favorites System**
  - Add/remove favorites
  - View favorite items

- **User Management**
  - User profile operations
  - Profile updates

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
- **Middleware**: CORS v2.8.5
- **Environment**: dotenv v17.2.3

### Mobile App
- **Framework**: Flutter (SDK >= 3.0.0 <4.0.0)
- **Platform Support**: iOS, Android, Web, Windows, Linux, macOS
- **Key Dependencies**:
  - `google_sign_in` v6.1.0 - Google authentication
  - `http` v1.1.0 - HTTP requests
  - `shared_preferences` v2.2.2 - Local storage
  - `url_launcher` v6.3.2 - Deep linking
  - `cupertino_icons` v1.0.8 - iOS design

## 🚀 Getting Started

### Prerequisites
- Node.js v14+ and npm
- Flutter SDK (v3.0.0+)
- MongoDB Atlas account
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
   JWT_SECRET=your_jwt_secret_key
   GOOGLE_CLIENT_ID=your_google_client_id
   ```

4. **Start the server**
   ```bash
   npm start
   ```
   
   Server will run on `http://localhost:5000`

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
   - Update the API base URL in `lib/config` or `lib/constants.dart`
   - For Android emulator: `http://10.0.2.2:5000`
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
   ```

## 📱 Mobile App Navigation

The app uses route-based navigation with the following screens:

| Route | Screen | Purpose |
|-------|--------|---------|
| `/` | Splash Screen | App initialization |
| `/login` | Login Screen | User login |
| `/signup` | Sign Up Screen | New user registration |
| `/home` | Home Screen | Main app dashboard |
| `/category` | Category Screen | Browse by category |
| `/product_details` | Product Details | View product information |
| `/favorites` | Favorites Screen | View bookmarked items |
| `/cart` | Cart Screen | Shopping cart |
| `/notifications` | Notifications | User notifications |
| `/account` | Account Menu | User account options |
| `/edit_profile` | Edit Profile | Update user profile |
| `/chatbot` | Chatbot | Customer support chat |

## 🔑 API Endpoints

### Authentication
- `POST /api/auth/signup` - Register new user
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/google-login` - Login with Google
- `GET /api/auth/user` - Get current user info

### Products
- `GET /api/products` - Get all products
- `GET /api/products/:id` - Get product details
- `GET /api/products/category/:category` - Get products by category
- `POST /api/products` - Create product (admin)
- `PUT /api/products/:id` - Update product (admin)
- `DELETE /api/products/:id` - Delete product (admin)

### Favorites
- `GET /api/favorites` - Get user's favorite items
- `POST /api/favorites` - Add to favorites
- `DELETE /api/favorites/:id` - Remove from favorites

## 📦 Database Schema

### User
```javascript
{
  name: String,
  email: String (unique),
  password: String (optional for Google users),
  googleId: String (for Google OAuth),
  role: String (default: 'customer'),
  createdAt: Date
}
```

### Product
```javascript
{
  name: String,
  category: String (e.g., 'Rings', 'Necklaces'),
  price: String,
  image: String (asset path),
  description: String,
  createdAt: Date
}
```

### Favorite
```javascript
{
  userId: ObjectId (reference to User),
  productId: ObjectId (reference to Product),
  createdAt: Date
}
```

## 🔐 Security Features

- **Password Hashing**: bcryptjs for secure password storage
- **JWT Authentication**: Token-based user sessions
- **Google OAuth**: Secure third-party authentication
- **CORS**: Cross-Origin Resource Sharing enabled
- **Environment Variables**: Sensitive data stored in `.env` file

## 🚧 Future Development

- [ ] AI-powered product recommendations
- [ ] Augmented Reality (AR) virtual try-on
- [ ] Admin dashboard for product management
- [ ] Payment gateway integration (Stripe, PayPal)
- [ ] Order management system
- [ ] Advanced search and filters
- [ ] Product reviews and ratings
- [ ] Wishlist sharing
- [ ] Push notifications
- [ ] Multi-language support

## 📝 Development Guidelines

### Backend
- Use Express middleware for request validation
- Implement error handling middleware
- Use environment variables for configuration
- Follow REST API conventions

### Mobile App
- Use Flutter best practices and widget composition
- Implement proper state management
- Handle errors and loading states gracefully
- Use Dart linting (flutter_lints)

## 🐛 Troubleshooting

### Backend Issues
- **MongoDB Connection Error**: Verify `MONGO_URI` in `.env` file and ensure MongoDB Atlas IP whitelist includes your IP
- **Port Already in Use**: Change `PORT` in `.env` or kill the process using port 5000

### Mobile App Issues
- **HTTP Connection Error**: Ensure backend is running and API URL is correct
- **Google Sign-In Error**: Verify Google credentials are configured in Firebase
- **Build Errors**: Run `flutter clean` and `flutter pub get`

## 📄 License

This project is licensed under the ISC License.

## 👥 Contributors

Zarva FYP Development Team

## 📞 Support

For issues, feature requests, or questions, please contact the development team.

---

**Last Updated**: January 2026
