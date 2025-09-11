# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Health Genie

Health Genie is a Flutter-based iOS health monitoring application that collects biometric data from Apple Watch, calculates health scores, and provides AI-powered health insights.

## Technology Stack

### Mobile Application (Flutter)
- **Framework**: Flutter (Dart)
- **State Management**: Provider package
- **HealthKit Integration**: health package (pub.dev)
- **Local Database**: SQLite via sqflite package
- **Testing**: Unit tests, widget tests, integration tests

### Backend Services (Python)
- **API Framework**: FastAPI
- **AI Orchestration**: LangGraph (LangChain)
- **LLM**: Claude Sonnet 3.5 (Anthropic)

### Cloud Infrastructure
- **Database**: Supabase (PostgreSQL)
- **Sync Strategy**: WiFi-only manual sync with queue-based uploads

## Project Structure

```
health-genie/
├── flutter_app/           # Flutter mobile application
│   ├── lib/
│   │   ├── models/       # Data models
│   │   ├── services/     # HealthKit, database, API services
│   │   ├── providers/    # State management
│   │   ├── screens/      # UI screens
│   │   └── widgets/      # Reusable widgets
│   └── test/             # Unit and widget tests
├── backend/              # Python backend
│   ├── api/             # FastAPI endpoints
│   ├── langgraph/       # LangGraph workflows
│   └── tests/           # Backend tests
└── docs/                # Documentation
```

## Development Setup

### Flutter Development
```bash
# Install Flutter SDK
# Set up iOS development environment (Xcode)
cd flutter_app
flutter pub get
flutter run
```

### Python Backend
```bash
source venv/bin/activate
cd backend
pip install -r requirements.txt
uvicorn api.main:app --reload
```

## Implementation Guidelines

### Data Collection
- Collect biometrics only when app is in foreground (with specified exceptions)
- Persist data from RAM to SQLite every 15 seconds
- Maintain 24-hour circular buffer for local storage
- Track unchanged values with special code (-1)

### Health Score Calculation
- Categories: Cardiovascular, Sleep, Activity, Recovery, Stress
- Hybrid approach: rule-based thresholds + AI analysis
- Configurable time windows for trend analysis

### Error Handling
- Display notifications for:
  - Apple Watch disconnection
  - WiFi unavailability
  - HealthKit permission denials

### Testing Requirements
- Write unit tests for all business logic
- Create widget tests for UI components
- Implement integration tests for data flows
- Test on iPhone 12 and Apple Watch Series 7

## Git Workflow

- Default branch for development: `wip`
- Production-ready code: `main`
- Use descriptive commit messages
- Regular syncs between Mac Mini and MacBook Pro

## Code Standards

### Flutter/Dart
- Follow Dart style guide
- Use const constructors where possible
- Implement proper error handling with try-catch
- Add documentation comments for public APIs

### Python
- Follow PEP 8 style guidelines
- Use type hints
- Create docstrings for modules, classes, and functions
- Prefer pathlib.Path over os.path

## Important Reminders

- Do what has been asked; nothing more, nothing less
- NEVER create files unless they're absolutely necessary for achieving the goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- Test thoroughly before committing changes
- Consider battery optimization for continuous monitoring