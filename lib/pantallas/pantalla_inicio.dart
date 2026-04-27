import 'package:flutter/material.dart';

class PantallaInicio extends StatelessWidget {
  final String pacienteId;
  final String nombrePaciente;

  const PantallaInicio({
    super.key,
    required this.pacienteId,
    required this.nombrePaciente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(nombrePaciente, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Panel de Control", 
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50), fontFamily: 'Roboto')
            ),
            const SizedBox(height: 5),
            Text(
              "Gestiona y monitorea la tableta de $nombrePaciente", 
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey)
            ),
            const SizedBox(height: 35),
            
            // MENÚ DE CUADRÍCULA
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2 columnas
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.0, // Cuadrados perfectos
                children: [
                  _construirTarjetaMenu(
                    context, 
                    "Medicinas", 
                    Icons.medical_information_outlined, 
                    Colors.redAccent, 
                    () {
                      // TODO: Navegar a PantallaMedicinasFamiliar(pacienteId: pacienteId)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                  _construirTarjetaMenu(
                    context, 
                    "Agenda", 
                    Icons.calendar_month_outlined, 
                    Colors.orange, 
                    () {
                      // TODO: Navegar a PantallaAgendaFamiliar
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                  _construirTarjetaMenu(
                    context, 
                    "Galería", 
                    Icons.photo_library_outlined, 
                    Colors.purple, 
                    () {
                      // TODO: Navegar a PantallaGaleriaFamiliar
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                  _construirTarjetaMenu(
                    context, 
                    "Mensajes", 
                    Icons.chat_bubble_outline, 
                    Colors.green, 
                    () {
                      // TODO: Navegar a PantallaMensajesFamiliar
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                  _construirTarjetaMenu(
                    context, 
                    "Llamar", 
                    Icons.video_camera_front_outlined, 
                    const Color(0xFF4A90E2), 
                    () {
                      // TODO: Iniciar lógica de videollamada
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                  _construirTarjetaMenu(
                    context, 
                    "Ajustes", 
                    Icons.settings_outlined, 
                    Colors.blueGrey, 
                    () {
                      // TODO: Ver información de la tableta / Desvincular
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Módulo en construcción")));
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET REUTILIZABLE PARA LAS TARJETAS DEL MENÚ
  Widget _construirTarjetaMenu(BuildContext context, String titulo, IconData icono, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 38, color: color),
              ),
              const SizedBox(height: 15),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 17, 
                  fontWeight: FontWeight.bold, 
                  color: Color(0xFF2C3E50),
                  fontFamily: 'Roboto'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}