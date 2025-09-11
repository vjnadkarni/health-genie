#!/bin/bash

# Health Genie Development Environment Setup Script
# This script sets up all required tools and frameworks for Health Genie development
# It includes human-in-the-loop checkpoints for review and confirmation

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Setup variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"  # Parent directory (health-genie)
LOG_DIR="${SCRIPT_DIR}/setup_logs"
LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
DRY_RUN=false
CHECKPOINT_COUNT=0

# Create log directory
mkdir -p "$LOG_DIR"

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
    echo "$@" >> "$LOG_FILE"
}

# Function to print section headers
print_section() {
    echo
    print_color "$CYAN" "════════════════════════════════════════════════════════════════"
    print_color "$CYAN" "  $1"
    print_color "$CYAN" "════════════════════════════════════════════════════════════════"
    echo
}

# Function to print checkpoints
checkpoint() {
    CHECKPOINT_COUNT=$((CHECKPOINT_COUNT + 1))
    echo
    print_color "$YELLOW" "┌─────────────────────────────────────────────────────────────┐"
    print_color "$YELLOW" "│  CHECKPOINT #$CHECKPOINT_COUNT: $1"
    print_color "$YELLOW" "└─────────────────────────────────────────────────────────────┘"
    echo
    print_color "$MAGENTA" "Please review the above installations and outputs."
    echo -n -e "${BOLD}Continue with next section? (y/n/q to quit): ${NC}"
    read -r response
    case $response in
        [yY]) 
            print_color "$GREEN" "✓ Continuing..."
            return 0
            ;;
        [qQ])
            print_color "$RED" "✗ Setup cancelled by user"
            exit 0
            ;;
        *)
            print_color "$RED" "✗ Skipping next section"
            return 1
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to verify installation
verify_install() {
    local cmd=$1
    local name=$2
    if command_exists "$cmd"; then
        print_color "$GREEN" "✓ $name is installed"
        return 0
    else
        print_color "$RED" "✗ $name is NOT installed"
        return 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --dry-run    Preview what will be installed without making changes"
            echo "  --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Start setup
clear
print_color "$CYAN" "╔══════════════════════════════════════════════════════════════╗"
print_color "$CYAN" "║          Health Genie Development Environment Setup          ║"
print_color "$CYAN" "╚══════════════════════════════════════════════════════════════╝"
echo
print_color "$BLUE" "This script will install and configure all required tools for"
print_color "$BLUE" "Health Genie development. You'll have checkpoints to review"
print_color "$BLUE" "progress and confirm before proceeding to each next step."
echo
print_color "$YELLOW" "Log file: $LOG_FILE"

if [ "$DRY_RUN" = true ]; then
    print_color "$MAGENTA" "🔍 DRY RUN MODE - No actual installations will be performed"
fi

echo
echo -n -e "${BOLD}Ready to begin? (y/n): ${NC}"
read -r response
if [[ ! "$response" =~ ^[yY]$ ]]; then
    print_color "$RED" "Setup cancelled"
    exit 0
fi

# ============================================================================
# SECTION 1: Verify Prerequisites
# ============================================================================
print_section "1. VERIFYING PREREQUISITES"

print_color "$BLUE" "Checking required tools..."
echo

# Check Xcode
if command_exists xcode-select; then
    XCODE_PATH=$(xcode-select -p 2>/dev/null)
    if [ -n "$XCODE_PATH" ]; then
        print_color "$GREEN" "✓ Xcode Command Line Tools: $XCODE_PATH"
    else
        print_color "$RED" "✗ Xcode Command Line Tools not configured"
        print_color "$YELLOW" "  Run: xcode-select --install"
    fi
else
    print_color "$RED" "✗ Xcode not found"
fi

# Check Flutter
if command_exists flutter; then
    FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n 1)
    print_color "$GREEN" "✓ Flutter: $FLUTTER_VERSION"
else
    print_color "$RED" "✗ Flutter not found"
    print_color "$YELLOW" "  Install from: https://flutter.dev/docs/get-started/install"
fi

