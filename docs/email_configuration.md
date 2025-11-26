# Email Configuration for ARC

## Overview

This guide shows you how to configure custom email templates for ARC (AI-based Record Classifier) to send professional, branded verification emails with PIN codes.

---

## 🎯 Email Verification System

ARC uses **Supabase Auth** to send email verification messages with:

- ✅ **6-digit PIN code** for easy verification
- ✅ **Verification link** as alternative option
- ✅ **Custom branding** with "ARC" identity
- ✅ **Professional templates** for trust and credibility

---

## 📧 Email Types

### 1. **Sign Up Verification Email**

**Sent when:** User creates new account

**Contains:**
- 6-digit PIN code
- Verification link
- Welcome message
- App branding

**Subject:**
```
ARC Email Verification – Confirm Your Account
```

**Sender Name:**
```
ARC (AI-based Record Classifier)
```

---

## 🔧 Configuration Steps

### Step 1: Access Supabase Email Settings

1. Go to [supabase.com](https://supabase.com) and open your project
2. Navigate to **Authentication** → **Email Templates**
3. You'll see different template types:
   - Confirm signup
   - Magic Link
   - Change Email Address
   - Reset Password

### Step 2: Configure "Confirm Signup" Template

Click on **"Confirm signup"** template to edit.

#### Option A: Use Custom SMTP (Recommended for Production)

**Benefits:**
- Full control over sender email
- Professional domain email (e.g., noreply@arc-system.com)
- Better deliverability
- Custom branding

**Setup:**
1. Go to **Project Settings** → **Auth** → **SMTP Settings**
2. Configure your email provider:
   - **Gmail**
   - **SendGrid**
   - **AWS SES**
   - **Mailgun**
   - **Custom SMTP**

**Example (Gmail):**
```
SMTP Host: smtp.gmail.com
SMTP Port: 587
SMTP User: your-email@gmail.com
SMTP Password: your-app-password
Sender Email: noreply@yourdomain.com
Sender Name: ARC (AI-based Record Classifier)
```

#### Option B: Use Supabase Default Email (Quick Start)

**For development/testing:**
- Supabase provides default email service
- Works immediately without setup
- Limited customization
- May go to spam folder

---

## 📝 Email Template Customization

### Complete Email Template for Confirm Signup

Copy and paste this template into Supabase:

```html
<html>
<head>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      border-radius: 10px 10px 0 0;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
    }
    .header p {
      margin: 10px 0 0 0;
      font-size: 14px;
      opacity: 0.9;
    }
    .content {
      background: #ffffff;
      padding: 40px 30px;
      border: 1px solid #e0e0e0;
      border-top: none;
    }
    .pin-code {
      background: #f5f5f5;
      border: 2px dashed #667eea;
      padding: 20px;
      text-align: center;
      border-radius: 8px;
      margin: 30px 0;
    }
    .pin-code h2 {
      margin: 0 0 10px 0;
      color: #667eea;
      font-size: 16px;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    .pin-code .code {
      font-size: 36px;
      font-weight: bold;
      letter-spacing: 8px;
      color: #333;
      font-family: 'Courier New', monospace;
    }
    .button {
      display: inline-block;
      padding: 14px 30px;
      background: #667eea;
      color: white;
      text-decoration: none;
      border-radius: 6px;
      font-weight: 600;
      margin: 20px 0;
    }
    .button:hover {
      background: #5568d3;
    }
    .info-box {
      background: #e3f2fd;
      border-left: 4px solid #2196f3;
      padding: 15px;
      margin: 20px 0;
      border-radius: 4px;
    }
    .footer {
      background: #f5f5f5;
      padding: 20px 30px;
      border-radius: 0 0 10px 10px;
      border: 1px solid #e0e0e0;
      border-top: none;
      text-align: center;
      color: #666;
      font-size: 12px;
    }
    .divider {
      text-align: center;
      margin: 30px 0;
      color: #999;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🎓 ARC</h1>
    <p>AI-based Record Classifier</p>
  </div>
  
  <div class="content">
    <h2>Welcome to ARC!</h2>
    <p>Thank you for signing up. To complete your registration and verify your email address, please use the verification code below:</p>
    
    <div class="pin-code">
      <h2>Your Verification Code</h2>
      <div class="code">{{ .Token }}</div>
      <p style="margin: 10px 0 0 0; color: #666; font-size: 14px;">This code expires in 10 minutes</p>
    </div>
    
    <div class="info-box">
      <strong>📱 Using the mobile app?</strong><br>
      Simply enter this code in the verification screen.
    </div>
    
    <div class="divider">
      ── OR ──
    </div>
    
    <p style="text-align: center;">Click the button below to verify your email automatically:</p>
    
    <p style="text-align: center;">
      <a href="{{ .ConfirmationURL }}" class="button">Verify Email Address</a>
    </p>
    
    <p style="font-size: 13px; color: #666; margin-top: 30px;">
      <strong>Security Tips:</strong><br>
      • Don't share this code with anyone<br>
      • ARC will never ask for your password via email<br>
      • If you didn't create an account, please ignore this email
    </p>
  </div>
  
  <div class="footer">
    <p><strong>ARC - AI-based Record Classifier</strong></p>
    <p>Intelligent Document Management for Educational Institutions</p>
    <p style="margin-top: 10px;">
      This is an automated message, please do not reply to this email.
    </p>
  </div>
</body>
</html>
```

### Template Variables

Supabase provides these variables you can use:

| Variable | Description |
|----------|-------------|
| `{{ .Token }}` | 6-digit OTP code (e.g., 123456) |
| `{{ .ConfirmationURL }}` | Verification link |
| `{{ .Email }}` | User's email address |
| `{{ .SiteURL }}` | Your app URL |

---

## 📱 Mobile App Integration

The email verification screen in the Flutter app:

**Features:**
- ✅ Clean 6-digit PIN input interface
- ✅ Auto-focus on next field
- ✅ Auto-verify when all digits entered
- ✅ Resend code with countdown timer
- ✅ Error handling with helpful messages
- ✅ Alternative verification link option

**User Flow:**
```
Sign Up → Email Sent → Enter 6-Digit PIN → Verified → Home Screen
```

---

## 🎨 Customization Options

### Change Email Subject

In Supabase Email Templates, modify the **Subject** field:

**Default:**
```
Confirm your signup
```

**Recommended for ARC:**
```
ARC Email Verification – Confirm Your Account
```

### Change Sender Name

In SMTP Settings or Email Templates:

**Recommended:**
```
Sender Name: ARC (AI-based Record Classifier)
Sender Email: noreply@yourdomain.com
```

### Brand Colors

Update the CSS in the template:

```css
/* Primary Color */
.header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

/* Button Color */
.button {
  background: #667eea;
}

/* Accent Color */
.info-box {
  border-left: 4px solid #2196f3;
}
```

---

## 🔐 Security Best Practices

### OTP Configuration

**In Supabase Dashboard:**
1. Go to **Authentication** → **Settings**
2. Configure OTP settings:

```
OTP Expiry: 600 seconds (10 minutes)
OTP Length: 6 digits
Allow Multiple OTPs: Disabled (one active code at a time)
```

### Email Security

✅ **Use HTTPS** for confirmation URLs  
✅ **Enable rate limiting** to prevent spam  
✅ **Set expiry time** for verification codes  
✅ **Use SPF/DKIM** records for your domain  
✅ **Monitor failed attempts** in Supabase logs  

---

## 🧪 Testing the Email System

### Test in Development

1. **Sign up** with a real email address
2. **Check inbox** (and spam folder)
3. **Verify** the email looks correct
4. **Test PIN code** in the app
5. **Test verification link** as alternative

### Test Checklist

- [ ] Email arrives within 1 minute
- [ ] Subject line is correct: "ARC Email Verification – Confirm Your Account"
- [ ] Sender name is "ARC (AI-based Record Classifier)"
- [ ] PIN code is visible and formatted correctly
- [ ] Verification link works
- [ ] Branding (logo, colors) matches ARC design
- [ ] Mobile app accepts and verifies PIN
- [ ] Resend code functionality works
- [ ] Code expires after 10 minutes

---

## 📊 Monitoring Email Delivery

### Supabase Email Logs

**Location:** `Authentication` → `Logs`

**Information available:**
- Email send attempts
- Delivery status
- Failed deliveries
- Error messages

### Common Issues

#### Emails Going to Spam

**Solutions:**
- Use custom SMTP with verified domain
- Add SPF and DKIM records
- Avoid spam trigger words
- Use professional email service

#### Emails Not Arriving

**Troubleshooting:**
1. Check Supabase logs for errors
2. Verify SMTP credentials
3. Check email provider limits
4. Confirm user email is valid
5. Check spam folder

#### OTP Code Not Working

**Possible causes:**
- Code expired (10 minutes)
- Wrong code entered
- Multiple codes sent (use latest)
- Network issues

---

## 🚀 Production Deployment

### Pre-Launch Checklist

- [ ] Custom SMTP configured with professional email
- [ ] Domain verified with email provider
- [ ] SPF/DKIM records added to DNS
- [ ] Email templates tested and approved
- [ ] Sender name set to "ARC (AI-based Record Classifier)"
- [ ] Subject line configured correctly
- [ ] All links use HTTPS
- [ ] Rate limiting enabled
- [ ] Monitoring set up

### Recommended Email Providers

1. **SendGrid** - Reliable, good free tier
2. **Amazon SES** - Scalable, cost-effective
3. **Mailgun** - Developer-friendly
4. **Postmark** - High deliverability
5. **Gmail SMTP** - Easy for small scale

---

## 📧 Email Template Variables Reference

### Available in All Templates

```
{{ .Email }}           - Recipient email address
{{ .Token }}           - 6-digit OTP code
{{ .ConfirmationURL }} - Verification link
{{ .SiteURL }}         - Your app URL
{{ .TokenHash }}       - Token hash (for security)
{{ .RedirectTo }}      - Redirect URL after verification
```

### Example Usage

```html
<p>Hi {{ .Email }},</p>
<p>Your verification code is: <strong>{{ .Token }}</strong></p>
<p><a href="{{ .ConfirmationURL }}">Click here to verify</a></p>
```

---

## 🎯 Email Content Guidelines

### Subject Line Best Practices

✅ **Clear and concise**  
✅ **Include app name (ARC)**  
✅ **Action-oriented**  
✅ **Professional tone**  

**Examples:**
- ✅ "ARC Email Verification – Confirm Your Account"
- ✅ "Verify Your ARC Account"
- ❌ "Confirm your signup" (too generic)
- ❌ "URGENT!!!" (spammy)

### Email Body Guidelines

✅ **Greet the user professionally**  
✅ **State the purpose clearly**  
✅ **Display PIN prominently**  
✅ **Provide alternative (link)**  
✅ **Include security tips**  
✅ **Add expiry information**  
✅ **Professional footer with app info**  

---

## 📞 Support Information

Add support contact to email footer:

```html
<p>Need help? Contact us:</p>
<p>
  Email: support@arc-system.com<br>
  Website: https://arc-system.com
</p>
```

---

## 🔄 Email Template Versions

### Version 1.0 (Current)

**Features:**
- 6-digit PIN code
- Verification link alternative
- Professional ARC branding
- Security information
- Mobile-friendly design
- 10-minute expiry

### Future Enhancements

- [ ] Localization (multiple languages)
- [ ] Dark mode support
- [ ] QR code verification
- [ ] Social proof elements
- [ ] Personalized content

---

## 📚 Additional Resources

- **Supabase Email Docs**: https://supabase.com/docs/guides/auth/auth-email
- **Email Best Practices**: https://supabase.com/docs/guides/auth/auth-email-templates
- **SMTP Configuration**: https://supabase.com/docs/guides/auth/auth-smtp

---

## ✅ Quick Setup Summary

1. **Access Supabase** → Authentication → Email Templates
2. **Select** "Confirm signup" template
3. **Paste** the custom HTML template above
4. **Update** subject line to "ARC Email Verification – Confirm Your Account"
5. **Configure** sender name as "ARC (AI-based Record Classifier)"
6. **Save** and test with a real email
7. **Monitor** delivery in Authentication → Logs

---

**Email System Status**: ✅ Fully Implemented  
**Template Version**: 1.0  
**Last Updated**: January 2025

Your professional email verification system is ready! 🎉
