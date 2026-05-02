import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'pantalla_medicinas_familiar.dart';
import 'pantalla_agenda_familiar.dart';
import 'pantalla_notas_familiar.dart';
import 'pantalla_galeria_familiar.dart';
import 'pantalla_historial_actividad.dart';

class PantallaInicio extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaInicio({super.key, required this.pacienteId, required this.nombrePaciente});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Map<String, dynamic>> _proximasDosis = [];
  List<Map<String, dynamic>> _actividades = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _refrescarTodo();
  }

  Future<void> _refrescarTodo() async {
    setState(() => _cargando = true);
    await Future.wait([
      _cargarMedicamentos(),
      _cargarActividadReciente(),
    ]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarMedicamentos() async {
    try {
      final respuesta = await Supabase.instance.client
          .from('medicamentos')
          .select('nombre, dosis, horas_toma')
          .eq('usuario_id', widget.pacienteId);

      final ahora = DateTime.now();
      List<Map<String, dynamic>> listaTemporal = [];

      for (var med in respuesta) {
        if (med['horas_toma'] != null) {
          List<String> horas = med['horas_toma'].toString().split(',');
          for (var h in horas) {
            listaTemporal.add({
              'nombre': med['nombre'],
              'dosis': med['dosis'],
              'horaString': h,
              'horaData': _convertirAComparable(h),
            });
          }
        }
      }

      listaTemporal.sort((a, b) {
        DateTime horaA = a['horaData'];
        DateTime horaB = b['horaData'];
        bool pasoA = horaA.isBefore(ahora);
        bool pasoB = horaB.isBefore(ahora);
        if (pasoA && !pasoB) return 1;
        if (!pasoA && pasoB) return -1;
        return horaA.compareTo(horaB);
      });

      _proximasDosis = listaTemporal;
    } catch (e) {
      debugPrint("Error medicinas: $e");
    }
  }

  Future<void> _cargarActividadReciente() async {
    try {
      final res = await Supabase.instance.client
          .from('actividad_reciente')
          .select()
          .eq('paciente_id', widget.pacienteId)
          .order('created_at', ascending: false)
          .limit(5);

      _actividades = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error actividad: $e");
    }
  }

  DateTime _convertirAComparable(String horaStr) {
    final partes = horaStr.split(':');
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day, int.parse(partes[0]), int.parse(partes[1]));
  }

  String _haceCuanto(String fechaIso) {
    final fecha = DateTime.parse(fechaIso).toLocal();
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 60) return "Hace ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Hace ${diff.inHours} h";
    return DateFormat('dd/MM').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    const colorPrimario = Color(0xFF0047A0);
    const colorFondo = Color(0xFFF7FEFF);

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorPrimario,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("MI PACIENTE", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refrescarTodo,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Column(
                    children: [
                      // --- SECCIÓN MEDICINAS ---
                      _construirSeccionMedicinas(colorPrimario),
                      const SizedBox(height: 35),

                      // --- BOTONES MÓDULOS ---
                      _construirGridModulos(context, colorPrimario),
                      const SizedBox(height: 45),

                      // --- ACTIVIDAD RECIENTE ---
                      _construirSeccionActividad(colorPrimario),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
              _construirBotonLlamada(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirSeccionMedicinas(Color color) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text("PRÓXIMAS DOSIS", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15, letterSpacing: 1.1)),
          ),
          Expanded(
            child: _proximasDosis.isEmpty
                ? const Center(child: Text("No hay dosis pendientes", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _proximasDosis.length > 3 ? 3 : _proximasDosis.length,
                    itemBuilder: (context, i) {
                      final d = _proximasDosis[i];
                      return ListTile(
                        leading: Icon(Icons.access_time, color: color, size: 22),
                        title: Text(d['horaString'], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                        subtitle: Text("${d['nombre']} - ${d['dosis']}", 
                          style: const TextStyle(fontSize: 16)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionActividad(Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("ACTIVIDAD RECIENTE", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PantallaHistorialActividad(pacienteId: widget.pacienteId))),
              child: const Text("Ver todo", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_actividades.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text("Sin actividad reciente", style: TextStyle(fontSize: 16)))
        else
          ..._actividades.map((a) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  leading: _obtenerIconoActividad(a['tipo']),
                  title: Text(a['mensaje'], 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.2)),
                  trailing: Text(_haceCuanto(a['created_at']), 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              )),
      ],
    );
  }

  Icon _obtenerIconoActividad(String? tipo) {
    switch (tipo) {
      case 'medicamentos': return const Icon(Icons.medication, color: Colors.green, size: 24);
      case 'galeria': return const Icon(Icons.image, color: Colors.orange, size: 24);
      case 'recordatorios': return const Icon(Icons.event, color: Colors.blue, size: 24);
      case 'notas_medicas': return const Icon(Icons.assignment, color: Colors.purple, size: 24);
      default: return const Icon(Icons.info, size: 24);
    }
  }

  Widget _construirGridModulos(BuildContext context, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _btn(context, Icons.medication, "Medicina", PantallaMedicinasFamiliar(pacienteId: widget.pacienteId, nombrePaciente: widget.nombrePaciente)),
        _btn(context, Icons.calendar_month, "Agenda", PantallaAgendaFamiliar(pacienteId: widget.pacienteId, nombrePaciente: widget.nombrePaciente)),
        _btn(context, Icons.edit_note, "Notas", PantallaNotasFamiliar(pacienteId: widget.pacienteId, nombrePaciente: widget.nombrePaciente)),
        _btn(context, Icons.collections, "Galería", PantallaGaleriaFamiliar(pacienteId: widget.pacienteId, nombrePaciente: widget.nombrePaciente)),
      ],
    );
  }

  Widget _btn(BuildContext context, IconData icon, String label, Widget screen) {
    return Column(children: [
      IconButton.filled(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => screen)),
        icon: Icon(icon, size: 28),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white, 
          foregroundColor: const Color(0xFF0047A0), 
          padding: const EdgeInsets.all(18)
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    ]);
  }

  Widget _construirBotonLlamada() {
    return Positioned(
      bottom: 25, left: 0, right: 0,
      child: Center(
        child: FloatingActionButton.large(
          onPressed: () {}, 
          backgroundColor: Colors.green, 
          child: const Icon(Icons.phone, color: Colors.white, size: 45)
        )
      ),
    );
  }
}