# Check Git
if command_exists git; then
    GIT_VERSION=$(git --version)
    print_color "$GREEN" "✓ Git: $GIT_VERSION"
else
    print_color "$RED" "✗ Git not found"
fi

# Check Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version)
    print_color "$GREEN" "✓ Python: $PYTHON_VERSION"
else
    print_color "$RED" "✗ Python 3 not found"
fi

checkpoint "Prerequisites Check Complete"

# ============================================================================
# SECTION 2: Install Homebrew (if needed)
# ============================================================================
print_section "2. HOMEBREW PACKAGE MANAGER"

if command_exists brew; then
    print_color "$GREEN" "✓ Homebrew is already installed"
    BREW_VERSION=$(brew --version | head -n 1)
    print_color "$BLUE" "  Version: $BREW_VERSION"
else
    print_color "$YELLOW" "Homebrew is not installed"
    echo -n -e "${BOLD}Install Homebrew? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            print_color "$BLUE" "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            print_color "$MAGENTA" "[DRY RUN] Would install Homebrew"
        fi
    fi
fi

checkpoint "Homebrew Setup Complete"

# ============================================================================
# SECTION 3: Install CocoaPods
# ============================================================================
print_section "3. COCOAPODS (iOS Dependency Manager)"

if command_exists pod; then
    POD_VERSION=$(pod --version 2>/dev/null)
    print_color "$GREEN" "✓ CocoaPods is already installed: $POD_VERSION"
else
    print_color "$YELLOW" "CocoaPods is not installed (required for Flutter iOS builds)"
    echo -n -e "${BOLD}Install CocoaPods? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            print_color "$BLUE" "Installing CocoaPods..."
            sudo gem install cocoapods
            pod setup
        else
            print_color "$MAGENTA" "[DRY RUN] Would install CocoaPods"
        fi
    fi
fi

checkpoint "CocoaPods Setup Complete"

# ============================================================================
# SECTION 4: Install Command Line Tools
# ============================================================================
print_section "4. COMMAND LINE TOOLS"

print_color "$BLUE" "Checking optional but helpful tools..."
echo

# Watchman (file watching)
if command_exists watchman; then
    print_color "$GREEN" "✓ Watchman is already installed"
else
    print_color "$YELLOW" "Watchman not found (helps with file watching)"
    echo -n -e "${BOLD}Install Watchman? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            brew install watchman
        else
            print_color "$MAGENTA" "[DRY RUN] Would install Watchman"
        fi
    fi
fi

# PostgreSQL (for local Supabase testing)
if command_exists psql; then
    print_color "$GREEN" "✓ PostgreSQL is already installed"
else
    print_color "$YELLOW" "PostgreSQL not found (optional for local Supabase testing)"
    echo -n -e "${BOLD}Install PostgreSQL? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            brew install postgresql
        else
            print_color "$MAGENTA" "[DRY RUN] Would install PostgreSQL"
        fi
    fi
fi

checkpoint "Command Line Tools Complete"

# ============================================================================
# SECTION 5: Python Environment Setup
# ============================================================================
print_section "5. PYTHON ENVIRONMENT SETUP"

print_color "$BLUE" "Setting up Python packages for backend development..."
echo

# Check if virtual environment exists
if [ -d "${PROJECT_DIR}/venv" ]; then
    print_color "$GREEN" "✓ Virtual environment found at ${PROJECT_DIR}/venv"
else
    print_color "$YELLOW" "Virtual environment not found"
    echo -n -e "${BOLD}Create virtual environment? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            python3 -m venv "${PROJECT_DIR}/venv"
            print_color "$GREEN" "✓ Created virtual environment"
        else
            print_color "$MAGENTA" "[DRY RUN] Would create virtual environment"
        fi
    fi
fi

# Create requirements.txt
print_color "$BLUE" "Creating Python requirements.txt..."
if [ "$DRY_RUN" = false ]; then
    cat > "${PROJECT_DIR}/requirements.txt" << 'EOF'
# Health Genie Backend Requirements

# Web Framework
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-multipart==0.0.6

