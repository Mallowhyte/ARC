# 🚀 Quick Start: Authentication Setup

Complete this 5-minute setup to enable authentication in ARC.

---

## Step 1: Configure Supabase (2 minutes)

### 1.1 Update Config File

Edit `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  // Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://yfosfxhwxikgqpjdtvlo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlmb3NmeGh3eGlrZ3FwamR0dmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzMzcyNTYsImV4cCI6MjA3NzkxMzI1Nn0.YkLJL4GlbmXBXP0zkKbaXKgEfqzbL_ioRFx6IGfUauI';
  
  static const String backendUrl = 'http://localhost:5000';
}
```

**Where to find your credentials:**
1. Go to [supabase.com](https://supabase.com)
2. Open your project
3. Go to **Settings** → **API**
4. Copy:
   - Project URL → `supabaseUrl`
   - `anon` `public` key → `supabaseAnonKey`

---

## Step 2: Create Users Table (1 minute)

### 2.1 Run SQL in Supabase

1. Go to **SQL Editor** in Supabase Dashboard
2. Click **New Query**
3. Paste this SQL:

```sql
-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'staff',
    department VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index
CREATE INDEX idx_users_email ON users(email);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

-- Policy: Users can update own data
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);
```

4. Click **Run** or press `Ctrl+Enter`

---

## Step 3: Enable Email Auth (1 minute)

### 3.1 Enable Provider

1. Go to **Authentication** → **Providers**
2. Find **Email** provider
3. Make sure it's **Enabled** (toggle on)

### 3.2 Configure Email Settings

1. Go to **Authentication** → **Settings**
2. Check **Enable email confirmations**
3. Save changes

---

## Step 4: Test the App (1 minute)

### 4.1 Run Flutter App

```bash
flutter pub get
flutter run
```

### 4.2 Create Test Account

1. App will open to **Login Screen**
2. Click **"Sign Up"**
3. Fill in details:
   - Name: Test User
   - Email: test@example.com
   - Password: TestPass123
   - Confirm password
4. Check "I agree to Terms"
5. Click **"Sign Up"**

### 4.3 Check Email

1. Open your email inbox
2. Look for verification email from Supabase
3. Click verification link

### 4.4 Login

1. Return to app
2. Enter credentials
3. Click **"Login"**
4. You're in! 🎉

---

## ✅ Verification Checklist

- [ ] Supabase credentials added to `supabase_config.dart`
- [ ] Users table created in Supabase
- [ ] Email authentication enabled
- [ ] Test account created successfully
- [ ] Verification email received
- [ ] Login works correctly
- [ ] User profile displays in app
- [ ] Logout works correctly

---

## 🐛 Troubleshooting

### Problem: "Invalid Supabase URL or key"

**Solution**: 
- Double-check credentials in `supabase_config.dart`
- Ensure no extra spaces or quotes
- Use the `anon` `public` key, not `service_role`

### Problem: "Error creating user profile"

**Solution**:
- Make sure users table is created
- Check SQL ran successfully
- Verify table exists in Supabase Table Editor

### Problem: "Verification email not received"

**Solution**:
- Check spam folder
- Verify email auth is enabled
- Check Supabase email logs (Auth → Logs)
- For development, you can skip verification in Supabase settings

### Problem: "Cannot connect to backend"

**Solution**:
- Backend is optional for auth testing
- Auth works independently
- Update `backendUrl` to your deployed backend URL when ready

---

## 📱 Using Authentication

### Check if User is Logged In

```dart
import 'package:auto_file_classifier/services/auth_service.dart';

final auth = AuthService();

if (auth.isSignedIn) {
  print('Logged in as: ${auth.currentUserEmail}');
}
```

### Get Current User Info

```dart
final userId = auth.currentUserId;
final email = auth.currentUserEmail;
final name = auth.userFullName;
```

### Sign Out Programmatically

```dart
await auth.signOut();
```

---

## 🎯 What's Next?

Now that auth is working:

1. **Start using the app**
   - Upload documents
   - View classified files
   - Check statistics

2. **Configure backend** (optional)
   - Update backend URL in config
   - Connect to Flask API
   - Enable document classification

3. **Customize**
   - Update email templates in Supabase
   - Add more user fields
   - Implement roles and permissions

---

## 📚 More Information

- **Full Auth Documentation**: `docs/authentication.md`
- **Implementation Details**: `AUTH_IMPLEMENTATION.md`
- **API Reference**: `docs/api_endpoints.md`

---

## 🆘 Need Help?

1. Check error messages carefully
2. Review Supabase logs (Auth → Logs)
3. Verify all setup steps completed
4. Check Flutter console for errors
5. Review documentation files

---

**Setup Time**: ~5 minutes  
**Difficulty**: Easy  
**Status**: Production Ready ✅

Happy coding! 🚀
