// config/env.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl {
    return dotenv.get('SUPABASE_URL', fallback: '');
  }

  static String get supabaseAnonKey {
    return dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  }

  static String get graphhopperApiKey {
    return dotenv.get('GRAPHHOPPER_API_KEY', fallback: '');
  }

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }
}