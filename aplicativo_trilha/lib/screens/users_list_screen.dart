// lib/screens/users_list_screen.dart
import 'package:aplicativo_trilha/main.dart'; // Para acessar apiService
import 'package:flutter/material.dart';

class UsersListScreen extends StatefulWidget {
  final String titulo;
  final int? tipoPerfilFiltro; // 1=Trilheiro, 2=Guia/Op, 3=Admin

  const UsersListScreen({
    super.key,
    required this.titulo,
    this.tipoPerfilFiltro,
  });

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  bool _isLoading = true;
  List<dynamic> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    try {
      final lista = await apiService.getUsuarios(
        tipoPerfil: widget.tipoPerfilFiltro,
      );
      if (mounted) {
        setState(() {
          _usuarios = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.titulo, style: const TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            )
          : _usuarios.isEmpty
          ? const Center(
              child: Text(
                "Nenhum usuário encontrado.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _usuarios.length,
              itemBuilder: (context, index) {
                final user = _usuarios[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (user['url_foto_perfil'] != null)
                          ? NetworkImage(
                              '${apiService.baseUrl}/uploads/${user['url_foto_perfil']}',
                            )
                          : null,
                      child: user['url_foto_perfil'] == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    title: Text(
                      user['nome'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(user['email']),
                    trailing: const Icon(
                      Icons.info_outline,
                      color: Color(0xFF1B5E20),
                    ),
                    onTap: () => _mostrarDetalhesCompletos(user),
                  ),
                );
              },
            ),
    );
  }

  void _mostrarDetalhesCompletos(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.badge, color: Color(0xFF1B5E20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(user['nome'], style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow("ID Sistema", user['id'].toString()),
            _infoRow("E-mail", user['email']),
            _infoRow("Telefone", user['telefone'] ?? "Não informado"),
            _infoRow("Idade", user['idade']?.toString() ?? "-"),
            _infoRow("Sexo", user['sexo'] ?? "-"),
            const Divider(),
            _infoRow("Tipo Perfil", _traduzirPerfil(user['tipo_perfil'])),
            if (user['status_guia'] != null)
              _infoRow(
                "Status Guia",
                user['status_guia'].toString().toUpperCase(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Fechar",
              style: TextStyle(color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _traduzirPerfil(int? tipo) {
    switch (tipo) {
      case 1:
        return "Trilheiro";
      case 2:
        return "Guia/Operador";
      case 3:
        return "Administrador";
      default:
        return "Desconhecido";
    }
  }
}
