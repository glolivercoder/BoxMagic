@echo off
echo ===== Compilando APK de Debug do BoxMagic =====

echo 1. Obtendo dependências (sem limpar o projeto)
flutter pub get

echo 2. Compilando APK de debug (mais tolerante a erros)
flutter build apk --debug

echo ===== Processo concluído! =====
echo O APK de debug está disponível em:
echo build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Para instalar no seu dispositivo, conecte-o via USB e execute:
echo flutter install --debug
echo.
