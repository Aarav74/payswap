// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
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
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProxyProvider<AuthService, ApiService>(
          create: (context) => ApiService(authService: context.read<AuthService>()),
          update: (context, authService, apiService) => ApiService(authService: authService),
        ),
        ChangeNotifierProxyProvider<AuthService, WebSocketService>(
          create: (context) => WebSocketService(authService: context.read<AuthService>()),
          update: (context, authService, webSocketService) => WebSocketService(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'Cash Exchange',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            if (authService.isLoading) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            // Remove const keywords since constructors are not const
            return authService.currentUser != null ? HomeScreen() : AuthScreen();
          },
        ),
      ),
    );
  }
}