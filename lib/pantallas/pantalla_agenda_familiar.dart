import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class PantallaAgendaFamiliar extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaAgendaFamiliar({
    super.key,
    required this.pacienteId,
    required this.nombrePaciente,
  });

  @override
  State<PantallaAgendaFamiliar> createState() => _PantallaAgendaFamiliarState();
}

class _PantallaAgendaFamiliarState extends State<PantallaAgendaFamiliar> {
  DateTime _diaEnfocado = DateTime.now();
  DateTime? _diaSeleccionado;
  
  List<Map<String, dynamic>> _recordatoriosDelDia = [];
  bool _cargando = false;

  final Color colorPrimario = const Color(0xFF4A90E2); // Azul Familiar

  @override
  void initState() {
    super.initState();
    _diaSeleccionado = _diaEnfocado;
    _cargarDatosDelDia(_diaSeleccionado!);
  }

  // --- 1. CARGAR DATOS DESDE SUPABASE ---
  Future<void> _cargarDatosDelDia(DateTime fecha) async {
    setState(() => _cargando = true);
    final fechaFiltro = DateFormat('yyyy-MM-dd').format(fecha);

    try {
      // Usamos el ID del abuelo (pacienteId) para traer sus citas
      final recordatoriosRes = await Supabase.instance.client
          .from('recordatorios')
          .select()
          .eq('usuario_id', widget.pacienteId)
          .eq('fecha', fechaFiltro)
          .order('hora', ascending: true);

      if (mounted) {
        setState(() {
          _recordatoriosDelDia = List<Map<String, dynamic>>.from(recordatoriosRes);
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al sincronizar datos del calendario: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- 2. ELIMINAR RECORDATORIO ---
  Future<void> _eliminarRecordatorio(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Borrar Evento"),
        content: const Text("¿Estás seguro? Desaparecerá de la tableta de tu familiar."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Borrar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirmar == true) {
      setState(() => _cargando = true);
      try {
        await Supabase.instance.client.from('recordatorios').delete().eq('id', id);
        _cargarDatosDelDia(_diaSeleccionado!); // Recarga el día actual
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al borrar")));
        setState(() => _cargando = false);
      }
    }
  }

  // --- 3. MODAL PARA AGREGAR NUEVA CITA/RECORDATORIO ---
  void _abrirModalAgregar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ModalAgregarRecordatorio(
          pacienteId: widget.pacienteId, 
          colorPrimario: colorPrimario,
          fechaInicial: _diaSeleccionado ?? DateTime.now(), // Inicia en el día que tienes seleccionado
          alGuardar: () => _cargarDatosDelDia(_diaSeleccionado!), // Recarga tras guardar
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
            const Text("Agenda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
        label: const Text("Agendar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _construirCalendario(),
          const SizedBox(height: 10),
          Expanded(child: _construirListaDelDia()),
        ],
      ),
    );
  }

  Widget _construirCalendario() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 10),
      child: TableCalendar(
        locale: 'es_MX',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _diaEnfocado,
        selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _diaSeleccionado = selectedDay;
            _diaEnfocado = focusedDay;
          });
          _cargarDatosDelDia(selectedDay);
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: colorPrimario.withOpacity(0.3), shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: colorPrimario, shape: BoxShape.circle),
          weekendTextStyle: const TextStyle(color: Colors.redAccent),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _construirListaDelDia() {
    if (_cargando) return Center(child: CircularProgressIndicator(color: colorPrimario));
    
    if (_recordatoriosDelDia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text("El día está libre", style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
          ],
        ),
      );
    }

    final String fechaTxt = DateFormat('EEEE d \'de\' MMMM', 'es').format(_diaSeleccionado!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          child: Text(fechaTxt.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recordatoriosDelDia.length,
            itemBuilder: (context, index) {
              final item = _recordatoriosDelDia[index];
              final bool completado = item['completado'] ?? false;
              final String horaCortada = item['hora'].toString().substring(0, 5);

              return Card(
                elevation: 0,
                color: completado ? Colors.grey[200] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: completado ? Colors.transparent : Colors.grey[300]!)
                ),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colorPrimario.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.notifications_active, color: completado ? Colors.grey : colorPrimario),
                  ),
                  title: Text(
                    item['titulo'], 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: completado ? TextDecoration.lineThrough : null)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(horaCortada, style: TextStyle(color: colorPrimario, fontWeight: FontWeight.bold)),
                      if (item['descripcion'] != null && item['descripcion'].toString().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(item['descripcion'], style: const TextStyle(fontSize: 13)),
                      ]
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _eliminarRecordatorio(item['id']),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// BOTTOM SHEET PARA AGREGAR EVENTO DESDE EL CELULAR
// =====================================================================
class ModalAgregarRecordatorio extends StatefulWidget {
  final String pacienteId;
  final Color colorPrimario;
  final DateTime fechaInicial;
  final VoidCallback alGuardar;

  const ModalAgregarRecordatorio({
    super.key, 
    required this.pacienteId, 
    required this.colorPrimario, 
    required this.fechaInicial,
    required this.alGuardar
  });

  @override
  State<ModalAgregarRecordatorio> createState() => _ModalAgregarRecordatorioState();
}

class _ModalAgregarRecordatorioState extends State<ModalAgregarRecordatorio> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  late DateTime _fechaSeleccionada;
  TimeOfDay _horaSeleccionada = TimeOfDay.now();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = widget.fechaInicial; // Pre-seleccionamos el día que estaba viendo
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? seleccion = await showTimePicker(context: context, initialTime: _horaSeleccionada);
    if (seleccion != null) setState(() => _horaSeleccionada = seleccion);
  }

  Future<void> _guardarEvento() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _guardando = true);
    final String horaSQL = "${_horaSeleccionada.hour.toString().padLeft(2, '0')}:${_horaSeleccionada.minute.toString().padLeft(2, '0')}:00";

    try {
      await Supabase.instance.client.from('recordatorios').insert({
        'usuario_id': widget.pacienteId, // <-- CLAVE: Vinculamos al abuelo
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'fecha': DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
        'hora': horaSQL,
        'completado': false, 
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nuevo Evento", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.colorPrimario)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: _tituloController,
                  decoration: InputDecoration(labelText: "Título (ej. Cita Médica)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                ),
                const SizedBox(height: 15),
                
                // Selección de Hora con el diseño del móvil
                InkWell(
                  onTap: _seleccionarHora,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                    decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: widget.colorPrimario),
                        const SizedBox(width: 15),
                        Text("Hora: ${_horaSeleccionada.format(context)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: "Detalles (opcional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                ),
                const SizedBox(height: 25),
                
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: widget.colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: _guardando ? null : _guardarEvento,
                    child: _guardando 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Agendar a Tableta", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}