# Health Genie

A real-time health monitoring iOS application that integrates with Apple Watch to collect, analyze, and display biometric data.

## Features

- **Real-time Biometric Monitoring**
  - Heart Rate & Heart Rate Variability (HRV)
  - Blood Oxygen Saturation
  - Steps, Distance, and Active Calories
  - Resting Heart Rate
  
- **Health Score Dashboard**
  - Overall health score calculation
  - Category scores: Cardiovascular, Sleep, Activity, Recovery, Stress
  - Visual charts and trends
  
- **Data Management**
  - 15-second automatic data collection cycle
  - Local SQLite database with 24-hour rolling window
  - Offline functionality - works without WiFi
  
- **Apple Watch Integration**
  - Direct Bluetooth connection
  - HealthKit integration
  - Support for Apple Watch Series 7+

## Current Status

✅ **Completed Features:**
- HealthKit integration and permissions
- Real-time data collection from Apple Watch
- SQLite database with circular buffer
- Dashboard UI with live metrics
- Health score calculations
- Offline functionality
- Release build deployed to iPhone 12

## Requirements

- iPhone running iOS 13.0+
- Apple Watch Series 7 or newer
- Xcode 14+ (for development)
- Flutter 3.35.3+

## Installation

The app is currently installed on iPhone 12 for testing. For new installations:

1. Connect iPhone via USB
2. Build and install:
```bash
flutter build ios --release
flutter install -d [device-id]
```

## Usage

1. Open Health Genie app on iPhone
2. Grant HealthKit permissions when prompted
3. Ensure Apple Watch is paired and worn
4. View real-time metrics on dashboard
5. Data updates automatically every 15 seconds

## Data Privacy

- All health data stored locally on device
- No cloud sync or external data transmission
- 24-hour data retention policy
- Works completely offline

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Testing Devices

- iPhone 12 (iOS 18.6.2)
- Apple Watch Series 7

## License

Private project - All rights reserved
