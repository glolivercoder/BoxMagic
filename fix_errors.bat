@echo off
echo Corrigindo erros do Flutter Analyzer...

echo 1. Corrigindo boxes_screen_temp.dart
powershell -Command "(Get-Content boxes_screen_temp.dart) -replace \"content: Text\('\$\{selectedBoxes.length\} etiquetas enviadas para impressão'\),\", \"content: Text('\${boxes.length} etiquetas enviadas para impressão'),\" | Set-Content boxes_screen_temp.dart"

echo 2. Substituindo temp_fix.dart
copy /Y temp_fix_fixed.dart temp_fix.dart

echo 3. Removendo arquivos temporários de correção
del boxes_screen_temp_fixed.dart
del temp_fix_corrected.dart

echo 4. Executando flutter analyze novamente para verificar correções
flutter analyze

echo Correções aplicadas! Agora você pode criar o APK com:
echo flutter build apk --release
