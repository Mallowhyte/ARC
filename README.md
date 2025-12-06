# ARC – Automated Record Classifier

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/arc)
[![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-blue.svg)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Python-3.12%2B-yellow.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-Educational-green.svg)](LICENSE)

> 🎓 **An intelligent document management system that automatically classifies and organizes academic and administrative documents using OCR and machine learning.**

ARC (Automated Record Classifier) is a full-stack mobile application designed for school administrators, faculty staff, and registrar offices. It eliminates manual document sorting by automatically extracting text from uploaded files and classifying them into predefined categories such as **Exam Forms**, **Grade Sheets**, **Receipts**, **Clearances**, and more.

**✨ Key Benefits:**
- ⚡ **Fast Processing** - Documents classified in seconds
- 🎯 **High Accuracy** - Advanced OCR with Tesseract 5.3+
- 🔒 **Secure Storage** - Cloud-based storage with Supabase
- 📱 **Mobile-First** - Native Flutter mobile app
- 🔄 **Real-time Sync** - Instant updates across devices

---

## 📑 Table of Contents

- [Features](#-features)
- [System Architecture](#-system-architecture)
- [Quick Start](#-quick-start)
- [Documentation](#-documentation)
- [Technology Stack](#-technology-stack)
- [Project Status](#-project-status)
- [Contributing](#-contributing)

---

## ✨ Features

### Core Features
- 📤 **Document Upload** - Camera, gallery, or file system
- 🔍 **OCR Text Extraction** - Tesseract-powered text recognition
- 🤖 **Auto-Classification** - 10 document categories
- 💾 **Cloud Storage** - Secure file storage with Supabase
- 📊 **Statistics Dashboard** - Upload trends and analytics
- 🔐 **User Authentication** - Email/password with OTP verification
- 📱 **Cross-Platform** - Android, iOS, Web support

### Document Categories
1. Exam Form
2. Acknowledgement Form
3. Clearance
4. Receipt
5. Grade Sheet
6. Enrollment Form
7. ID Application
8. Certificate Request
9. Leave Form
10. Other

---

## 🏗️ System Architecture

### High-Level Overview

```
┌─────────────────┐
│  Flutter App    │ ◄─── Mobile/Web Interface
│  (Frontend)     │      • User authentication
└────────┬────────┘      • Document upload
         │ HTTPS         • View documents
         │ REST API      • Statistics
         │
┌────────▼────────┐
│  Flask Backend  │ ◄─── Processing Engine
│  (Python)       │      • OCR processing
└────┬───────┬────┘      • Classification
     │       │            • API endpoints
     │       │
┌────▼────┐  ┌────▼──────┐
│Tesseract│  │ Supabase  │
│   OCR   │  │ Database  │
└─────────┘  │ & Storage │
             └───────────┘
```

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|----------|
| **Frontend** | Flutter | 3.5+ | Cross-platform mobile app |
| **Backend** | Flask | 3.0.0 | REST API server |
| **OCR Engine** | Tesseract | 5.3.3 | Text extraction |
| **ML** | scikit-learn | 1.3.2 | Document classification |
| **Database** | Supabase (PostgreSQL) | 14+ | Data storage |
| **Storage** | Supabase Storage | - | File storage |
| **Auth** | Supabase Auth | - | User authentication |

---

## 🚀 Quick Start

### Prerequisites

**Software Requirements:**
- Python 3.12 or higher
- Flutter SDK 3.5 or higher
- Tesseract OCR 5.3+
- Git

**Accounts:**
- Supabase account (free tier available)

### Installation

**1. Clone Repository**
```bash
git clone <repository-url>
cd auto_file_classifier
```

**2. Backend Setup**
```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
copy .env.example .env
# Edit .env with your Supabase credentials

# Start server
python app.py
```

**3. Frontend Setup**
```bash
cd ..

# Install dependencies
flutter pub get

# Update configuration
# Edit lib/config/supabase_config.dart with your credentials

# Run app
flutter run
```

**4. Database Setup**
- Go to Supabase Dashboard
- Run SQL from `database_setup_complete.sql`
- Create storage bucket named `documents`

### Verify Installation

**Test Backend:**
```bash
curl http://localhost:5000/health
```

**Test Tesseract:**
```bash
cd backend
python test_tesseract.py
```

**Expected Result:** ✓ All checks pass

**For detailed setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**

---

## 📚 Documentation

### Essential Guides

📘 **[SYSTEM_OVERVIEW.md](SYSTEM_OVERVIEW.md)**  
Comprehensive system architecture, features, and technical overview.

📗 **[SETUP_GUIDE.md](SETUP_GUIDE.md)**  
Step-by-step installation and configuration instructions.

📙 **[API_DOCUMENTATION.md](API_DOCUMENTATION.md)**  
Complete REST API reference with examples.

📕 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**  
Common issues and their solutions.

📔 **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**  
Production deployment instructions and best practices.

### Additional Documentation

- **[Database Schema](docs/database_schema.md)** - Database structure and queries
- **[Authentication](docs/authentication.md)** - Authentication system details
- **[Email Configuration](docs/email_configuration.md)** - Email setup guide

---

## 📁 Project Structure

```
auto_file_classifier/
├── lib/                           # Flutter frontend
│   ├── main.dart                 # App entry point
│   ├── config/                   # Configuration
│   │   └── supabase_config.dart  # API endpoints
│   ├── screens/                  # UI screens
│   │   ├── auth/                 # Authentication screens
│   │   ├── home_screen.dart      # Home dashboard
│   │   ├── upload_screen.dart    # Upload interface
│   │   ├── documents_screen.dart # Document list
│   │   └── statistics_screen.dart # Analytics
│   ├── services/                 # Business logic
│   │   ├── api_service.dart      # Backend API client
│   │   └── auth_service.dart     # Authentication
│   └── models/                   # Data models
│       └── document_model.dart   # Document schema
├── backend/                       # Python Flask backend
│   ├── app.py                    # Main API server
│   ├── ocr_engine.py             # OCR processing
│   ├── ml_classifier.py          # Classification logic
│   ├── supabase_client.py        # Database client
│   ├── requirements.txt          # Dependencies
│   ├── .env                      # Environment variables
│   └── test_tesseract.py         # OCR test script
├── docs/                          # Technical documentation
├── SYSTEM_OVERVIEW.md            # Architecture overview
├── SETUP_GUIDE.md                # Installation guide
├── API_DOCUMENTATION.md          # API reference
├── TROUBLESHOOTING.md            # Problem solving
├── DEPLOYMENT_GUIDE.md           # Production deployment
└── database_setup_complete.sql   # Database schema
```

---

## 🎯 Project Status

### Current Version: 1.0.0 ✅

**Completed Features:**
- ✅ User authentication (signup, login, email verification)
- ✅ Document upload (camera, gallery, files)
- ✅ OCR text extraction (Tesseract 5.3.3)
- ✅ Document classification (10 categories)
- ✅ Cloud storage (Supabase)
- ✅ Document management (list, filter, view)
- ✅ Statistics dashboard
- ✅ Mobile app (Android/iOS)
- ✅ Responsive design
- ✅ Error handling

**System Health:**
- 🟢 Backend: Operational
- 🟢 Database: Connected
- 🟢 Storage: Available
- 🟢 OCR: Functional
- 🟢 Authentication: Active

### Roadmap

**v1.1.0 (Future)**
- [ ] Custom ML model training
- [ ] Batch document upload
- [ ] Advanced search functionality
- [ ] Export reports (PDF/Excel)
- [ ] Admin dashboard
- [ ] Multi-language OCR support

---

## 🤝 Contributing

This project is currently in active development for educational purposes.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Style

**Python (Backend):**
- Follow PEP 8 guidelines
- Use type hints
- Add docstrings to functions

**Dart (Frontend):**
- Follow Dart style guide
- Use meaningful variable names
- Comment complex logic

---

## 👥 Target Users

- **Administrative Staff** - Upload and manage documents
- **Faculty Members** - Organize departmental files
- **Registrar Staff** - Retrieve categorized records
- **IT Administrators** - System maintenance and monitoring

---

## 📞 Support

### Getting Help

1. **Check Documentation** - See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Review Issues** - Search existing GitHub issues
3. **Check Logs** - Backend terminal and Flutter console
4. **Test Connectivity** - Verify backend and Supabase connection

### Common Issues

- **Tesseract not found** → See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#issue-1-tesseract-not-found)
- **Connection timeout** → See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#issue-1-connection-refused-from-phone)
- **Database errors** → See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#database-issues)

---

## 🔐 Security

### Best Practices

- ✅ Environment variables for secrets
- ✅ Row-Level Security (RLS) enabled
- ✅ JWT-based authentication
- ✅ Input validation and sanitization
- ✅ HTTPS for production
- ✅ Secure password hashing

**⚠️ Important:** Never commit `.env` files or API keys to version control.

---

## 📄 License

This project is developed for **educational purposes**.

### Usage Terms

- ✅ Use for learning and education
- ✅ Modify and extend functionality
- ✅ Deploy for personal/academic projects
- ⚠️ Not for commercial use without permission

---

## 🙏 Acknowledgments

**Technologies Used:**
- [Flutter](https://flutter.dev/) - Cross-platform framework
- [Flask](https://flask.palletsprojects.com/) - Python web framework
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) - Text recognition
- [Supabase](https://supabase.com/) - Backend-as-a-Service
- [scikit-learn](https://scikit-learn.org/) - Machine learning

---

## 📬 Contact

For questions, suggestions, or collaboration:

- **Documentation Issues:** Open a GitHub issue
- **Technical Support:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Feature Requests:** Submit via GitHub discussions

---

**Built with ❤️ for educational purposes**

[![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-blue.svg)](https://flutter.dev/)
[![Powered by Supabase](https://img.shields.io/badge/Powered%20by-Supabase-green.svg)](https://supabase.com/)
[![OCR by Tesseract](https://img.shields.io/badge/OCR%20by-Tesseract-orange.svg)](https://github.com/tesseract-ocr/tesseract)
