# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Health Genie

Health Genie is a Flutter-based iOS health monitoring application that collects biometric data from Apple Watch, calculates health scores, provides AI-powered health insights, and securely syncs data across devices using HIPAA-compliant cloud storage.

## Technology Stack

### Mobile Application (Flutter)
- **Framework**: Flutter (Dart)
- **State Management**: Provider package
- **HealthKit Integration**: health package (pub.dev)
- **Local Database**: SQLite via sqflite package
- **Cloud Sync**: Supabase Flutter SDK
- **Authentication**: Supabase Auth (Email/Password + Apple Sign In)
- **Testing**: Unit tests, widget tests, integration tests

### Backend Services (Python)
- **API Framework**: FastAPI
- **AI Orchestration**: LangGraph (LangChain)
- **LLM**: Claude Sonnet 3.5 (Anthropic)

### Cloud Infrastructure
- **Database**: Supabase (PostgreSQL with Row Level Security)
- **Authentication**: Supabase Auth (Email/Password + Apple Sign In)
- **Sync Strategy**: WiFi-only auto-sync (15 min) + manual sync option
- **Data Tables**:
  - `health_scores`: Calculated health metrics
  - `biometric_summaries`: Daily aggregated biometrics
  - `user_profiles`: User account information
- **Security**: TLS/SSL encryption, RLS policies, user data isolation
- **HIPAA Compliance**: Architecture ready (requires Pro tier + BAA)

## Project Structure

```
health-genie/
├── flutter_app/           # Flutter mobile application
│   ├── lib/
│   │   ├── config/       # Supabase configuration
│   │   ├── models/       # Data models
│   │   ├── services/     # Core services
│   │   │   ├── healthkit_service.dart
│   │   │   ├── database_service.dart
│   │   │   ├── health_score_service.dart
│   │   │   ├── cloud_sync_service.dart
│   │   │   ├── supabase_auth_service.dart
│   │   │   └── long_term_health_score_service.dart
│   │   ├── providers/    # State management
│   │   ├── screens/      # UI screens
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   └── login_screen.dart
│   │   └── widgets/      # Reusable widgets
│   ├── supabase/         # Database setup scripts
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
- Multi-tier collection intervals:
  - Fast metrics: 10 seconds (steps, distance, energy)
  - Standard metrics: 30 seconds (heart rate, activity)
  - Slow metrics: 3 minutes (HRV, SpO2, resting HR)
  - Background metrics: 1 hour (body temp, sleep)
- Persist data from RAM to SQLite with circular buffer
- Maintain 24-hour local storage (5760 records max)
- Track unchanged values with special code (-1)
- Automatic cloud sync every 15 minutes on WiFi

### Health Score Calculation
- Categories: Cardiovascular, Sleep, Activity, Recovery, Stress
- Hybrid approach: rule-based thresholds + AI analysis
- Dual scoring system:
  - Instant scores: Real-time calculations
  - Long-term scores: 30-day weighted averages
- Confidence levels based on data availability
- Configurable time windows for trend analysis

### Error Handling
- Display notifications for:
  - Apple Watch disconnection
  - WiFi unavailability
  - HealthKit permission denials
  - Cloud sync failures
  - Authentication errors
- Implement retry logic for sync operations
- Queue failed uploads for later sync

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