import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_medicinas_familiar.dart';
import 'pantalla_agenda_familiar.dart';
import 'pantalla_galeria_familiar.dart';

class PantallaInicio extends StatefulWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaInicio({
    super.key,
    required this.pacienteId,
    required this.nombrePaciente,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<Map<String, dynamic>> _medicamentosActivos = [];
  bool _cargandoMed = true;

  @override
  void initState() {
    super.initState();
    _cargarMedicamentos();
  }

  // Carga un resumen de las medicinas para la tarjeta principal
  Future<void> _cargarMedicamentos() async {
    try {
      final respuesta = await Supabase.instance.client
          .from('medicamentos')
          .select('nombre, dosis, horas_toma')
          .eq('usuario_id', widget.pacienteId)
          .limit(5); // Solo mostramos las próximas

      if (mounted) {
        setState(() {
          _medicamentosActivos = List<Map<String, dynamic>>.from(respuesta);
          _cargandoMed = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar medicinas breves: $e");
      if (mounted) setState(() => _cargandoMed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const colorPrimario = Color(0xFF0047A0); // Azul oscuro de tu diseño
    const colorFondo = Color(0xFFE0F7FA); // Azul muy bajito de fondo
    const colorBotonLlamada = Color(0xFF64DD17); // Verde brillante

    return Scaffold(
      backgroundColor: Colors.grey[200], // Fondo exterior para web
      
      // BARRA LATERAL (DRAWER)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: colorPrimario),
              accountName: Text(widget.nombrePaciente, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              accountEmail: const Text("Paciente Activo"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.elderly, size: 40, color: colorPrimario),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes del Dispositivo'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajustes pendientes")));
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Desvincular Paciente', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      
      // CUERPO RESTRINGIDO A TAMAÑO DE TELÉFONO (IDEAL PARA WEB)
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450), // Ancho máximo de celular
          decoration: BoxDecoration(
            color: colorFondo,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Para que tome el colorFondo del Container
            
            // APPBAR INTERNO
            appBar: AppBar(
              backgroundColor: colorPrimario,
              iconTheme: const IconThemeData(color: Colors.white),
              centerTitle: true,
              title: const Text("MI PACIENTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 15.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: colorPrimario), // Aquí iría la foto real
                  ),
                )
              ],
            ),
            
            // CONTENIDO PRINCIPAL
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      
                      // 1. TARJETA DE MEDICINAS SCROLEABLE
                      Container(
                        height: 220, // Altura fija para que tenga scroll interno
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 15, bottom: 5),
                              child: Text("MEDICINAS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)),
                            ),
                            Expanded(
                              child: _cargandoMed 
                                  ? const Center(child: CircularProgressIndicator())
                                  : _medicamentosActivos.isEmpty
                                      ? const Center(child: Text("No hay medicinas programadas", style: TextStyle(color: Colors.grey)))
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          itemCount: _medicamentosActivos.length,
                                          itemBuilder: (context, index) {
                                            final med = _medicamentosActivos[index];
                                            return ListTile(
                                              leading: const Icon(Icons.play_arrow, color: Colors.grey),
                                              title: Text(med['horas_toma'] ?? 'Sin hora', style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                              subtitle: Text("${med['nombre']} - ${med['dosis']}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                                            );
                                          },
                                        ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 2. MÓDULOS PEQUEÑOS DE NAVEGACIÓN
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _botonModuloRapido(context, Icons.medical_services, "Tratamiento", () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaMedicinasFamiliar(pacienteId: widget.pacienteId, nombrePaciente: widget.nombrePaciente)));
                          }),
                          _botonModuloRapido(context, Icons.calendar_month, "Agenda", () {
                            // TODO: Crear PantallaAgendaFamiliar
                            // Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaAgendaFamiliar()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abriendo Agenda...")));
                          }),
                          _botonModuloRapido(context, Icons.photo_library, "Galería", () {
                            // TODO: Crear PantallaGaleriaFamiliar
                            // Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaGaleriaFamiliar()));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Abriendo Galería...")));
                          }),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // 3. ACTIVIDAD RECIENTE (Scrollable natural)
                      const Text("ACTIVIDAD RECIENTE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2), textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      
                      // Mockup de actividades (Después se conectará a Supabase)
                      _tarjetaActividad(Icons.check_circle, "TOMÓ IBUPROFENO (8:00 AM)", "HACE 4 HORAS"),
                      _tarjetaActividad(Icons.phone_in_talk, "LLAMADA CON HIJA", "HACE 1 HORA"),
                      _tarjetaActividad(Icons.check_circle, "TOMÓ PARACETAMOL (11:00 AM)", "HACE 5 MIN"),
                      
                    ],
                  ),
                ),

                // 4. BOTÓN DE LLAMADA FLOTANTE FIJO ABAJO
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Iniciando videollamada... (Próximamente)")));
                      },
                      child: Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colorBotonLlamada,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
                        ),
                        child: const Icon(Icons.phone, color: Colors.white, size: 35),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para los botones de módulos
  Widget _botonModuloRapido(BuildContext context, IconData icono, String titulo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))]
            ),
            child: Icon(icono, color: const Color(0xFF0047A0), size: 28),
          ),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  // Widget auxiliar para las tarjetas de actividad reciente
  Widget _tarjetaActividad(IconData icono, String titulo, String subtitulo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))]
      ),
      child: ListTile(
        leading: Icon(icono, color: Colors.blueGrey[300], size: 40),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}