import 'package:flutter/material.dart';
import 'package:boxmagic/screens/etiquetas_screen.dart';

void main() {
  runApp(const TestEtiquetasApp());
}

class TestEtiquetasApp extends StatelessWidget {
  const TestEtiquetasApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teste de Etiquetas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const EtiquetasScreen(),
    );
  }
}
