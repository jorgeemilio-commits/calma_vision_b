import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PantallaGaleriaFamiliar extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaGaleriaFamiliar({
    super.key, 
    required this.pacienteId, 
    required this.nombrePaciente
  });

  @override
  State<PantallaGaleriaFamiliar> createState() => _PantallaGaleriaFamiliarState();
}

class _PantallaGaleriaFamiliarState extends State<PantallaGaleriaFamiliar> {
  List<Map<String, dynamic>> _fotos = [];
  bool _cargando = true;
  bool _subiendo = false;
  
  final Color colorPrimario = const Color(0xFF0047A0);
  final Color colorFondo = const Color(0xFFF0F8FF);

  @override
  void initState() {
    super.initState();
    _cargarFotos();
  }

  // --- CARGA DE DATOS ---
  Future<void> _cargarFotos() async {
    setState(() => _cargando = true);
    try {
      final res = await Supabase.instance.client
          .from('galeria') // Usamos tu tabla existente
          .select()
          .eq('usuario_id', widget.pacienteId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _fotos = List<Map<String, dynamic>>.from(res);
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- SUBIDA CON CAMPO DE TEXTO GRANDE ---
  Future<void> _subirFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? imagen = await picker.pickImage(source: ImageSource.gallery);
    
    if (imagen == null) return;

    final descCtrl = TextEditingController();
    
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Añadir un Recuerdo", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Escribe una pequeña anécdota o descripción para que el abuelo la recuerde:"),
              const SizedBox(height: 15),
              TextField(
                controller: descCtrl,
                maxLines: 6, // CAMBIO: Ahora es un campo mucho más grande
                decoration: InputDecoration(
                  hintText: "Ej. Aquí estamos todos en el cumpleaños de Luis, ¡nos divertimos mucho ese día!",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  fillColor: Colors.grey[50],
                  filled: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Compartir", style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );

    if (confirmar != true) return;

    setState(() => _subiendo = true);

    try {
      final bytes = await imagen.readAsBytes();
      final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rutaStorage = '${widget.pacienteId}/$nombreArchivo';

      await Supabase.instance.client.storage
          .from('galeria')
          .uploadBinary(rutaStorage, bytes);

      final urlPublica = Supabase.instance.client.storage
          .from('galeria')
          .getPublicUrl(rutaStorage);

      await Supabase.instance.client.from('galeria').insert({
        'usuario_id': widget.pacienteId,
        'imagen_url': urlPublica,
        'descripcion': descCtrl.text.trim(), // Se guarda la anécdota[cite: 1]
        'fecha_toma': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      _cargarFotos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  // --- VISOR DE ZOOM CON DESCRIPCIÓN ---
  void _verFotoZoom(String url, String? descripcion) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // El visor de imagen con zoom interactivo
            Center(
              child: InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            
            // Capa inferior con la descripción/anécdota
            if (descripcion != null && descripcion.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    descripcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- BORRADO ---
  Future<void> _eliminarFoto(String id, String url) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar"),
        content: const Text("¿Borrar este recuerdo definitivamente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí")),
        ],
      )
    );

    if (confirmar != true) return;

    try {
      final Uri uri = Uri.parse(url);
      final String ruta = uri.pathSegments.last;
      final String rutaCompleta = '${widget.pacienteId}/$ruta';

      await Supabase.instance.client.storage.from('galeria').remove([rutaCompleta]);
      await Supabase.instance.client.from('galeria').delete().eq('id', id);
      _cargarFotos();
    } catch (e) {
      debugPrint("Error al borrar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        title: const Text("Recuerdos Familiares", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: colorPrimario,
        elevation: 0,
      ),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator())
        : _fotos.isEmpty 
          ? const Center(child: Text("Comparte la primera foto con el abuelo"))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _fotos.length,
              itemBuilder: (context, index) {
                final foto = _fotos[index];
                return GestureDetector(
                  onTap: () => _verFotoZoom(foto['imagen_url'], foto['descripcion']), // ZOOM + DESC[cite: 1]
                  onLongPress: () => _eliminarFoto(foto['id'], foto['imagen_url']),
                  child: Hero(
                    tag: foto['id'],
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        image: DecorationImage(image: NetworkImage(foto['imagen_url']), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subirFoto,
        backgroundColor: colorPrimario,
        label: const Text("Subir Foto", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}