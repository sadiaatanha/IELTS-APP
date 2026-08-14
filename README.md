# IELTS-APP 🎓

An interactive IELTS preparation and practice application built with **Flutter**.  
The application provides students with dedicated practice environments for IELTS **Listening, Reading, Writing, and Speaking**, along with user profiles, analytics, results, and an administration dashboard.

## 🚀 Features

### 👨‍🎓 Student Features

- 🔐 User Registration and Login
- 🏠 Personalized Home Page
- 👤 User Profile Management
- 🎧 IELTS Listening Practice
- 📖 IELTS Reading Practice
- ✍️ IELTS Writing Practice
- 🗣️ IELTS Speaking Practice
- 📊 Performance Analytics
- 📝 Writing Task 1 Practice
- 📝 Writing Task 2 Practice
- 📋 Writing Tests and Answer Submission
- 📈 Results and Performance Tracking

### 👨‍💼 Admin Features

The application includes an administrative dashboard for managing IELTS content and users.

- 📊 Admin Dashboard
- 👥 User Management
- 🎧 Listening Question Management
- 📖 Reading Content Management
- ✍️ Writing Question Management
- 🗣️ Speaking Content Management
- 📋 Results Management
- 📥 Listening Question Import
- 📈 User Performance Monitoring

## 🛠️ Technologies Used

- **Flutter**
- **Dart**
- **Supabase**
- **REST/API Integration**
- **Groq API**
- **Gemini / AI-based services**
- **SQLite / Local Storage** *(where applicable)*

## 📂 Project Structure

```text
IELTS-APP/
│
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
├── web/
│
├── lib/
│   ├── admin/
│   │   ├── admin_dashboard.dart
│   │   ├── admin_listening_import_page.dart
│   │   ├── admin_reading_page.dart
│   │   ├── admin_results_page.dart
│   │   ├── admin_speaking_page.dart
│   │   ├── admin_users_page.dart
│   │   └── admin_writing_page.dart
│   │
│   ├── listening/
│   │   └── listening_page.dart
│   │
│   ├── models/
│   │   └── writing_question.dart
│   │
│   ├── services/
│   │   └── groq_service.dart
│   │
│   ├── analytics_page.dart
│   ├── home_page.dart
│   ├── login_page.dart
│   ├── main.dart
│   ├── profile_page.dart
│   ├── reading_page.dart
│   ├── reading_practice_list_page.dart
│   ├── register_page.dart
│   ├── speaking_page.dart
│   ├── writing_answer_page.dart
│   ├── writing_page.dart
│   ├── writing_task1_page.dart
│   ├── writing_task2_page.dart
│   └── writing_test_page.dart
│
├── supabase/
│   ├── functions/
│   │   └── gemini-feedback/
│   └── config.toml
│
├── test/
├── pubspec.yaml
└── README.md