# AI and LLM
langgraph==0.0.32
langchain==0.1.0
langchain-anthropic==0.1.1
anthropic==0.17.0

# Database
supabase==2.3.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9

# Utilities
python-dotenv==1.0.0
pydantic==2.5.0
httpx==0.25.2
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# Development & Testing
pytest==7.4.3
pytest-asyncio==0.21.1
black==23.11.0
pylint==3.0.3
mypy==1.7.1

# Data Processing
pandas==2.1.4
numpy==1.26.2
scipy==1.11.4

# Monitoring & Logging
loguru==0.7.2
EOF
    print_color "$GREEN" "✓ Created requirements.txt"
else
    print_color "$MAGENTA" "[DRY RUN] Would create requirements.txt"
fi

# Install Python packages
echo -n -e "${BOLD}Install Python packages now? (y/n): ${NC}"
read -r response
if [[ "$response" =~ ^[yY]$ ]]; then
    if [ "$DRY_RUN" = false ]; then
        print_color "$BLUE" "Activating virtual environment and installing packages..."
        source "${PROJECT_DIR}/venv/bin/activate"
        pip install --upgrade pip
        pip install -r "${PROJECT_DIR}/requirements.txt"
        print_color "$GREEN" "✓ Python packages installed"
    else
        print_color "$MAGENTA" "[DRY RUN] Would install Python packages from requirements.txt"
    fi
fi

checkpoint "Python Environment Setup Complete"

# ============================================================================
# SECTION 6: Flutter Project Setup
# ============================================================================
print_section "6. FLUTTER PROJECT INITIALIZATION"

print_color "$BLUE" "Preparing Flutter project structure..."
echo

# Check if flutter_app directory exists
if [ -d "${PROJECT_DIR}/flutter_app" ]; then
    print_color "$YELLOW" "Flutter app directory already exists"
else
    echo -n -e "${BOLD}Create Flutter app structure? (y/n): ${NC}"
    read -r response
    if [[ "$response" =~ ^[yY]$ ]]; then
        if [ "$DRY_RUN" = false ]; then
            print_color "$BLUE" "Creating Flutter app..."
            cd "$PROJECT_DIR"
            flutter create --org com.healthgenie --project-name health_genie flutter_app
            print_color "$GREEN" "✓ Flutter app created"
        else
            print_color "$MAGENTA" "[DRY RUN] Would create Flutter app structure"
        fi
    fi
fi

# Create/Update pubspec.yaml with required packages
if [ -f "${SCRIPT_DIR}/flutter_app/pubspec.yaml" ] && [ "$DRY_RUN" = false ]; then
    print_color "$BLUE" "Adding required Flutter packages to pubspec.yaml..."
    
    # Create a temporary file with the dependencies to add
    cat > "${SCRIPT_DIR}/flutter_app/pubspec_additions.txt" << 'EOF'

  # HealthKit Integration
  health: ^9.0.0
  
  # State Management
  provider: ^6.1.1
  
  # Local Database
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1
  
  # Cloud Database
  supabase_flutter: ^2.0.0
  
  # Data Visualization
  fl_chart: ^0.65.0
  
  # Networking
  http: ^1.1.0
  dio: ^5.4.0
  
  # Utilities
  intl: ^0.18.1
  uuid: ^4.2.1
  shared_preferences: ^2.2.2
  
  # UI Components
  flutter_spinkit: ^5.2.0
  shimmer: ^3.0.0
  
  # Permissions
  permission_handler: ^11.1.0
EOF
    
    print_color "$YELLOW" "Note: You'll need to manually add the dependencies from pubspec_additions.txt to pubspec.yaml"
    print_color "$YELLOW" "Then run: cd flutter_app && flutter pub get"
else
    print_color "$MAGENTA" "[DRY RUN] Would update pubspec.yaml with required packages"
fi

checkpoint "Flutter Project Setup Complete"

# ============================================================================
# SECTION 7: Configuration Templates
# ============================================================================
print_section "7. CONFIGURATION TEMPLATES"

