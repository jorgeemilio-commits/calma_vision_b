import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_inicio.dart';
import 'pantalla_login.dart';

class PantallaSeleccionTerminal extends StatefulWidget {
  const PantallaSeleccionTerminal({super.key});

  @override
  State<PantallaSeleccionTerminal> createState() => _PantallaSeleccionTerminalState();
}

class _PantallaSeleccionTerminalState extends State<PantallaSeleccionTerminal> {
  List<Map<String, dynamic>> _pacientes = [];
  bool _cargando = true;
  String? _miId;

  final Color colorPrimario = const Color(0xFF4A90E2);

  @override
  void initState() {
    super.initState();
    _miId = Supabase.instance.client.auth.currentUser?.id;
    _cargarPacientesVinculados();
  }

  // ========================================================
  // LÓGICA DE DATOS
  // ========================================================
  Future<void> _cargarPacientesVinculados() async {
    if (_miId == null) return;
    setState(() => _cargando = true);

    try {
      // Buscamos todas las vinculaciones donde yo sea el cuidador
      final res = await Supabase.instance.client
          .from('vinculaciones')
          .select('paciente_id, usuarios(nombre, terminal_id)')
          .eq('cuidador_id', _miId!);

      if (mounted) {
        List<Map<String, dynamic>> lista = [];
        for (var item in res) {
          final usuarioData = item['usuarios'];
          if (usuarioData != null) {
            lista.add({
              'id': item['paciente_id'],
              'nombre': usuarioData['nombre'] ?? 'Paciente sin nombre',
              'terminal_id': usuarioData['terminal_id'] ?? 'N/A',
            });
          }
        }

        setState(() {
          _pacientes = lista;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar pacientes: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ========================================================
  // LÓGICA DE CERRAR SESIÓN
  // ========================================================
  Future<void> _cerrarSesion() async {
    try {
      // 1. Cerramos sesión en Supabase
      await Supabase.instance.client.auth.signOut();
      
      // 2. Destruimos el historial y volvemos al Login
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PantallaLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cerrar sesión: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // ========================================================
  // LÓGICA PARA VINCULAR NUEVO PACIENTE
  // ========================================================
  void _mostrarDialogoVinculacion() {
    final terminalController = TextEditingController();
    final pinController = TextEditingController();
    bool vinculando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Vincular Nueva Tableta", style: TextStyle(color: colorPrimario, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Ingresa el ID de la terminal y el PIN de seguridad de tu familiar.", style: TextStyle(fontSize: 15)),
                const SizedBox(height: 20),
                TextField(
                  controller: terminalController,
                  decoration: InputDecoration(
                    labelText: "ID de Terminal (Ej. Manzana123)",
                    prefixIcon: const Icon(Icons.tablet_mac),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "PIN de Seguridad",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: vinculando ? null : () => Navigator.pop(context),
                child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: colorPrimario, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: vinculando ? null : () async {
                  final idIngresado = terminalController.text.trim();
                  final pinIngresado = pinController.text.trim();

                  if (idIngresado.isEmpty || pinIngresado.isEmpty) return;

                  setStateDialog(() => vinculando = true);

                  try {
                    // 1. Buscamos la terminal
                    final resTerminal = await Supabase.instance.client
                        .from('usuarios')
                        .select('id')
                        .eq('terminal_id', idIngresado)
                        .eq('pin', pinIngresado)
                        .maybeSingle();

                    if (resTerminal == null) {
                      throw "ID o PIN incorrectos";
                    }

                    final pacienteId = resTerminal['id'];

                    // 2. Creamos la vinculación
                    await Supabase.instance.client.from('vinculaciones').insert({
                      'cuidador_id': _miId,
                      'paciente_id': pacienteId,
                      'parentesco_especifico': 'Familiar',
                    });

                    if (mounted) {
                      Navigator.pop(context); // Cierra el dialog
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Tableta vinculada con éxito!"), backgroundColor: Colors.green));
                      _cargarPacientesVinculados(); // Refresca la lista
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  } finally {
                    if (mounted) setStateDialog(() => vinculando = false);
                  }
                },
                child: vinculando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Vincular", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: colorPrimario,
        title: const Text("Mis Pacientes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false, // Oculta la flecha de atrás
        actions: [
          // BOTÓN DE CERRAR SESIÓN IMPLEMENTADO
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Cerrar Sesión",
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text("Cerrar Sesión"),
                  content: const Text("¿Estás seguro de que deseas salir de tu cuenta?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () {
                        Navigator.pop(context); // Cierra el dialog
                        _cerrarSesion(); // Llama a la función de cierre
                      },
                      child: const Text("Salir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colorPrimario))
          : _pacientes.isEmpty
              ? _construirVistaVacia()
              : _construirListaPacientes(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorPrimario,
        onPressed: _mostrarDialogoVinculacion,
        icon: const Icon(Icons.add_link, color: Colors.white),
        label: const Text("Vincular Tableta", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _construirVistaVacia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              "Aún no cuidas a nadie",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            const Text(
              "Toca el botón de abajo para vincular la tableta de tu familiar usando su ID y PIN.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirListaPacientes() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pacientes.length,
      itemBuilder: (context, index) {
        final paciente = _pacientes[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // Navegar al panel de control de ese paciente
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PantallaInicio(
                    pacienteId: paciente['id'],
                    nombrePaciente: paciente['nombre'],
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.blue[100],
                    child: Icon(Icons.elderly, size: 40, color: colorPrimario),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paciente['nombre'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("Terminal: ${paciente['terminal_id']}", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}