import 'package:flutter/material.dart';

class PantallaInicio extends StatelessWidget {
  final String pacienteId;
  final String nombrePaciente;
  
  const PantallaInicio({super.key, required this.pacienteId, required this.nombrePaciente});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cuidando a $nombrePaciente"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text("Menú Principal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text("Aquí aparecerán las opciones para ver medicinas, notas y galería en tiempo real.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}