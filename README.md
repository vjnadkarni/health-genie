# Galeno Genie

A comprehensive health monitoring iOS application that integrates with Apple Watch to collect, analyze, and securely sync biometric data across devices with HIPAA-compliant cloud storage.

## Features

- **Real-time Biometric Monitoring**
  - Heart Rate & Heart Rate Variability (HRV)
  - Blood Oxygen Saturation (SpO2)
  - Steps, Distance, and Active Calories
  - Resting Heart Rate
  - Body Temperature (when available)
  - Sleep Analysis

- **Advanced Health Score Dashboard**
  - Overall health score with confidence levels
  - Category scores: Cardiovascular, Sleep, Activity, Recovery, Stress
  - Visual charts and trends
  - Instant scores and 30-day long-term analysis

- **Secure Cloud Synchronization**
  - HIPAA-compliant cloud storage with Supabase
  - Cross-device data access
  - Row Level Security (RLS) for data isolation
  - Email/password and Apple Sign In authentication
  - WiFi-only auto-sync to conserve bandwidth
  - Manual sync option for immediate updates

- **Data Management**
  - Multi-tier collection: 10s (fast), 30s (standard), 3m (slow), 1h (background)
  - Local SQLite database with 24-hour circular buffer
  - Offline functionality with sync queue
  - Automatic data aggregation and summarization

- **Apple Watch Integration**
  - Direct Bluetooth connection
  - HealthKit integration with comprehensive permissions
  - Support for Apple Watch Series 7+
  - Background data collection

## Current Status

✅ **Completed Features:**
- HealthKit integration and permissions
- Real-time multi-tier data collection from Apple Watch
- SQLite database with circular buffer (24-hour retention)
- Advanced dashboard UI with live metrics
- Health score calculations with confidence levels
- Secure cloud sync with Supabase (PostgreSQL + RLS)
- Authentication system (email/password + Apple Sign In)
- Settings screen with sync controls
- Cross-device data access capability
- Offline functionality with sync queue
- Release build deployed and tested on iPhone 12

## Requirements

- iPhone running iOS 13.0+
- Apple Watch Series 7 or newer
- Xcode 14+ (for development)
- Flutter 3.35.3+

## Installation

### Prerequisites
1. Install Flutter and Xcode
2. Set up Supabase account (free tier available)
3. Configure Supabase project with provided SQL schema

### Setup Steps
1. Clone the repository:
```bash
git clone https://github.com/vjnadkarni/galeno-genie.git
cd galeno-genie/flutter_app
```

2. Install dependencies:
```bash
flutter pub get
cd ios && pod install
```

3. Configure Supabase credentials:
   - Copy `lib/config/supabase_config.example.dart` to `lib/config/supabase_config.dart`
   - Add your Supabase URL and anon key

4. Run database setup:
   - Open Supabase SQL Editor
   - Execute `supabase/setup_database.sql`

5. Build and install:
```bash
flutter build ios --release
flutter install -d [device-id]
```

## Usage

### Initial Setup
1. Open Galeno Genie app on iPhone
2. Grant HealthKit permissions when prompted
3. Ensure Apple Watch is paired and worn
4. Create account or sign in for cloud sync

### Daily Use
1. View real-time metrics on dashboard
2. Monitor health scores and trends
3. Data updates automatically:
   - Fast metrics: every 10 seconds
   - Standard metrics: every 30 seconds
   - Slow metrics: every 3 minutes
4. Sync to cloud via Settings → Manual Sync

### Cross-Device Access
1. Install app on additional iPhone
2. Sign in with same credentials
3. Health data automatically syncs

## Data Privacy & Security

- **Local Storage**: SQLite with 24-hour circular buffer
- **Cloud Storage**: Supabase with Row Level Security (RLS)
- **Authentication**: Email/password or Apple Sign In
- **Data Encryption**: TLS/SSL for all transmissions
- **HIPAA Ready**: Architecture supports compliance (Pro tier required)
- **User Control**: Manual sync option, delete cloud data anytime
- **Offline Mode**: Full functionality without internet

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Testing Devices

- iPhone 12 (iOS 18.6.2)
- Apple Watch Series 7

## License

Private project - All rights reserved
