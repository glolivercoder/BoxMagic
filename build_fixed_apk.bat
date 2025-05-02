@echo off
echo ===== Compilando APK corrigido do BoxMagic =====

echo 1. Limpando o projeto
flutter clean

echo 2. Obtendo dependências
flutter pub get

echo 3. Compilando APKs separados por arquitetura (mais leves e otimizados)
flutter build apk --release --target-platform android-arm,android-arm64 --split-per-abi

echo ===== Processo concluído! =====
echo Os APKs corrigidos estão disponíveis em:
echo build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk (para a maioria dos dispositivos)
echo build\app\outputs\flutter-apk\app-arm64-v8a-release.apk (para dispositivos mais recentes)
echo.
echo Para instalar no seu dispositivo, conecte-o via USB e execute:
echo flutter install
echo.
