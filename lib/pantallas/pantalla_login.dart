import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_seleccion_terminal.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  bool _esRegistro = false;
  bool _cargando = false;

  Future<void> _autenticar() async {
    setState(() => _cargando = true);
    try {
      if (_esRegistro) {
        // REGISTRO SEGURO EN SUPABASE
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        
        if (response.user != null) {
          // AHORA GUARDAMOS EN LA NUEVA TABLA 'CUIDADORES'
          await Supabase.instance.client.from('cuidadores').insert({
            'id': response.user!.id,
            'nombre': _nombreController.text.trim(),
          });
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaSeleccionTerminal()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_rounded, size: 70, color: Color(0xFF4A90E2)),
                const SizedBox(height: 15),
                const Text("CALMA VISION", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Color(0xFF2C3E50))),
                const Text("Portal para Familiares", style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                const SizedBox(height: 50),
                
                if (_esRegistro) ...[
                  TextField(controller: _nombreController, decoration: const InputDecoration(labelText: "Tu Nombre Completo", prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 15),
                ],
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Correo Electrónico", prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 15),
                TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 35),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A90E2)),
                  onPressed: _cargando ? null : _autenticar,
                  child: _cargando ? const CircularProgressIndicator(color: Colors.white) : Text(_esRegistro ? "Crear Cuenta" : "Entrar", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => setState(() => _esRegistro = !_esRegistro), 
                  child: Text(_esRegistro ? "Ya tengo cuenta. Iniciar sesión" : "No tengo cuenta. Registrarme", style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 16, fontWeight: FontWeight.bold))
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}