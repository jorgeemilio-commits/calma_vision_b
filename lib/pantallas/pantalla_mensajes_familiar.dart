import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PantallaMensajesFamiliar extends StatefulWidget {
  final String pacienteId; // ID del abuelo
  final String nombrePaciente;

  const PantallaMensajesFamiliar({
    super.key, 
    required this.pacienteId, 
    required this.nombrePaciente
  });

  @override
  State<PantallaMensajesFamiliar> createState() => _PantallaMensajesFamiliarState();
}

class _PantallaMensajesFamiliarState extends State<PantallaMensajesFamiliar> {
  final TextEditingController _mensajeController = TextEditingController();
  String? _miId;

  final Color colorPrimario = const Color(0xFF0047A0);

  @override
  void initState() {
    super.initState();
    _miId = Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _miId == null) return;

    _mensajeController.clear(); 

    try {
      await Supabase.instance.client.from('mensajes').insert({
        'emisor_id': _miId,
        'receptor_id': widget.pacienteId,
        'texto': texto,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo enviar: $e"), backgroundColor: Colors.red)
        );
      }
      debugPrint("Error al enviar mensaje: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), 
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.elderly, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text(widget.nombrePaciente, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ÁREA DE MENSAJES
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('mensajes')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorPrimario));
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Mándale un saludo a tu familiar.", style: TextStyle(color: Colors.black54)));
                }
                
                final mensajesDelChat = snapshot.data!.where((m) {
                  bool soyEmisor = m['emisor_id'] == _miId && m['receptor_id'] == widget.pacienteId;
                  bool soyReceptor = m['receptor_id'] == _miId && m['emisor_id'] == widget.pacienteId;
                  return soyEmisor || soyReceptor;
                }).toList();

                if(mensajesDelChat.isEmpty) {
                    return const Center(child: Text("Mándale un saludo a tu familiar.", style: TextStyle(color: Colors.black54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: mensajesDelChat.length,
                  itemBuilder: (context, index) {
                    var mensaje = mensajesDelChat[index];
                    bool esRecibido = mensaje['emisor_id'] != _miId; 
                    
                    return _globoTexto(mensaje["texto"], esRecibido);
                  },
                );
              },
            ),
          ),
          
          // BARRA DE ESCRITURA MÓVIL
          _barraEscritura(),
        ],
      ),
    );
  }

  Widget _globoTexto(String texto, bool esRecibido) {
    return Align(
      alignment: esRecibido ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), 
        decoration: BoxDecoration(
          color: esRecibido ? Colors.white : const Color(0xFFDCF8C6),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1))],
        ),
        child: Text(texto, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _barraEscritura() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]
              ),
              child: TextField(
                controller: _mensajeController, 
                decoration: const InputDecoration(
                  hintText: "Mensaje", 
                  border: InputBorder.none
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _enviarMensaje(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: colorPrimario,
            radius: 25,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _enviarMensaje,
            ),
          ),
        ],
      ),
    );
  }
}