print_color "$BLUE" "Creating configuration template files..."
echo

# Create config_templates directory
mkdir -p "${SCRIPT_DIR}/config_templates"

# Create .env.template
if [ "$DRY_RUN" = false ]; then
    cat > "${SCRIPT_DIR}/config_templates/.env.template" << 'EOF'
# Health Genie Environment Variables
# Copy this file to .env and fill in your actual values

# Anthropic API (Claude)
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_KEY=your_supabase_service_key_here

# Backend API
API_BASE_URL=http://localhost:8000
API_VERSION=v1

# Apple HealthKit (no API key needed, but for reference)
HEALTHKIT_ENABLED=true

# Development Settings
DEBUG=true
LOG_LEVEL=INFO

# Database
DATABASE_URL=postgresql://user:password@localhost/healthgenie

# Security
JWT_SECRET_KEY=your_jwt_secret_key_here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF
    print_color "$GREEN" "✓ Created .env.template"
else
    print_color "$MAGENTA" "[DRY RUN] Would create .env.template"
fi

# Create .gitignore if it doesn't exist
if [ ! -f "${PROJECT_DIR}/.gitignore" ] && [ "$DRY_RUN" = false ]; then
    cat > "${PROJECT_DIR}/.gitignore" << 'EOF'
# Environment variables
.env
.env.local
*.env

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
ENV/

# Flutter/Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
flutter_app/ios/Pods/
flutter_app/ios/.symlinks/
flutter_app/ios/Flutter/Flutter.framework
flutter_app/ios/Flutter/Flutter.podspec
flutter_app/ios/Flutter/Generated.xcconfig
flutter_app/ios/Flutter/app.flx
flutter_app/ios/Flutter/app.zip
flutter_app/ios/Flutter/flutter_assets/
flutter_app/ios/Flutter/flutter_export_environment.sh
flutter_app/ios/ServiceDefinitions.json
flutter_app/ios/Runner/GeneratedPluginRegistrant.*

# Android
*.iml
*.ipr
*.iws
.gradle/
flutter_app/android/local.properties
flutter_app/android/.gradle/
flutter_app/android/captures/
flutter_app/android/gradlew
flutter_app/android/gradlew.bat

# IDE
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store

# Logs
*.log
setup_logs/

# Testing
coverage/
*.lcov
.coverage

# Temporary files
tmp/
temp/
EOF
    print_color "$GREEN" "✓ Created .gitignore"
else
    print_color "$MAGENTA" "[DRY RUN] Would create .gitignore"
fi

checkpoint "Configuration Templates Complete"

# ============================================================================
# SECTION 8: Backend Structure
# ============================================================================
print_section "8. BACKEND PROJECT STRUCTURE"

print_color "$BLUE" "Creating backend directory structure..."
echo

if [ "$DRY_RUN" = false ]; then
    # Create backend directories
    mkdir -p "${SCRIPT_DIR}/backend/api/endpoints"
    mkdir -p "${SCRIPT_DIR}/backend/api/models"
    mkdir -p "${SCRIPT_DIR}/backend/api/services"
    mkdir -p "${SCRIPT_DIR}/backend/langgraph/agents"
    mkdir -p "${SCRIPT_DIR}/backend/langgraph/workflows"
    mkdir -p "${SCRIPT_DIR}/backend/tests"
    mkdir -p "${SCRIPT_DIR}/backend/data"
    
    # Create basic __init__.py files
    touch "${SCRIPT_DIR}/backend/__init__.py"
    touch "${SCRIPT_DIR}/backend/api/__init__.py"
    touch "${SCRIPT_DIR}/backend/api/endpoints/__init__.py"
    touch "${SCRIPT_DIR}/backend/api/models/__init__.py"
    touch "${SCRIPT_DIR}/backend/api/services/__init__.py"
    touch "${SCRIPT_DIR}/backend/langgraph/__init__.py"
    touch "${SCRIPT_DIR}/backend/langgraph/agents/__init__.py"
    touch "${SCRIPT_DIR}/backend/langgraph/workflows/__init__.py"
    
    print_color "$GREEN" "✓ Created backend directory structure"
    
    # Show the structure
    print_color "$CYAN" "Backend structure:"
    tree -L 3 "${PROJECT_DIR}/backend" 2>/dev/null || ls -la "${PROJECT_DIR}/backend"
