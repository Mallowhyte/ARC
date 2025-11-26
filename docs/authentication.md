# Authentication Documentation

## Overview

ARC uses Supabase Auth for user authentication, providing secure sign up, login, and session management.

---

## Features Implemented

### ✅ User Registration (Sign Up)
- Email and password authentication
- Full name capture
- Email verification
- Password strength validation
- Terms and conditions acceptance

### ✅ User Login
- Email/password login
- Password visibility toggle
- "Remember me" functionality via Supabase session
- Forgot password link

### ✅ Password Reset
- Email-based password reset
- Reset link sent to user email
- Success confirmation

### ✅ Session Management
- Automatic session persistence
- Auth state monitoring
- Auto-logout on session expiry
- Secure token management

### ✅ User Profile
- Display user information
- Email verification status
- Avatar with initials
- Account details

### ✅ Logout
- Confirmation dialog
- Session cleanup
- Redirect to login screen

---

## Authentication Flow

```
┌─────────────────┐
│  App Start      │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Auth Gate      │──────> Check Auth State
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    v         v
 Logged    Logged
   Out       In
    │         │
    v         v
┌─────────┐ ┌─────────┐
│ Login   │ │  Home   │
│ Screen  │ │ Screen  │
└─────────┘ └─────────┘
```

---

## Files Structure

```
lib/
├── services/
│   └── auth_service.dart          # Authentication service layer
└── screens/
    └── auth/
        ├── auth_gate.dart         # Auth state router
        ├── login_screen.dart      # Login UI
        ├── signup_screen.dart     # Registration UI
        └── forgot_password_screen.dart  # Password reset UI
```

---

## AuthService API

### Properties

```dart
// Get current user
User? currentUser

// Get current user ID
String? currentUserId

// Get current user email
String? currentUserEmail

// Check if signed in
bool isSignedIn

// Get user metadata
Map<String, dynamic>? userMetadata

// Get user full name
String? userFullName

// Check email verification
bool isEmailVerified
```

### Methods

#### Sign Up
```dart
Future<AuthResponse> signUp({
  required String email,
  required String password,
  String? fullName,
})
```

#### Sign In
```dart
Future<AuthResponse> signIn({
  required String email,
  required String password,
})
```

#### Sign Out
```dart
Future<void> signOut()
```

#### Reset Password
```dart
Future<void> resetPassword(String email)
```

#### Update Password
```dart
Future<UserResponse> updatePassword(String newPassword)
```

#### Update Profile
```dart
Future<UserResponse> updateProfile({
  String? fullName,
  String? avatarUrl,
})
```

### Validation Methods

```dart
// Validate email format
static bool isValidEmail(String email)

// Validate password strength
static bool isValidPassword(String password)

// Get password strength message
static String getPasswordStrengthMessage(String password)
```

---

## Usage Examples

### Check Authentication Status

```dart
import 'package:auto_file_classifier/services/auth_service.dart';

final authService = AuthService();

if (authService.isSignedIn) {
  print('User is logged in: ${authService.currentUserEmail}');
} else {
  print('User is not logged in');
}
```

### Sign Up New User

```dart
try {
  final response = await authService.signUp(
    email: 'user@example.com',
    password: 'SecurePass123',
    fullName: 'John Doe',
  );
  
  if (response.user != null) {
    print('Sign up successful! Check email for verification.');
  }
} catch (e) {
  print('Sign up failed: $e');
}
```

### Sign In User

```dart
try {
  final response = await authService.signIn(
    email: 'user@example.com',
    password: 'SecurePass123',
  );
  
  if (response.session != null) {
    // Navigate to home screen
    Navigator.push(...);
  }
} catch (e) {
  print('Login failed: $e');
}
```

### Listen to Auth State Changes

```dart
authService.authStateChanges.listen((AuthState state) {
  if (state.session != null) {
    print('User logged in');
  } else {
    print('User logged out');
  }
});
```

### Sign Out User

```dart
await authService.signOut();
// Navigate to login screen
```

---

## Password Requirements

- **Minimum Length**: 8 characters
- **Uppercase**: At least 1 uppercase letter (A-Z)
- **Lowercase**: At least 1 lowercase letter (a-z)
- **Number**: At least 1 digit (0-9)

Example valid password: `SecurePass123`

---

## Email Verification

### Verification Flow

1. User signs up with email and password
2. Supabase sends verification email
3. User clicks verification link
4. Email is marked as verified
5. User can now login

### Check Verification Status

```dart
if (authService.isEmailVerified) {
  print('Email is verified');
} else {
  print('Please verify your email');
}
```

