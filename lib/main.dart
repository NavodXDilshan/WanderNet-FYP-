import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/dbHelper/mongodb.dart';
import 'package:app/pages/feed.dart';
import 'package:app/pages/home.dart';
import 'package:app/pages/market.dart';
import 'package:app/pages/planner.dart';
import 'package:app/pages/weather.dart';
import 'package:app/pages/signin.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://xvzwffdkquawwjacoyfq.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh2endmZmRrcXVhd3dqYWNveWZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMwMDg3NDQsImV4cCI6MjA2ODU4NDc0NH0.JBKpNdRzojaia7_cvGvAZAmONiuQaI4kKHvW7b8m28k',
  );
  await MongoDataBase.connect();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _secureStorage = const FlutterSecureStorage();

  Future<bool> _checkAuthState() async {
    final sessionString = await _secureStorage.read(key: 'supabase_session');
    if (sessionString != null) {
      try {
        final sessionData = jsonDecode(sessionString);
        final response = await Supabase.instance.client.auth.recoverSession(sessionData);
        return response.session != null;
      } catch (e) {
        print('Error recovering session: $e');
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true ? const MainScreen() : const SignInScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _secureStorage = const FlutterSecureStorage();

  static List<Widget> _pages = [
    Homepage(),
    const Market(),
    const Feed(),
    const WeatherScreen(),
    const Planner(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    await _secureStorage.delete(key: 'supabase_session');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud),
            label: 'Weather',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  
}