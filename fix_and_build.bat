@echo off
echo ===== Corrigindo problemas e compilando APK do BoxMagic =====

echo 1. Removendo arquivos temporários que podem causar conflitos
if exist boxes_screen_temp.dart del boxes_screen_temp.dart
if exist temp_fix.dart del temp_fix.dart

echo 2. Limpando o projeto
flutter clean

echo 3. Obtendo dependências
flutter pub get

echo 4. Compilando APK com configurações seguras
flutter build apk --debug

echo ===== Processo concluído! =====
echo O APK de debug está disponível em:
echo build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Para instalar no seu dispositivo, conecte-o via USB e execute:
echo flutter install --debug
echo.
