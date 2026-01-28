// lib/screens/schedule_management_screen.dart

import 'package:aplicativo_trilha/main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _pendentes = [];
  List<dynamic> _listaGuias = [];
  String _erro = "";

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.getAgendamentosPendentes(),
        apiService.getUsuarios(tipoPerfil: 2),
      ]);

      if (mounted) {
        setState(() {
          _pendentes = results[0];
          _listaGuias = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = "Erro de conexão: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _atribuirGuia(
    int agendamentoId,
    int guiaId,
    String nomeGuia,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await apiService.atribuirGuia(agendamentoId, guiaId);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Trilha atribuída ao guia $nomeGuia!"),
            backgroundColor: Colors.green,
          ),
        );
        _carregarDadosIniciais();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirModalAtribuicao(Map<String, dynamic> item) {
    int? guiaSelecionado;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Selecionar Profissional",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Trilha: ${item['nome_trilha']}",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              if (_listaGuias.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text("Nenhum guia cadastrado no sistema."),
                  ),
                )
              else
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: "Guia Disponível",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_search),
                  ),
                  items: _listaGuias.map<DropdownMenuItem<int>>((guia) {
                    return DropdownMenuItem(
                      value: guia['id'],
                      child: Text(guia['nome']),
                    );
                  }).toList(),
                  onChanged: (val) => guiaSelecionado = val,
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    if (guiaSelecionado != null) {
                      final guia = _listaGuias.firstWhere(
                        (g) => g['id'] == guiaSelecionado,
                      );
                      _atribuirGuia(item['id'], guiaSelecionado!, guia['nome']);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Selecione um guia.")),
                      );
                    }
                  },
                  child: const Text("CONFIRMAR ATRIBUIÇÃO"),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Gestão de Solicitações"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDadosIniciais,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erro.isNotEmpty
          ? _buildErrorState()
          : _pendentes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendentes.length,
              itemBuilder: (context, index) =>
                  _buildRequestCard(_pendentes[index]),
            ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final data = DateTime.parse(item['data_agendada']);
    final bool temNotas =
        item['notas'] != null && item['notas'].toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_filled,
                  size: 16,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat("dd/MM/yyyy 'às' HH:mm").format(data),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    "PENDENTE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: item['foto_trilheiro'] != null
                      ? CachedNetworkImageProvider(
                          item['foto_trilheiro'].startsWith('http')
                              ? item['foto_trilheiro']
                              : '${apiService.baseUrl}/uploads/${item['foto_trilheiro']}',
                        )
                      : null,
                  child: item['foto_trilheiro'] == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['nome_trilha'] ?? "Trilha Sem Nome",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Cliente: ${item['nome_trilheiro']}",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTag(
                            item['dificuldade'],
                            Colors.blue[100]!,
                            Colors.blue[900]!,
                          ),
                          const SizedBox(width: 8),
                          _buildTag(
                            "${item['duracao_estimada_min']} min",
                            Colors.grey[200]!,
                            Colors.black87,
                          ),
                        ],
                      ),

                      if (temNotas) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.yellow[50],
                            border: Border.all(color: Colors.yellow[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.note,
                                size: 14,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item['notas'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          InkWell(
            onTap: () => _abrirModalAtribuicao(item),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                "ATRIBUIR GUIA",
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[200]),
          const SizedBox(height: 16),
          const Text(
            "Tudo em ordem!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const Text("Nenhuma solicitação pendente no momento."),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Não foi possível conectar",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Verifique sua conexão ou se o servidor está online.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarDadosIniciais, // Tenta recarregar
              icon: const Icon(Icons.refresh),
              label: const Text("TENTAR NOVAMENTE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
