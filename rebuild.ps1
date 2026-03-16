# Flutter Complete Rebuild Script
# This script performs a complete clean rebuild of the Flutter app

Write-Host "Starting complete Flutter rebuild..." -ForegroundColor Green

# Stop any running Flutter processes
Write-Host "`nStopping Flutter processes..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "`nGetting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

# Build APK (debug)
Write-Host "`nBuilding debug APK..." -ForegroundColor Yellow
flutter build apk --debug

Write-Host "`n✅ Rebuild complete! Now run: flutter run" -ForegroundColor Green
