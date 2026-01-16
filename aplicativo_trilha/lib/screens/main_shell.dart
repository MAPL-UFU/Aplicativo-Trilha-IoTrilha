// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:aplicativo_trilha/screens/guide_screen.dart';
import 'package:aplicativo_trilha/screens/operator_screen.dart';
import 'package:aplicativo_trilha/screens/live_trail_screen.dart';

enum UserProfile { trilheiro, guia, operador }

class MainShell extends StatefulWidget {
  final UserProfile profile;

  const MainShell({super.key, required this.profile});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late List<Widget> _screens;
  late List<BottomNavigationBarItem>? _navItems;

  @override
  void initState() {
    super.initState();

    switch (widget.profile) {
      case UserProfile.trilheiro:
        _screens = [const LiveTrailScreen()];
        _navItems = null;
        break;

      case UserProfile.guia:
        _screens = [const GuideScreen()];
        _navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Painel Guia',
          ),
        ];
        break;

      case UserProfile.operador:
        _screens = [const OperatorScreen()];
        _navItems = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ];
        break;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: (_navItems == null || _navItems!.length < 2)
          ? null
          : BottomNavigationBar(
              items: _navItems!,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
    );
  }
}
