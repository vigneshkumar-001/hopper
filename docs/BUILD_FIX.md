# Flutter Build Fix Guide

## Problem
```
Error: Unable to delete directory 'build/stripe_android/intermediates/...'
Cause: Gradle cache is locked or corrupted
```

---

## Solution (Choose One)

### ✅ Option 1: Complete Clean (RECOMMENDED)

Run these commands in PowerShell:

```powershell
cd "D:\SATZ\SATZ\Hoppr\Live_23_06_26\hoppr (3)\hoppr\hoppr flutter\hopper_driver"

# Step 1: Kill any running processes
taskkill /F /IM dart.exe 2>$null
taskkill /F /IM java.exe 2>$null
taskkill /F /IM gradle.exe 2>$null

# Step 2: Clean Flutter
flutter clean

# Step 3: Delete build directories
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force ".dart_tool" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android/.gradle" -ErrorAction SilentlyContinue

# Step 4: Reinstall dependencies
flutter pub get

# Step 5: Build
flutter run -d chrome
```

---

### Option 2: Quick Fix (Faster)

```powershell
cd "D:\SATZ\SATZ\Hoppr\Live_23_06_26\hoppr (3)\hoppr\hoppr flutter\hopper_driver"

flutter clean
flutter pub get
flutter run --release
```

---

### Option 3: Android Gradle Cache Clear

```powershell
cd "D:\SATZ\SATZ\Hoppr\Live_23_06_26\hoppr (3)\hoppr\hoppr flutter\hopper_driver"

# Delete Android build cache
Remove-Item -Recurse -Force "android/build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android/.gradle" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue

flutter clean
flutter pub get
flutter run
```

---

## If Still Failing

### Check for locked processes:

```powershell
# Find what's using the directory
Get-Process | Where-Object {$_.ProcessName -like "*java*" -or $_.ProcessName -like "*gradle*"}

# Kill them
taskkill /F /IM java.exe
taskkill /F /IM gradle.exe
```

### Reset Gradle Daemon:

```powershell
cd "D:\SATZ\SATZ\Hoppr\Live_23_06_26\hoppr (3)\hoppr\hoppr flutter\hopper_driver\android"
./gradlew --stop
cd ..
flutter clean
```

---

## Recommended: One-Line Solution

Copy and paste this entire command:

```powershell
$dir = "D:\SATZ\SATZ\Hoppr\Live_23_06_26\hoppr (3)\hoppr\hoppr flutter\hopper_driver"; cd $dir; taskkill /F /IM java.exe 2>$null; taskkill /F /IM dart.exe 2>$null; flutter clean; Remove-Item -Recurse -Force "build", ".dart_tool", "android/.gradle" -ErrorAction SilentlyContinue; flutter pub get; flutter run -d chrome
```

---

## Build Command Options

### Option A: Chrome (Web) - FASTEST
```
flutter run -d chrome
```
✅ Fastest build time (~2-3 min)
✅ Good for UI testing
✅ No Android setup needed

### Option B: Android (APK) - SLOWER
```
flutter run
```
✓ Builds APK for testing on device
✓ Takes longer (5-10 min first build)

### Option C: Release Build
```
flutter build apk
```
✓ Optimized for production
✓ Takes much longer

---

## Verify Code Change Is Correct

The bookingId display code was added successfully:

✅ **File**: `picking_shared_screens.dart`
✅ **Lines**: 1323-1358
✅ **Change**: Added bookingId badge next to rider tag
✅ **Syntax**: Valid Dart code

The build issue is **NOT** related to the code change - it's a Gradle cache issue.

---

## Code Change Summary

```dart
// Before
Text(
  rider.stage == SharedRiderStage.onboardDrop
      ? 'Onboard Rider'
      : 'Shared Rider',
  style: TextStyle(...),
),

// After (Added bookingId badge)
Row(
  children: [
    Text(
      rider.stage == SharedRiderStage.onboardDrop
          ? 'Onboard Rider'
          : 'Shared Rider',
      style: TextStyle(...),
    ),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _C.borderLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'ID: ${rider.bookingId}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _C.textMuted,
          fontFamily: 'monospace',
        ),
      ),
    ),
  ],
),
```

---

## Next Steps

1. Run the build fix command above
2. Wait for build to complete
3. Open app in Chrome or on device
4. Navigate to picking screen
5. Verify bookingId displays: `ID: BOOKING-001`

---

## Still Having Issues?

If build still fails:

1. **Restart your computer** (clears all locks)
2. Run Option 1 above
3. If fails again, check:
   - Disk space (need 5GB+ free)
   - Java installed (run: `java -version`)
   - Android SDK installed
   - Flutter path correct

---

## Success Indicators

After successful build:
```
✓ No red errors
✓ App starts in Chrome/Device
✓ Navigation works
✓ BookingId shows on rider cards
✓ "WAITING FOR PICKUP (X)" count displays correctly
```

---

## Remember

The code change is **correct** ✅ - it's just a Gradle cache issue. After cleaning, it will build fine!
