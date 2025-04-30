import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100, // Aumentado para acomodar melhor o logo
        leading: Padding(
          padding: const EdgeInsets.all(8.0), // Adicionado padding
          child: Image.asset(
            'Fotos de icones/magicbox_mascot .png',
            fit: BoxFit.contain,
            height: 84,
            width: 84,
          ),
        ),
        title: const Text(
          'MagicBox',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '0',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}