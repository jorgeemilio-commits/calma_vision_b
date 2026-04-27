import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PantallaMedicinasFamiliar extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaMedicinasFamiliar({
    super.key,
    required this.pacienteId,
    required this.nombrePaciente,
  });

  @override
  State<PantallaMedicinasFamiliar> createState() => _PantallaMedicinasFamiliarState();
}

class _PantallaMedicinasFamiliarState extends State<PantallaMedicinasFamiliar> {
  List<Map<String, dynamic>> _medicamentos = [];
  bool _cargando = true;
  final Color colorPrimario = const Color(0xFF4A90E2);

  @override
  void initState() {
    super.initState();
    _cargarMedicamentos();
  }

  // --- 1. CARGAR MEDICINAS DEL PACIENTE ---
  Future<void> _cargarMedicamentos() async {
    setState(() => _cargando = true);
    try {
      // IMPORTANTE: Buscamos las medicinas que le pertenecen al abuelo (pacienteId)
      final respuesta = await Supabase.instance.client
          .from('medicamentos')
          .select()
          .eq('usuario_id', widget.pacienteId)
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _medicamentos = List<Map<String, dynamic>>.from(respuesta);
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- 2. ELIMINAR MEDICINA ---
  Future<void> _eliminarMedicina(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Tratamiento"),
        content: Text("¿Estás seguro de que deseas eliminar $nombre? Desaparecerá de la tableta."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      try {
        await Supabase.instance.client.from('medicamentos').delete().eq('id', id);
        _cargarMedicamentos();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar")));
        setState(() => _cargando = false);
      }
    }
  }

  // --- 3. MODAL PARA AGREGAR NUEVA MEDICINA ---
  void _abrirModalAgregar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ModalAgregarMedicina(
          pacienteId: widget.pacienteId, 
          colorPrimario: colorPrimario,
          alGuardar: _cargarMedicamentos, // Recarga la lista al terminar
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tratamientos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(widget.nombrePaciente, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalAgregar,
        backgroundColor: colorPrimario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Recetar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colorPrimario))
          : _medicamentos.isEmpty
              ? _construirVacio()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _medicamentos.length,
                  itemBuilder: (context, index) {
                    final med = _medicamentos[index];
                    return _construirTarjetaMedicina(med);
                  },
                ),
    );
  }

  Widget _construirTarjetaMedicina(Map<String, dynamic> med) {
    // Para ver si el abuelo ya se tomó la pastilla hoy
    Map<String, dynamic> estadoTomas = med['estado_tomas'] ?? {};
    int tomasTotales = estadoTomas.length;
    int tomasRealizadas = estadoTomas.values.where((v) => v == true).length;

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: colorPrimario.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                image: med['imagen_url'] != null
                    ? DecorationImage(image: NetworkImage(med['imagen_url']), fit: BoxFit.cover)
                    : null,
              ),
              child: med['imagen_url'] == null ? Icon(Icons.medication, color: colorPrimario, size: 35) : null,
            ),
            const SizedBox(width: 20),
            
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med['nombre'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 5),
                  Text("${med['dosis']} • ${med['tipo_ingestion']}", style: const TextStyle(color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  
                  // Horarios
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: (med['horas_toma'].toString().split(',')).map((hora) {
                      bool tomado = estadoTomas[hora] == true;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tomado ? Colors.green[50] : Colors.grey[100],
                          border: Border.all(color: tomado ? Colors.green : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(
                          hora, 
                          style: TextStyle(color: tomado ? Colors.green[700] : Colors.grey[700], fontWeight: FontWeight.bold)
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            
            // Botón Borrar
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _eliminarMedicina(med['id'], med['nombre']),
            )
          ],
        ),
      ),
    );
  }

  Widget _construirVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("No hay medicamentos activos", style: TextStyle(color: Colors.blueGrey, fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// =====================================================================
// BOTTOM SHEET PARA AGREGAR (Adaptado a móviles)
// =====================================================================
class ModalAgregarMedicina extends StatefulWidget {
  final String pacienteId;
  final Color colorPrimario;
  final VoidCallback alGuardar;

  const ModalAgregarMedicina({super.key, required this.pacienteId, required this.colorPrimario, required this.alGuardar});

  @override
  State<ModalAgregarMedicina> createState() => _ModalAgregarMedicinaState();
}

class _ModalAgregarMedicinaState extends State<ModalAgregarMedicina> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _dosisController = TextEditingController();
  final _descController = TextEditingController();
  
  String _tipoIngestion = 'Oral (Pastilla)';
  final List<String> _tipos = ['Oral (Pastilla)', 'Oral (Jarabe)', 'Tópica', 'Gotas', 'Inyectable'];
  List<TimeOfDay> _horasSeleccionadas = [];
  
  Uint8List? _imagenBytes;
  String? _nombreExtensionImagen;
  bool _guardando = false;

  Future<void> _tomarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.gallery); // Usamos galería por comodidad en el celular
    if (foto != null) {
      final bytes = await foto.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
        _nombreExtensionImagen = foto.name;
      });
    }
  }

  Future<void> _agregarHora() async {
    final TimeOfDay? seleccion = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (seleccion != null && !_horasSeleccionadas.contains(seleccion)) {
      setState(() => _horasSeleccionadas.add(seleccion));
    }
  }

  Future<void> _guardarMedicina() async {
    if (!_formKey.currentState!.validate()) return;
    if (_horasSeleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agrega al menos una hora")));
      return;
    }
    
    setState(() => _guardando = true);
    String? imageUrl;

    try {
      // 1. Subir imagen al mismo bucket que usa la App A
      if (_imagenBytes != null) {
        final ext = _nombreExtensionImagen?.split('.').last ?? 'jpg';
        final nombre = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        // Lo guardamos en la carpeta del paciente para que la tableta lo encuentre
        final ruta = '${widget.pacienteId}/$nombre'; 

        await Supabase.instance.client.storage.from('medicinas').uploadBinary(ruta, _imagenBytes!);
        imageUrl = Supabase.instance.client.storage.from('medicinas').getPublicUrl(ruta);
      }

      // 2. Preparar el String de horas (ej. "08:00,15:30")
      List<String> horasString = _horasSeleccionadas.map((h) => "${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}").toList();
      horasString.sort();
      String horasUnidas = horasString.join(',');

      // 3. Preparar el JSON de estados en falso
      Map<String, bool> estadosIniciales = {};
      for (var h in horasString) estadosIniciales[h] = false;

      // 4. Insertar en la tabla apuntando al pacienteId
      await Supabase.instance.client.from('medicamentos').insert({
        'usuario_id': widget.pacienteId, // <-- CLAVE: Vinculamos al abuelo
        'nombre': _nombreController.text.trim(),
        'dosis': _dosisController.text.trim(),
        'tipo_ingestion': _tipoIngestion,
        'horas_toma': horasUnidas,
        'descripcion': _descController.text.trim(),
        'estado_tomas': estadosIniciales, 
        'imagen_url': imageUrl, 
      });

      if (mounted) {
        Navigator.pop(context);
        widget.alGuardar();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      height: MediaQuery.of(context).size.height * 0.85, // Ocupa el 85% de la pantalla
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nuevo Tratamiento", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.colorPrimario)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: _tomarFoto,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: widget.colorPrimario.withOpacity(0.1),
                        backgroundImage: _imagenBytes != null ? MemoryImage(_imagenBytes!) : null,
                        child: _imagenBytes == null ? Icon(Icons.camera_alt, color: widget.colorPrimario, size: 40) : null,
                      ),
                    ),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(labelText: "Nombre (ej. Paracetamol)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                      validator: (v) => v!.isEmpty ? "Requerido" : null,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dosisController,
                            decoration: InputDecoration(labelText: "Dosis", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                            validator: (v) => v!.isEmpty ? "Requerido" : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _tipoIngestion,
                            decoration: InputDecoration(labelText: "Tipo", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                            items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _tipoIngestion = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    // SECCIÓN DE HORARIOS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Horarios", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _horasSeleccionadas.map((h) => Chip(
                              label: Text(h.format(context)),
                              deleteIcon: const Icon(Icons.cancel, size: 18),
                              onDeleted: () => setState(() => _horasSeleccionadas.remove(h)),
                            )).toList(),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _agregarHora, 
                            icon: Icon(Icons.add_alarm, color: widget.colorPrimario), 
                            label: Text("Agregar Hora", style: TextStyle(color: widget.colorPrimario))
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: "Instrucciones (opcional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                    ),
                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: widget.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: _guardando ? null : _guardarMedicina,
                        child: _guardando 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Recetar a Tableta", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}