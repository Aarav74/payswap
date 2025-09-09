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
        ChangeNotifierProxyProvider<AuthService, RequestPollingService>(
          create: (context) => RequestPollingService(authService: context.read<AuthService>()),
          update: (context, authService, previous) => previous ?? RequestPollingService(authService: authService),
        ),
      ],
      child: MaterialApp(
        title: 'PaySwap',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          // Use copyWith to modify the default card theme instead
          cardTheme: ThemeData.light().cardTheme.copyWith(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.symmetric(vertical: 8),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            if (authService.isLoading) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Loading PaySwap...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
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