### Resend Verification Email

```dart
try {
  await authService.resendVerificationEmail();
  print('Verification email sent!');
} catch (e) {
  print('Error: $e');
}
```

---

## Error Handling

### Common Errors

| Error | Meaning | Solution |
|-------|---------|----------|
| `Invalid login credentials` | Wrong email/password | Check credentials |
| `Email not confirmed` | Email not verified | Verify email first |
| `User already registered` | Email exists | Use login instead |
| `Invalid email` | Malformed email | Check email format |
| `Weak password` | Password too weak | Use stronger password |

### Error Handling Pattern

```dart
try {
  await authService.signIn(email: email, password: password);
  // Success
} on AuthException catch (e) {
  // Handle specific auth errors
  if (e.message.contains('Invalid login credentials')) {
    showError('Wrong email or password');
  } else if (e.message.contains('Email not confirmed')) {
    showError('Please verify your email first');
  }
} catch (e) {
  // Handle other errors
  showError('An error occurred: $e');
}
```

---

## Security Best Practices

### ✅ Implemented

- Passwords are hashed and never stored in plain text
- Secure session token storage
- HTTPS-only communication (via Supabase)
- Email verification required
- Password strength validation
- Session expiration
- Logout confirmation

### 🔐 Recommendations

1. **Enable MFA** (Multi-Factor Authentication)
   ```dart
   // In Supabase Dashboard:
   // Authentication > Settings > Enable MFA
   ```

2. **Rate Limiting**
   - Limit login attempts
   - Prevent brute force attacks

3. **Session Timeout**
   - Configure in Supabase settings
   - Default: 3600 seconds (1 hour)

4. **Strong Password Policy**
   - Enforce in backend
   - Educate users

---

## Supabase Configuration

### Required Tables

The authentication system requires a `users` table:

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'staff',
    department VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index
CREATE INDEX idx_users_email ON users(email);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

-- Policy: Users can update their own data
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);
```

### Email Templates

Customize in Supabase Dashboard:
- **Authentication > Email Templates**
- Confirmation email
- Password reset email
- Magic link email

---

## Testing

### Test User Creation

```dart
// Create test user
await authService.signUp(
  email: 'test@example.com',
  password: 'TestPass123',
  fullName: 'Test User',
);
```

### Test Login

```dart
// Test login
await authService.signIn(
  email: 'test@example.com',
  password: 'TestPass123',
);

assert(authService.isSignedIn == true);
```

### Test Logout

```dart
// Test logout
await authService.signOut();
assert(authService.isSignedIn == false);
```

---

## Troubleshooting

### Issue: Email Not Sending

**Solution:**
1. Check Supabase email settings
2. Verify SMTP configuration
3. Check spam folder
4. Enable email provider

### Issue: Session Not Persisting

**Solution:**
1. Check Supabase initialization
2. Verify session storage
3. Check for errors in console

### Issue: Password Reset Not Working

**Solution:**
1. Verify email configuration
2. Check redirect URLs in Supabase
3. Ensure reset URL is whitelisted

---

## Future Enhancements

### Planned Features

- [ ] Social login (Google, Apple, Microsoft)
- [ ] Multi-factor authentication (MFA)
- [ ] Biometric authentication (fingerprint, Face ID)
- [ ] Remember device
- [ ] Login history
- [ ] Security notifications
- [ ] Role-based access control (RBAC)
- [ ] OAuth2 integration

### Social Login Example

```dart
// Google Sign In
await authService.signInWithGoogle();

// Apple Sign In
await authService.signInWithApple();
```

---

## API Integration

The authentication system integrates with the backend API:

### Headers

All API requests include authentication:

```dart
headers: {
  'Authorization': 'Bearer ${authService.accessToken}',
}
```

### Backend Validation

```python
# In Flask backend
from functools import wraps
from flask import request

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return {'error': 'No token provided'}, 401
        
        # Verify token with Supabase
        # ... verification logic
        
        return f(*args, **kwargs)
    return decorated

@app.route('/api/classify')
@require_auth
def classify():
    # Protected endpoint
    pass
```

---

## Resources

- [Supabase Auth Docs](https://supabase.com/docs/guides/auth)
- [Flutter Supabase Package](https://pub.dev/packages/supabase_flutter)
- [Auth Best Practices](https://supabase.com/docs/guides/auth/auth-helpers)
- [Security Guidelines](https://supabase.com/docs/guides/auth/auth-security)

---

**Last Updated**: January 2025  
**Version**: 1.0.0
