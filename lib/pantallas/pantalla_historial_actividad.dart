import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PantallaHistorialActividad extends StatelessWidget {
  final String pacienteId;
  const PantallaHistorialActividad({super.key, required this.pacienteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FEFF),
      appBar: AppBar(title: const Text("Historial de Actividad"), backgroundColor: Colors.white, foregroundColor: const Color(0xFF0047A0), elevation: 0),
      body: FutureBuilder(
        future: Supabase.instance.client.from('actividad_reciente').select().eq('paciente_id', pacienteId).order('created_at', ascending: false).limit(50),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final datos = snapshot.data as List;
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: datos.length,
            itemBuilder: (context, i) {
              final a = datos[i];
              final fecha = DateTime.parse(a['created_at']).toLocal();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(a['mensaje']),
                  subtitle: Text(DateFormat('dd/MM/yyyy - HH:mm').format(fecha)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}