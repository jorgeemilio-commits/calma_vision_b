import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_seleccion_terminal.dart';
import 'pantalla_completar_perfil.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  bool _esRegistro = false;
  bool _cargando = false;
  bool _ocultarPass = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      if (_esRegistro) {
        // 1. SOLO CREAMOS EL USUARIO EN AUTH
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (res.user != null && mounted) {
          // El usuario ya existe en Auth, lo mandamos a completar su perfil
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PantallaCompletarPerfil()),
          );
        }
      } else {
        // 2. INICIO DE SESIÓN NORMAL
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          // Nota: Aquí podrías verificar si su perfil existe, pero por ahora lo mandamos a la app
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PantallaSeleccionTerminal()),
          );
        }
      }
    } on AuthException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      _mostrarError("Error inesperado: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    const colorPrimario = Color(0xFF4A90E2);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _esRegistro ? "Crear Cuenta" : "Acceso Familiar",
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorPrimario),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _esRegistro ? "Registra tu correo para empezar" : "Bienvenido de vuelta",
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  _campo(
                    controller: _emailController, 
                    label: "Correo Electrónico", 
                    icon: Icons.email_outlined, 
                    type: TextInputType.emailAddress,
                    validator: (val) => val!.isEmpty || !val.contains('@') ? "Ingresa un correo válido" : null
                  ),
                  const SizedBox(height: 15),
                  
                  _campo(
                    controller: _passwordController, 
                    label: "Contraseña", 
                    icon: Icons.lock_outline, 
                    obscure: _ocultarPass, 
                    suffix: IconButton(
                      icon: Icon(_ocultarPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey), 
                      onPressed: () => setState(() => _ocultarPass = !_ocultarPass)
                    ),
                    validator: (val) => val!.length < 6 ? "Mínimo 6 caracteres" : null
                  ),
                  
                  if (_esRegistro) ...[
                    const SizedBox(height: 15),
                    _campo(
                      controller: _confirmarPasswordController, 
                      label: "Confirmar Contraseña", 
                      icon: Icons.lock_reset_outlined, 
                      obscure: true,
                      validator: (val) {
                        if (val != _passwordController.text) return "Las contraseñas no coinciden";
                        return null;
                      }
                    ),
                  ],

                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _enviarFormulario,
                      style: ElevatedButton.styleFrom(backgroundColor: colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: _cargando 
                          ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                          : Text(_esRegistro ? "Siguiente Paso" : "Iniciar Sesión", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _esRegistro = !_esRegistro;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _esRegistro ? "¿Ya tienes cuenta? Inicia sesión" : "¿Nuevo cuidador? Crea tu cuenta",
                      style: const TextStyle(color: colorPrimario, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo({required TextEditingController controller, required String label, required IconData icon, bool obscure = false, TextInputType? type, Widget? suffix, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller, obscureText: obscure, keyboardType: type,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)), suffixIcon: suffix,
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2)),
      ),
      validator: validator ?? (val) => val!.isEmpty ? "Campo requerido" : null,
    );
  }
}