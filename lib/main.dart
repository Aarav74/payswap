// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'services/request_polling_service.dart'; 
import 'config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Env.load();
  
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
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
        ChangeNotifierProxyProvider<AuthService, ApiService>(
          create: (context) => ApiService(authService: context.read<AuthService>()),
          update: (context, authService, previous) => previous ?? ApiService(authService: authService),
        ),
        // Replace WebSocketService with RequestPollingService
        ChangeNotifierProxyProvider<AuthService, RequestPollingService>(
          create: (context) => RequestPollingService(authService: context.read<AuthService>()),
          update: (context, authService, pollingService) => RequestPollingService(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'Cash Exchange',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true, // Enable Material 3 for better UI
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            if (authService.isLoading) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return authService.currentUser != null ? HomeScreen() : AuthScreen();
          },
        ),
      ),
    );
  }
}