# Admin Access Guide

## How to Access Admin Panel

### Method 1: Hidden Access from Login Screen
1. Open the app and navigate to the login screen
2. **Long press** on the "Login" button
3. This will open the Admin Login screen

### Method 2: Direct URL (if using web version)
- Navigate to `/admin` route in the app

## Admin Credentials
- **Email**: demo2026@gmail.com
- **Password**: demo123

## Admin Features
- View dashboard with statistics
- Review pending donor applications
- Verify or reject donor applications
- View verified donors
- View verification logs
- Manage donor verification status

## Security Features
- Only verified donors appear in public donor searches
- All donor applications start with "pending" status
- Admin verification required before donors become visible
- Comprehensive audit trail of all admin actions

## Data Storage
All data is stored in Firebase Firestore with the following collections:
- `users` - User profiles
- `donors` - Donor profiles with verification status
- `bloodRequests` - Blood request posts
- `admins` - Admin user records
- `verification_logs` - Admin action audit trail
- `chats` - Chat messages between users

## Firestore Security Rules
- Users can only read/write their own data
- Admins can modify donor verification status
- Only verified donors appear in public queries
- Comprehensive security rules prevent unauthorized access