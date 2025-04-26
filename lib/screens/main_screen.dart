import 'package:flutter/material.dart';
import 'package:boxmagic/screens/boxes_screen.dart';
import 'package:boxmagic/screens/items_screen.dart';
import 'package:boxmagic/screens/users_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const BoxesScreen(),
    const ItemsScreen(),
    const UsersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Caixas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Objetos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Usuários',
          ),
        ],
      ),
    );
  }
}
