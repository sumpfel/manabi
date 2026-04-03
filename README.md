# 🎌 Manabi (学び) — Next-Gen Japanese Learning

**Manabi** is a modern, AI-powered language learning application built with Flutter. It focuses on contextual learning through Manga, smart SRS (Spaced Repetition System) vocabulary training, and deep AI-driven grammar explanations.

![App Icon](assets/manabi_icon.png)

## 🌟 Key Features

### 📖 Interactive Manga Reader
- **Direct Reading**: Read your favorite Manga directly in the app.
- **Smart OCR & Translation**: Tap on any sentence to get instant translations and grammar breakdowns.
- **Vocabulary Extraction**: Save new words directly from the pages you are reading into your study decks.

### 🧠 Spaced Repetition System (SRS)
- **Scientific Learning**: Optimized review cycles based on your performance.
- **Rich Media**: Flashcards include kanji, hiragana, romaji, and contextual example sentences.
- **Manual & AI Decks**: Organize your learning with custom decks or generate AI-assisted vocabulary lists.

### 🤖 AI Sensei (Tutor)
- **Contextual Explanations**: Ask questions about specific grammar points appearing in your reading.
- **Auto-Titling**: Your conversations are automatically organized with descriptive titles.
- **Multi-Model Support**: Connect to **Ollama** (Local), **Gemini**, **OpenAI**, or **Anthropic**.
- **Offline First**: Full support for local LLMs via Ollama.

### 📈 Progress Tracking
- **Daily Streaks**: Stay motivated with daily learning goals.
- **Grammar Path**: Follow a structured learning path with units ranging from N5 to N1.
- **Statistics**: Detailed insights into your vocabulary growth and study time.

## 🛠️ Tech Stack
- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Database**: [SQLite](https://sqlite.org) (sqflite)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Themes**: Modern Dark/Ultra-Black Productivity Dashboard

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (^3.10.4)
- Android Studio / VS Code with Flutter extension
- (Optional) [Ollama](https://ollama.com/) for local AI features

### Installation
1. Clone the repository:
   ```bash
   git clone git@github.com:sumpfel/manabi.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in the root and add your API keys (optional):
   ```env
   GEMINI_API_KEY=your_key_here
   OPENAI_API_KEY=your_key_here
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## 🔐 Privacy
Manabi is designed with an **Offline-First** philosophy. Your reading history, vocabulary progress, and AI conversations are stored locally on your device.

---
Made with ❤️ for Japanese learners.
