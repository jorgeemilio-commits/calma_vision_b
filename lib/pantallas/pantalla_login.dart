import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'pantalla_seleccion_terminal.dart';

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

  // Controladores
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  final _nombreController = TextEditingController();
  
  // Datos adicionales para el registro
  DateTime? _fechaNacimiento;
  Uint8List? _imagenBytes;
  String? _nombreImagen;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  // --- SELECTOR DE IMAGEN ---
  Future<void> _seleccionarImagen() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
        _nombreImagen = imagen.name;
      });
    }
  }

  // --- SELECTOR DE FECHA ---
  Future<void> _seleccionarFecha() async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)), // Edad inicial sugerida: 25 años
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale("es", "ES"),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
    if (seleccion != null) setState(() => _fechaNacimiento = seleccion);
  }

  // --- LÓGICA DE AUTH Y REGISTRO ---
  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_esRegistro && _fechaNacimiento == null) {
      _mostrarError("Por favor selecciona tu fecha de nacimiento");
      return;
    }

    setState(() => _cargando = true);

    try {
      if (_esRegistro) {
        // 1. Registro en Supabase Auth
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = res.user;
        if (user != null) {
          String? urlFoto;

          // 2. Subir imagen al bucket 'perfiles' si seleccionó una
          if (_imagenBytes != null && _nombreImagen != null) {
            final ext = _nombreImagen!.split('.').last;
            final path = 'cuidadores/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
            
            await Supabase.instance.client.storage
                .from('perfiles')
                .uploadBinary(path, _imagenBytes!);
                
            urlFoto = Supabase.instance.client.storage
                .from('perfiles')
                .getPublicUrl(path);
          } else {
            // Imagen por defecto si no puso nada
            urlFoto = "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";
          }

          // 3. Insertar perfil en la tabla 'perfiles_cuidadores'
          await Supabase.instance.client.from('perfiles_cuidadores').insert({
            'id': user.id,
            'nombre': _nombreController.text.trim(),
            'url_foto': urlFoto,
            'fecha_nacimiento': DateFormat('yyyy-MM-dd').format(_fechaNacimiento!),
            'parentesco_general': 'Familiar', 
          });
        }
      } else {
        // Inicio de sesión normal
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaSeleccionTerminal()),
        );
      }
    } on AuthException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      _mostrarError("Error inesperado al conectar con el servidor.");
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    // Color principal azulado de la App B
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
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorPrimario, fontFamily: 'Roboto'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _esRegistro ? "Ingresa tus datos para continuar" : "Bienvenido de vuelta a Calma Vision",
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 16),
                  ),
                  const SizedBox(height: 30),

                  if (_esRegistro) ...[
                    // SELECTOR DE FOTO DE PERFIL
                    GestureDetector(
                      onTap: _seleccionarImagen,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: colorPrimario.withOpacity(0.1),
                            backgroundImage: _imagenBytes != null ? MemoryImage(_imagenBytes!) : null,
                            child: _imagenBytes == null 
                                ? const Icon(Icons.person, color: colorPrimario, size: 50) 
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: colorPrimario, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    _campo(
                      controller: _nombreController, 
                      label: "Nombre Completo", 
                      icon: Icons.badge_outlined
                    ),
                    const SizedBox(height: 15),
                    
                    // SELECTOR DE FECHA DE NACIMIENTO
                    _buildSelectorFecha(colorPrimario),
                    const SizedBox(height: 15),
                  ],

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
                    validator: (val) => val!.length < 6 ? "La contraseña debe tener al menos 6 caracteres" : null
                  ),
                  
                  if (_esRegistro) ...[
                    const SizedBox(height: 15),
                    _campo(
                      controller: _confirmarPasswordController, 
                      label: "Confirmar Contraseña", 
                      icon: Icons.lock_reset_outlined, 
                      obscure: true,
                      validator: (val) {
                        if (val!.isEmpty) return "Confirma tu contraseña";
                        if (val != _passwordController.text) return "Las contraseñas no coinciden";
                        return null;
                      }
                    ),
                  ],

                  const SizedBox(height: 35),
                  
                  SizedBox(
                    width: double.infinity, 
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _enviarFormulario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrimario, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 2,
                      ),
                      child: _cargando 
                          ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                          : Text(
                              _esRegistro ? "Registrarme" : "Iniciar Sesión", 
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
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
                      _esRegistro ? "¿Ya tienes cuenta? Inicia sesión aquí" : "¿Nuevo cuidador? Crea tu cuenta",
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

  // WIDGET REUTILIZABLE PARA CAMPOS DE TEXTO
  Widget _campo({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    bool obscure = false, 
    TextInputType? type, 
    Widget? suffix, 
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)), 
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!)
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2)
        ),
      ),
      validator: validator ?? (val) => val!.isEmpty ? "Campo requerido" : null,
    );
  }

  // WIDGET REUTILIZABLE PARA EL SELECTOR DE FECHA
  Widget _buildSelectorFecha(Color color) {
    return InkWell(
      onTap: _seleccionarFecha,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[300]!), 
          borderRadius: BorderRadius.circular(15)
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined, color: color),
            const SizedBox(width: 15),
            Text(
              _fechaNacimiento == null 
                  ? "Fecha de Nacimiento" 
                  : DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es').format(_fechaNacimiento!),
              style: TextStyle(
                fontSize: 16, 
                color: _fechaNacimiento == null ? Colors.grey[700] : const Color(0xFF2C3E50),
                fontWeight: _fechaNacimiento == null ? FontWeight.normal : FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }
}