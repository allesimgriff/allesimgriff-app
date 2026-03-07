import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/startseite.dart';

// --- Konfiguration ---
const supabaseUrl = 'https://quptrocxksdqkvcfgzvc.supabase.co';
// ✅ Dein Key (anon/public):
const supabaseKey = 'sb_publishable_eR8hYowZBrevF0ywKwQLzA_d5xUmOlH';
const myposterAffiliateLink = 'https://www.myposter.de';

// --- Main Entry ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const FamilienTagebuchApp());
}

// --- App Widget ---
class FamilienTagebuchApp extends StatelessWidget {
  const FamilienTagebuchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Familien Tagebuch',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const Startseite(),
      debugShowCheckedModeBanner: false,
    );
  }
}
