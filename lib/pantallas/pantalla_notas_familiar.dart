import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PantallaNotasFamiliar extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaNotasFamiliar({
    super.key, 
    required this.pacienteId, 
    required this.nombrePaciente
  });

  @override
  State<PantallaNotasFamiliar> createState() => _PantallaNotasFamiliarState();
}

class _PantallaNotasFamiliarState extends State<PantallaNotasFamiliar> {
  List<Map<String, dynamic>> _notas = [];
  bool _cargando = true;
  
  final Color colorPrimario = const Color(0xFF0047A0);

  @override
  void initState() {
    super.initState();
    _cargarNotas();
  }

  // --- 1. CARGAR NOTAS DESDE SUPABASE ---
  Future<void> _cargarNotas() async {
    setState(() => _cargando = true);
    try {
      final res = await Supabase.instance.client
          .from('notas_medicas')
          .select()
          .eq('usuario_id', widget.pacienteId)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false); // Usamos created_at en lugar de hora

      if (mounted) {
        setState(() {
          _notas = List<Map<String, dynamic>>.from(res);
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar notas: $e");
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al cargar el historial médico"))
        );
      }
    }
  }

  // --- 2. ELIMINAR NOTA ---
  Future<void> _eliminarNota(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Borrar Nota Médica"),
        content: const Text("¿Estás seguro de que deseas eliminar este registro?"),
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
        await Supabase.instance.client.from('notas_medicas').delete().eq('id', id);
        _cargarNotas();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar la nota")));
        setState(() => _cargando = false);
      }
    }
  }

  // --- 3. MODAL PARA AGREGAR NUEVA NOTA ---
  void _agregarNotaRapida() {
    final tituloCtrl = TextEditingController();
    final contenidoCtrl = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom, 
              left: 25, right: 25, top: 25
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Nueva Nota Médica", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorPrimario)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 15),
                
                TextField(
                  controller: tituloCtrl, 
                  decoration: InputDecoration(
                    labelText: "Asunto (ej. Visita Cardiología)", 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                  )
                ),
                const SizedBox(height: 15),
                
                TextField(
                  controller: contenidoCtrl, 
                  maxLines: 4, 
                  decoration: InputDecoration(
                    labelText: "Detalles, síntomas o instrucciones", 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    alignLabelWithHint: true,
                  )
                ),
                const SizedBox(height: 25),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimario,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: guardando ? null : () async {
                      if (tituloCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("El asunto es requerido")));
                        return;
                      }
                      
                      setModalState(() => guardando = true);
                      
                      try {
                        // AQUÍ ESTÁ LA CORRECCIÓN CLAVE: Ya no mandamos la columna 'hora'
                        await Supabase.instance.client.from('notas_medicas').insert({
                          'usuario_id': widget.pacienteId,
                          'titulo': tituloCtrl.text.trim(),
                          'contenido': contenidoCtrl.text.trim(),
                          'fecha': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        });
                        
                        if (mounted) {
                          Navigator.pop(ctx);
                          _cargarNotas();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red)
                          );
                        }
                      } finally {
                        if (mounted) setModalState(() => guardando = false);
                      }
                    },
                    child: guardando 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Guardar Nota", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Notas Médicas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(widget.nombrePaciente, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: colorPrimario,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarNotaRapida,
        backgroundColor: colorPrimario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Redactar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _cargando 
        ? Center(child: CircularProgressIndicator(color: colorPrimario))
        : _notas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  const Text("No hay notas médicas registradas", style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _notas.length,
              itemBuilder: (context, index) {
                final nota = _notas[index];
                
                // Formateamos la fecha normal
                final String fechaFormateada = DateFormat('dd MMM yyyy', 'es').format(DateTime.parse(nota['fecha']));
                
                // Extraemos la hora directamente de created_at para mostrarla en la UI
                String horaFormateada = '';
                if (nota['created_at'] != null) {
                  final DateTime fechaCreacion = DateTime.parse(nota['created_at']).toLocal();
                  horaFormateada = DateFormat('HH:mm').format(fechaCreacion);
                }

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey[300]!)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorPrimario.withOpacity(0.1), 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Icon(Icons.medical_information, color: colorPrimario, size: 24),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nota['titulo'] ?? 'Sin título', 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    // Mostramos la fecha y la hora extraída
                                    horaFormateada.isNotEmpty ? "$fechaFormateada • $horaFormateada hrs" : fechaFormateada, 
                                    style: TextStyle(color: colorPrimario, fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _eliminarNota(nota['id']),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        if (nota['contenido'] != null && nota['contenido'].toString().trim().isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(),
                          ),
                          Text(
                            nota['contenido'],
                            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}