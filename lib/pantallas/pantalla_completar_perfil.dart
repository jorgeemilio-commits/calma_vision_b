import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'pantalla_seleccion_terminal.dart';

class PantallaCompletarPerfil extends StatefulWidget {
  const PantallaCompletarPerfil({super.key});

  @override
  State<PantallaCompletarPerfil> createState() => _PantallaCompletarPerfilState();
}

class _PantallaCompletarPerfilState extends State<PantallaCompletarPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  DateTime? _fechaNacimiento;
  Uint8List? _imagenBytes;
  String? _nombreImagen;
  bool _guardando = false;

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

  Future<void> _seleccionarFecha() async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale("es", "ES"),
    );
    if (seleccion != null) setState(() => _fechaNacimiento = seleccion);
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecciona tu fecha de nacimiento"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _guardando = true);
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      String? urlFoto;

      // 1. Subir imagen si existe
      if (_imagenBytes != null && _nombreImagen != null) {
        final ext = _nombreImagen!.split('.').last;
        final path = 'cuidadores/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        
        await Supabase.instance.client.storage.from('perfiles').uploadBinary(path, _imagenBytes!);
        urlFoto = Supabase.instance.client.storage.from('perfiles').getPublicUrl(path);
      }

      // 2. Insertar en la base de datos (AHORA SÍ ES SEGURO)
      await Supabase.instance.client.from('perfiles_cuidadores').insert({
        'id': user.id,
        'nombre': _nombreController.text.trim(),
        'url_foto': urlFoto,
        'fecha_nacimiento': DateFormat('yyyy-MM-dd').format(_fechaNacimiento!),
        'parentesco_general': 'Familiar',
      });

      // 3. ¡Éxito! Navegar a la app
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaSeleccionTerminal()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar perfil: $e"), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
                  const Text("¡Casi listos!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorPrimario)),
                  const SizedBox(height: 10),
                  const Text("Completa estos datos para que tu familiar pueda reconocerte.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                  const SizedBox(height: 30),

                  GestureDetector(
                    onTap: _seleccionarImagen,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: colorPrimario.withOpacity(0.1),
                          backgroundImage: _imagenBytes != null ? MemoryImage(_imagenBytes!) : null,
                          child: _imagenBytes == null ? const Icon(Icons.person, color: colorPrimario, size: 50) : null,
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
                  
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: "Nombre o Apodo", prefixIcon: const Icon(Icons.badge_outlined, color: colorPrimario),
                      filled: true, fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    validator: (val) => val!.isEmpty ? "Ingresa tu nombre" : null,
                  ),
                  const SizedBox(height: 15),
                  
                  InkWell(
                    onTap: _seleccionarFecha,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined, color: colorPrimario),
                          const SizedBox(width: 15),
                          Text(
                            _fechaNacimiento == null ? "Fecha de Nacimiento" : DateFormat('dd/MM/yyyy').format(_fechaNacimiento!),
                            style: TextStyle(fontSize: 16, color: _fechaNacimiento == null ? Colors.grey[700] : Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardarPerfil,
                      style: ElevatedButton.styleFrom(backgroundColor: colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: _guardando 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("Finalizar Registro", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}