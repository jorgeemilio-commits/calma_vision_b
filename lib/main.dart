import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart'; // Asegúrate de tenerlo en tu pubspec.yaml
import 'pantallas/pantalla_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://ushocogyfyntcsluaejs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzaG9jb2d5ZnludGNzbHVhZWpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NDMwNTMsImV4cCI6MjA5MjExOTA1M30.QW6gpetoVBN7rzWpxGqOPJMlYtxB9TK75lzOaziwdTU', // Recuerda poner tu llave real
  );

  runApp(const CalmaVisionB());
}

class CalmaVisionB extends StatelessWidget {
  const CalmaVisionB({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calma Vision - Familia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Colores suaves inspirados en Calma Vision A
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2), // Azul calmante
          background: const Color(0xFFF5F7FA), // Fondo gris muy claro
        ),
        useMaterial3: true,
        // Usamos Roboto para mantener la identidad de marca
        textTheme: GoogleFonts.robotoTextTheme(), 
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 2,
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
          ),
        ),
      ),
      home: const PantallaLogin(),
    );
  }
}