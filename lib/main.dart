// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Env.load();
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    debug: true, 
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ProxyProvider<AuthService, ApiService>(
          update: (_, authService, _) => ApiService(authService: authService),
        ),
      ],
      builder: (context, child) {
        final authService = Provider.of<AuthService>(context);
        
        return MaterialApp(
          title: 'Cash Exchange',
          navigatorKey: navigatorKey,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: authService.isLoading
              ? Scaffold(body: Center(child: CircularProgressIndicator()))
              : authService.currentUser != null
                  ? HomeScreen()
                  : AuthScreen(),
        );
      },
    );
  }
}