@echo off
echo ===== Corrigindo problemas que impedem o APK de carregar =====

echo 1. Limpando o projeto (ignorando erros)
flutter clean

echo 2. Obtendo dependências
flutter pub get

echo 3. Corrigindo problemas de compilação
echo 3.1. Removendo arquivos temporários que podem causar conflitos
if exist boxes_screen_temp.dart del boxes_screen_temp.dart
if exist temp_fix.dart del temp_fix.dart

echo 4. Compilando APK com configurações otimizadas
flutter build apk --release --target-platform android-arm,android-arm64 --split-per-abi

echo ===== Processo concluído! =====
echo Os APKs corrigidos estão disponíveis em:
echo build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
echo build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo.
