import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  List<Map<String, dynamic>> _todosLosMedicamentos = [];
  List<String> _horasDisponibles = [];
  String? _horaSeleccionada;
  bool _cargando = true;

  final Color colorPrimario = const Color(0xFF4A90E2); // Azul Familiar

  @override
  void initState() {
    super.initState();
    _cargarMedicamentos();
  }

  // --- 1. CARGAR MEDICINAS Y EXTRAER HORARIOS ---
  Future<void> _cargarMedicamentos() async {
    setState(() => _cargando = true);
    try {
      final respuesta = await Supabase.instance.client
          .from('medicamentos')
          .select()
          .eq('usuario_id', widget.pacienteId);

      if (mounted) {
        _todosLosMedicamentos = List<Map<String, dynamic>>.from(respuesta);
        
        Set<String> horasUnicas = {};
        for (var med in _todosLosMedicamentos) {
          if (med['horas_toma'] != null && med['horas_toma'].toString().isNotEmpty) {
            List<String> horas = med['horas_toma'].toString().split(',');
            horasUnicas.addAll(horas);
          }
        }
        
        _horasDisponibles = horasUnicas.toList()..sort();
        
        // Si no hay hora seleccionada, o si la que estaba se borró, selecciona la primera
        if (_horasDisponibles.isNotEmpty && !_horasDisponibles.contains(_horaSeleccionada)) {
          _horaSeleccionada = _horasDisponibles.first;
        } else if (_horasDisponibles.isEmpty) {
          _horaSeleccionada = null;
        }

        setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- 2. MARCAR O DESMARCAR TOMA DESDE EL CELULAR ---
  Future<void> _alternarToma(String idMedicina, String hora, Map<String, dynamic> estadoActuales) async {
    try {
      bool estadoActual = estadoActuales[hora] ?? false;
      estadoActuales[hora] = !estadoActual; // Invertimos el estado

      // Actualizamos en Supabase
      await Supabase.instance.client
          .from('medicamentos')
          .update({'estado_tomas': estadoActuales})
          .eq('id', idMedicina);
      
      // Recargamos la interfaz para ver el cambio
      await _cargarMedicamentos();
    } catch (e) {
      debugPrint("Error al actualizar la toma: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al actualizar estado")));
    }
  }

  // --- 3. ELIMINAR MEDICINA ---
  Future<void> _eliminarMedicina(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Tratamiento"),
        content: Text("¿Estás seguro de que deseas eliminar $nombre? Desaparecerá de la tableta de tu familiar."),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar")));
        setState(() => _cargando = false);
      }
    }
  }

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
          alGuardar: _cargarMedicamentos, 
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
          : _horasDisponibles.isEmpty
              ? _construirVacio()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CINTA SUPERIOR DE HORARIOS (Estilo Móvil)
                    _construirCintaHorarios(),
                    
                    // LISTA DE MEDICINAS PARA ESA HORA
                    Expanded(
                      child: _construirDetalleHora(),
                    ),
                  ],
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

  // --- CINTA HORIZONTAL DE HORARIOS ---
  Widget _construirCintaHorarios() {
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 15),
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _horasDisponibles.length,
        itemBuilder: (context, index) {
          final hora = _horasDisponibles[index];
          final bool esSeleccionada = hora == _horaSeleccionada;
          final DateTime horaObj = DateFormat("HH:mm").parse(hora);
          final String horaFormateada = DateFormat("hh:mm a").format(horaObj);

          return GestureDetector(
            onTap: () => setState(() => _horaSeleccionada = hora),
            child: Container(
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: esSeleccionada ? colorPrimario : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                boxShadow: esSeleccionada ? [BoxShadow(color: colorPrimario.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
                border: Border.all(color: esSeleccionada ? colorPrimario : Colors.grey[300]!)
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: esSeleccionada ? Colors.white : Colors.blueGrey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    horaFormateada, 
                    style: TextStyle(
                      color: esSeleccionada ? Colors.white : Colors.blueGrey, 
                      fontWeight: FontWeight.bold,
                      fontSize: 16
                    )
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- LISTA DE MEDICINAS ---
  Widget _construirDetalleHora() {
    if (_horaSeleccionada == null) return const SizedBox.shrink();

    // Filtramos las medicinas que tocan en la hora seleccionada
    final medicinasDeLaHora = _todosLosMedicamentos.where((med) {
      if (med['horas_toma'] == null) return false;
      List<String> horas = med['horas_toma'].toString().split(',');
      return horas.contains(_horaSeleccionada);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: medicinasDeLaHora.length,
      itemBuilder: (context, index) {
        final med = medicinasDeLaHora[index];
        Map<String, dynamic> estadoTomas = med['estado_tomas'] ?? {};
        bool estaTomado = estadoTomas[_horaSeleccionada!] == true;

        return Card(
          elevation: estaTomado ? 0 : 4,
          shadowColor: Colors.black26,
          color: estaTomado ? Colors.grey[100] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: estaTomado ? Colors.grey[300]! : Colors.transparent, width: 2)
          ),
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. IMAGEN
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: colorPrimario.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    image: med['imagen_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(med['imagen_url']), 
                            fit: BoxFit.cover,
                            colorFilter: estaTomado ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) : null,
                          )
                        : null,
                  ),
                  child: med['imagen_url'] == null 
                      ? Icon(Icons.medication, color: estaTomado ? Colors.grey : colorPrimario, size: 35) 
                      : null,
                ),
                const SizedBox(width: 15),
                
                // 2. INFO DE LA MEDICINA
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['nombre'], 
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          color: estaTomado ? Colors.grey : const Color(0xFF2C3E50),
                          decoration: estaTomado ? TextDecoration.lineThrough : null,
                        )
                      ),
                      const SizedBox(height: 5),
                      Text("${med['dosis']} • ${med['tipo_ingestion']}", style: TextStyle(color: estaTomado ? Colors.grey : Colors.blueGrey)),
                      
                      if (med['descripcion'] != null && med['descripcion'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          med['descripcion'], 
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: estaTomado ? Colors.grey : Colors.black54)
                        )
                      ],
                      
                      const SizedBox(height: 10),
                      // Botón para borrar el tratamiento completo
                      InkWell(
                        onTap: () => _eliminarMedicina(med['id'], med['nombre']),
                        child: const Text("Eliminar tratamiento", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
                
                // 3. BOTÓN INTERACTIVO (CHECK)
                GestureDetector(
                  onTap: () => _alternarToma(med['id'], _horaSeleccionada!, estadoTomas),
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: estaTomado ? Colors.green : Colors.white,
                      border: Border.all(color: estaTomado ? Colors.green : Colors.grey[400]!, width: 2),
                    ),
                    child: Icon(Icons.check, color: estaTomado ? Colors.white : Colors.transparent, size: 30),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// BOTTOM SHEET PARA AGREGAR (Se mantiene igual, solo colores adaptados)
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
    final XFile? foto = await picker.pickImage(source: ImageSource.gallery);
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
      if (_imagenBytes != null) {
        final ext = _nombreExtensionImagen?.split('.').last ?? 'jpg';
        final nombre = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ruta = '${widget.pacienteId}/$nombre'; 

        await Supabase.instance.client.storage.from('medicinas').uploadBinary(ruta, _imagenBytes!);
        imageUrl = Supabase.instance.client.storage.from('medicinas').getPublicUrl(ruta);
      }

      List<String> horasString = _horasSeleccionadas.map((h) => "${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}").toList();
      horasString.sort();
      String horasUnidas = horasString.join(',');

      Map<String, bool> estadosIniciales = {};
      for (var h in horasString) estadosIniciales[h] = false;

      await Supabase.instance.client.from('medicamentos').insert({
        'usuario_id': widget.pacienteId,
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
      height: MediaQuery.of(context).size.height * 0.85, 
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