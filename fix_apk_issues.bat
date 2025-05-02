@echo off
echo ===== Corrigindo problemas que impedem o APK de carregar =====

echo 1. Copiando arquivo database_helper corrigido
copy /Y lib\services\database_helper_fixed.dart lib\services\database_helper.dart

echo 2. Limpando o projeto
flutter clean

echo 3. Obtendo dependências
flutter pub get

echo 4. Verificando erros
flutter analyze

echo 5. Compilando APK
flutter build apk --release

echo ===== Processo concluído! =====
echo O APK corrigido está disponível em: build\app\outputs\flutter-apk\app-release.apk
echo.
