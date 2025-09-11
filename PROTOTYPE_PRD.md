# Health Genie Prototype - Product Requirements Document

## Executive Summary

Health Genie is a generative AI healthcare mobile application designed to monitor, interpret, and improve individual health through comprehensive biometric tracking and AI-powered analysis. The prototype will demonstrate core functionality on iOS with Apple Watch integration.

## Product Vision

To create an intelligent health monitoring system that provides users with actionable insights about their health through continuous biometric monitoring, comprehensive health scoring, and AI-driven trend analysis.

## Prototype Scope

### In Scope
- iOS application for iPhone 12 (WiFi only)
- Apple Watch Series 7 integration (WiFi only)
- Core biometric monitoring
- Health score calculation and display
- Local data storage with cloud sync
- Basic AI trend analysis

### Out of Scope (for Prototype)
- Android support
- Companion Apple Watch app
- Advanced AI features (anomaly detection, recommendations)
- HIPAA compliance and security
- Multi-user support
- Export capabilities

## Functional Requirements

### 1. Biometric Data Collection

#### 1.1 Data Types
- **Heart Rate Monitoring**
  - Real-time heart rate
  - Heart rate variability (HRV)
  - Resting heart rate
  - Exercise heart rate zones

- **Motion Sensing**
  - Step counting
  - Activity recognition
  - Sleep quality assessment
  - Exercise detection

- **Blood Oxygen (SpO2)**
  - Periodic SpO2 readings
  - Trend tracking

- **Body Temperature**
  - Skin temperature readings
  - Temperature variations

#### 1.2 Collection Parameters
- Data collection occurs only when app is in foreground
- Exceptions for background collection:
  - Incoming phone calls
  - FaceTime calls
  - WhatsApp calls
  - Alarms and timers
  - Emergency SOS
  - Screen timeout

### 2. Data Management

#### 2.1 Local Storage
- Store biometric data in RAM initially
- Persist to SQLite database every 15 seconds
- Maintain 24-hour circular buffer
- FIFO overwrite policy when buffer is full
- Track data freshness with special codes (-1 for unchanged)

#### 2.2 Cloud Synchronization
- Sync to Supabase only over WiFi
- Queue-based upload system
- Maintain pointer to oldest unsync'd data
- Handle offline/online state transitions

### 3. Health Score System

#### 3.1 Score Categories
- **Cardiovascular Health**: Based on heart rate, HRV, blood pressure trends
- **Sleep Quality**: Sleep duration, interruptions, recovery metrics
- **Activity Level**: Steps, exercise minutes, movement patterns
- **Recovery**: Rest periods, stress indicators, HRV trends
- **Stress**: HRV patterns, heart rate spikes, activity balance

#### 3.2 Score Calculation
- Individual category scores (0-100)
- Weighted aggregate score
- Hybrid approach:
  - Rule-based thresholds for baseline
  - AI enhancement for personalization

#### 3.3 Score Tracking
- Real-time score updates
- Historical trend visualization
- Configurable time windows:
  - 5 days
  - 1 month
  - 6 months
  - 1 year
  - 5 years
  - All time

### 4. User Interface

#### 4.1 Core Screens
- **Dashboard**: Current health score and key metrics
- **Real-time Monitor**: Live biometric display
- **Historical Charts**: Trend visualization
- **Settings**: Configuration and permissions

#### 4.2 Data Visualization
- Real-time biometric readings
- Score gauges and indicators
- Time-series charts
- Trend arrows and changes

### 5. AI Integration

#### 5.1 Trend Analysis (Prototype Focus)
- Analyze historical patterns
- Identify significant changes
- Generate basic insights
- Weekly/monthly summaries

#### 5.2 Backend Architecture
- Python FastAPI backend
- LangGraph for workflow orchestration
- Claude Sonnet 3.5 for analysis
- RESTful API communication

## Non-Functional Requirements

### 1. Performance
- Data persistence within 15 seconds
- UI refresh rate: 1Hz for real-time data
- App launch time: < 3 seconds
- Smooth scrolling and transitions

### 2. Reliability
- Handle Apple Watch disconnection gracefully
- Queue data during offline periods
- Recover from app termination
- Maintain data integrity

### 3. Usability
- Clear permission requests
- Intuitive navigation
- Visible connection status
- Error notifications

### 4. Compatibility
- iOS 15.0 or later
- iPhone 12 and newer
- Apple Watch Series 7 and newer
- WiFi connectivity required

## Technical Requirements

### 1. Development Environment
- Flutter SDK 3.x
- Xcode 15+
- Python 3.13+
- Git/GitHub for version control

### 2. Dependencies
- Flutter packages:
  - health (HealthKit integration)
  - provider (state management)
  - sqflite (local database)
  - supabase_flutter (cloud sync)
  - fl_chart (data visualization)

### 3. Testing
- Unit tests for business logic
- Widget tests for UI components
- Integration tests for data flow
- TestFlight for beta testing

## Success Criteria

### Prototype Milestones
1. ✅ Successfully pair with Apple Watch
2. ✅ Collect and display real-time biometrics
3. ✅ Calculate and show health scores
4. ✅ Store 24 hours of local data
5. ✅ Sync data to cloud over WiFi
6. ✅ Generate AI-powered trend analysis
7. ✅ Deploy via TestFlight

### Key Metrics
- Data collection reliability: > 95%
- Sync success rate: > 90% (when WiFi available)
- App stability: < 1 crash per 100 sessions
- Battery impact: < 10% additional drain

## Constraints

### Technical Constraints
- No cellular data usage
- Foreground-only operation (with exceptions)
- 24-hour local storage limit
- WiFi-only cloud sync

### Resource Constraints
- Single developer
- Testing on personal devices only
- No budget for paid services (free tiers only)

## Future Considerations (Post-Prototype)

- Android support
- WatchOS companion app
- Advanced AI features (anomaly detection, personalized recommendations)
- HIPAA compliance and encryption
- Multi-user/family support
- Healthcare provider integration
- Export to common health formats
- Background data collection
- Cellular data support

## Approval

This PRD defines the scope and requirements for the Health Genie prototype. Development will proceed in phases as outlined, with regular testing and validation at each milestone.

**Status**: Approved for prototype development
**Date**: September 2024
**Version**: 1.0