else
    print_color "$MAGENTA" "[DRY RUN] Would create backend directory structure"
fi

checkpoint "Backend Structure Complete"

# ============================================================================
# SECTION 9: Manual Installation Instructions
# ============================================================================
print_section "9. MANUAL INSTALLATIONS REQUIRED"

print_color "$YELLOW" "The following applications need to be installed manually:"
echo

print_color "$BLUE" "Design Tools:"
print_color "$WHITE" "  • Figma Desktop"
print_color "$CYAN" "    Download from: https://www.figma.com/downloads/"
print_color "$WHITE" "    After installation, add the Token Studio plugin from within Figma"
echo

print_color "$BLUE" "API Testing Tools (choose one):"
print_color "$WHITE" "  • Postman"
print_color "$CYAN" "    Download from: https://www.postman.com/downloads/"
print_color "$WHITE" "  • Insomnia"
print_color "$CYAN" "    Download from: https://insomnia.rest/download"
echo

print_color "$BLUE" "Database Tools:"
print_color "$WHITE" "  • DB Browser for SQLite"
print_color "$CYAN" "    Download from: https://sqlitebrowser.org/"
echo

print_color "$BLUE" "iOS Testing:"
print_color "$WHITE" "  • TestFlight"
print_color "$CYAN" "    Install from the App Store on your iPhone"
echo

print_color "$BLUE" "Required Accounts:"
print_color "$WHITE" "  • Apple Developer Account ($99/year)"
print_color "$CYAN" "    Sign up at: https://developer.apple.com/programs/"
print_color "$WHITE" "  • Supabase Account (free tier available)"
print_color "$CYAN" "    Sign up at: https://supabase.com/"
print_color "$WHITE" "  • Anthropic API Account (for Claude)"
print_color "$CYAN" "    Sign up at: https://console.anthropic.com/"

checkpoint "Manual Installation Instructions Reviewed"

# ============================================================================
# SECTION 10: Flutter Doctor & Final Verification
# ============================================================================
print_section "10. FINAL VERIFICATION"

print_color "$BLUE" "Running Flutter Doctor to verify setup..."
echo

if command_exists flutter && [ "$DRY_RUN" = false ]; then
    flutter doctor -v
else
    print_color "$MAGENTA" "[DRY RUN] Would run flutter doctor"
fi

echo
print_color "$BLUE" "Checking Python packages..."
if [ "$DRY_RUN" = false ]; then
    source "${PROJECT_DIR}/venv/bin/activate"
    pip list | grep -E "fastapi|langgraph|anthropic|supabase" || print_color "$YELLOW" "Some Python packages may not be installed"
else
    print_color "$MAGENTA" "[DRY RUN] Would check Python packages"
fi

# ============================================================================
# Setup Complete
# ============================================================================
print_section "SETUP COMPLETE!"

print_color "$GREEN" "✅ Health Genie development environment setup is complete!"
echo
print_color "$CYAN" "Next Steps:"
print_color "$WHITE" "1. Copy config_templates/.env.template to .env and add your API keys"
print_color "$WHITE" "2. Install the manual applications listed above"
print_color "$WHITE" "3. Configure your iPhone and Apple Watch for development"
print_color "$WHITE" "4. Run 'flutter doctor' to ensure everything is properly configured"
print_color "$WHITE" "5. Start developing the Health Genie app!"
echo
print_color "$YELLOW" "Setup log saved to: $LOG_FILE"
echo
print_color "$CYAN" "To start developing:"
print_color "$WHITE" "  Backend:  source venv/bin/activate && cd backend"
print_color "$WHITE" "  Flutter:  cd flutter_app && flutter run"
echo
print_color "$GREEN" "Good luck with your Health Genie project! 🚀"