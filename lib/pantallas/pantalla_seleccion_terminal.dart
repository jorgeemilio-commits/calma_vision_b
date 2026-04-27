import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_inicio.dart';

class PantallaSeleccionTerminal extends StatefulWidget {
  const PantallaSeleccionTerminal({super.key});

  @override
  State<PantallaSeleccionTerminal> createState() => _PantallaSeleccionTerminalState();
}

class _PantallaSeleccionTerminalState extends State<PantallaSeleccionTerminal> {
  List<dynamic> _terminales = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTerminales();
  }

  // --- CARGAR TERMINALES VINCULADAS ---
  Future<void> _cargarTerminales() async {
    setState(() => _cargando = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      // CORRECCIÓN 1: Usamos la tabla 'vinculaciones'
      final data = await Supabase.instance.client
          .from('vinculaciones')
          .select('paciente_id, usuarios(nombre, terminal_id)')
          .eq('cuidador_id', user.id);
      
      if (mounted) {
        setState(() {
          _terminales = data;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar terminales: $e");
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- MODAL DE VINCULACIÓN (TERMINAL ID + PIN) ---
  void _abrirAgregarTerminalModal() {
    final terminalIdCont = TextEditingController();
    final pinCont = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25))
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, 
          left: 25, right: 25, top: 30
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vincular Nueva Tableta", 
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontFamily: 'Roboto')
            ),
            const SizedBox(height: 10),
            const Text(
              "Ingresa el ID de la Terminal y el PIN que aparece en los ajustes de la tableta de tu familiar.", 
              style: TextStyle(color: Colors.blueGrey, fontSize: 15, fontFamily: 'Roboto')
            ),
            const SizedBox(height: 25),
            
            // CAMPO: TERMINAL ID
            TextField(
              controller: terminalIdCont, 
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: "ID de Terminal (ej. Pera9033)", 
                prefixIcon: const Icon(Icons.tablet_mac),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            const SizedBox(height: 15),
            
            // CAMPO: PIN DE SEGURIDAD
            TextField(
              controller: pinCont,
              keyboardType: TextInputType.number,
              maxLength: 8,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "PIN de Seguridad", 
                prefixIcon: const Icon(Icons.lock_person_outlined),
                counterText: "", 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ),
            ),
            
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () async {
                  try {
                    // 1. Buscamos a ver si existe una tableta con ese ID y PIN
                    final paciente = await Supabase.instance.client
                        .from('usuarios')
                        .select('id')
                        .eq('terminal_id', terminalIdCont.text.trim())
                        .eq('pin', pinCont.text.trim())
                        .maybeSingle(); // Usamos maybeSingle para controlar si no encuentra nada
                    
                    if (paciente == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("ID de Terminal o PIN incorrectos"), backgroundColor: Colors.orange)
                        );
                      }
                      return;
                    }

                    // CORRECCIÓN 2: Insertamos en la tabla 'vinculaciones' correcta
                    await Supabase.instance.client.from('vinculaciones').insert({
                      'cuidador_id': Supabase.instance.client.auth.currentUser!.id,
                      'paciente_id': paciente['id'],
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      _cargarTerminales(); // Recarga la lista
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Conexión establecida correctamente"), backgroundColor: Colors.green)
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      // Ahora sí veremos el error real (RLS, Duplicados, etc.)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error al vincular: $e"), backgroundColor: Colors.redAccent)
                      );
                      debugPrint(e.toString());
                    }
                  }
                }, 
                child: const Text(
                  "Verificar y Conectar", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                )
              ),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  // --- DISEÑO DE LA PANTALLA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Mis Familiares", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Roboto')), 
        backgroundColor: Colors.white, 
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: false,
      ),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                const SizedBox(height: 10),
                const Text(
                  "Terminales Conectadas", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey, fontFamily: 'Roboto')
                ),
                const SizedBox(height: 15),
                
                if (_terminales.isEmpty)
                  _construirEstadoVacio()
                else
                  ..._terminales.map((t) => _construirTarjetaTerminal(t)),
                
                const SizedBox(height: 25),
                
                OutlinedButton.icon(
                  onPressed: _abrirAgregarTerminalModal, 
                  icon: const Icon(Icons.add_link, size: 24), 
                  label: const Text("Vincular Nueva Tableta", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A90E2),
                    side: const BorderSide(color: Color(0xFF4A90E2), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                ),
              ],
            ),
    );
  }

  Widget _construirTarjetaTerminal(Map<String, dynamic> t) {
    // Protección por si la data relacional viene nula
    final nombre = t['usuarios']?['nombre'] ?? 'Desconocido';
    final terminalId = t['usuarios']?['terminal_id'] ?? 'Desconocido';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withOpacity(0.1), 
            shape: BoxShape.circle
          ),
          child: const Icon(Icons.elderly, color: Color(0xFF4A90E2), size: 28),
        ),
        title: Text(
          nombre, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF2C3E50), fontFamily: 'Roboto')
        ),
        subtitle: Text(
          "ID Terminal: $terminalId", 
          style: const TextStyle(color: Colors.blueGrey, fontSize: 14)
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 22),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => PantallaInicio(
            pacienteId: t['paciente_id'], 
            nombrePaciente: nombre
          )
        )),
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.tablet_mac_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "No hay tabletas vinculadas", 
            style: TextStyle(color: Colors.blueGrey, fontSize: 18, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}