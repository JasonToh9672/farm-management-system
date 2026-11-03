@echo off
echo Building APK...
cd android
call gradlew assembleDebug
cd ..
echo Installing APK...
C:\Users\user\AppData\Local\Android\sdk\platform-tools\adb.exe install -r android\app\build\outputs\apk\debug\app-debug.apk
echo Done!
