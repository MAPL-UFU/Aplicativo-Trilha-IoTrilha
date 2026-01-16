// lib/screens/guide_screen.dart
// ignore_for_file: unused_field

import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/widgets/guide_drawer.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _guiaId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarGuiaId();
  }

  Future<void> _carregarGuiaId() async {
    final userData = await authService.getUserData();
    if (mounted) {
      setState(() {
        _guiaId = int.tryParse(userData['user_id'] ?? '0');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const GuideDrawer(),
      appBar: AppBar(
        backgroundColor: Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Painel do Guia',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: "Chat",
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Chat em breve"))),
          ),
        ],
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.white,
          indicatorWeight: 4.0,
          indicatorSize: TabBarIndicatorSize.tab,
          controller: _tabController,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: "Verificar"),
            Tab(icon: Icon(Icons.calendar_month), text: "Agenda"),
            Tab(icon: Icon(Icons.dashboard), text: "Gestão"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const VerificationTabContent(),

          _guiaId == null
              ? const Center(child: CircularProgressIndicator())
              : GuideAgendaTab(guiaId: _guiaId!),

          _guiaId == null
              ? const Center(child: CircularProgressIndicator())
              : GuideStatsTab(guiaId: _guiaId!),
        ],
      ),
    );
  }
}

class VerificationTabContent extends StatefulWidget {
  const VerificationTabContent({super.key});

  @override
  State<VerificationTabContent> createState() => _VerificationTabContentState();
}

class _VerificationTabContentState extends State<VerificationTabContent> {
  final TextEditingController _tagIdController = TextEditingController();
  bool _isLoading = false;
  bool _isNfcScanning = false;
  String _tagSolicitada = "";
  List<dynamic> _passaramPorAqui = [];
  String _erro = "";

  Future<void> _fetchTagData({int? idOpcional}) async {
    final int? tagId = idOpcional ?? int.tryParse(_tagIdController.text);
    if (tagId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Informe um ID válido.")));
      return;
    }
    if (idOpcional != null) _tagIdController.text = idOpcional.toString();

    setState(() {
      _isLoading = true;
      _erro = "";
      _passaramPorAqui = [];
    });

    try {
      final data = await apiService.getEventosPorTag(tagId);
      if (mounted) {
        setState(() {
          _tagSolicitada = data['tag_solicitada'].toString();
          _passaramPorAqui = data['passaram_por_aqui'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _erro = "Erro: $e";
          _isLoading = false;
        });
    }
  }

  Future<void> _lerNfc() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("NFC desativado.")));
      return;
    }
    setState(() => _isNfcScanning = true);
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            final nfcData = await nfcService.readTagData(tag);
            await NfcManager.instance.stopSession();
            if (nfcData.logicalId != null) {
              if (mounted) {
                setState(() => _isNfcScanning = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Tag ${nfcData.logicalId} lida!")),
                );
                _fetchTagData(idOpcional: nfcData.logicalId);
              }
            } else {
              if (mounted) {
                setState(() => _isNfcScanning = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tag inválida."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (mounted) setState(() => _isNfcScanning = false);
          }
        },
      );
    } catch (e) {
      setState(() => _isNfcScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID da Tag',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_isNfcScanning,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isNfcScanning ? null : () => _fetchTagData(),
                icon: const Icon(Icons.search),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _isNfcScanning ? null : () => _fetchTagData(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isNfcScanning ? null : _lerNfc,
              icon: _isNfcScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.nfc),
              label: Text(_isNfcScanning ? "APROXIME..." : "LER COM NFC"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isNfcScanning
                    ? Colors.orange
                    : Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const Divider(height: 30),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _erro.isNotEmpty
                ? Center(
                    child: Text(
                      _erro,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _buildListaResultados(),
          ),
        ],
      ),
    );
  }

  Widget _buildListaResultados() {
    if (_passaramPorAqui.isEmpty)
      return const Center(child: Text('Nenhum registro encontrado.'));
    return ListView.builder(
      itemCount: _passaramPorAqui.length,
      itemBuilder: (context, index) {
        final evento = _passaramPorAqui[index];
        return Card(
          elevation: 2,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1B5E20),
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              evento['nome_usuario'] ?? 'Desconhecido',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Horário: ${evento['timestamp_leitura']}\nDireção: ${evento['direcao']}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class GuideAgendaTab extends StatefulWidget {
  final int guiaId;
  const GuideAgendaTab({super.key, required this.guiaId});

  @override
  State<GuideAgendaTab> createState() => _GuideAgendaTabState();
}

class _GuideAgendaTabState extends State<GuideAgendaTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _agendamentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _carregarAgenda();
  }

  Future<void> _carregarAgenda() async {
    setState(() => _isLoading = true);
    try {
      final dados = await apiService.getAgendamentosGuia(widget.guiaId);
      if (mounted) {
        setState(() {
          _agendamentos = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getEventosDoDia(DateTime dia) {
    return _agendamentos.where((ag) {
      final dataAg = DateTime.parse(ag['data_agendada']);
      return isSameDay(dataAg, dia);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          flex: 55,
          child: Card(
            margin: const EdgeInsets.all(8),
            elevation: 2,
            child: TableCalendar(
              locale: 'pt_BR',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              eventLoader: _getEventosDoDia,
              calendarStyle: const CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF1B5E20),
                  shape: BoxShape.circle,
                ),
                cellMargin: EdgeInsets.all(2.0),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              shouldFillViewport: true,
            ),
          ),
        ),

        const Divider(height: 1, thickness: 2),

        Expanded(
          flex: 45,
          child: Container(
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Agendamentos de ${DateFormat('dd/MM').format(_selectedDay!)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(child: _buildListaDoDia()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaDoDia() {
    final eventos = _getEventosDoDia(_selectedDay!);
    if (eventos.isEmpty) {
      return const Center(
        child: Text(
          "Dia livre! Sem agendamentos.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: eventos.length,
      itemBuilder: (c, i) {
        final ev = eventos[i];
        final data = DateTime.parse(ev['data_agendada']);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text(
                DateFormat('HH:mm').format(data),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(ev['nome_trilha']),
            subtitle: Text("Cliente: ${ev['nome_trilheiro']}"),
            trailing: Chip(
              label: Text(
                ev['status'],
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: _getStatusColor(ev['status']),
              padding: EdgeInsets.zero,
            ),
            onTap: () => _mostrarDetalhes(context, ev),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmado':
        return Colors.blue;
      case 'pendente':
        return Colors.orange;
      case 'concluido':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class GuideStatsTab extends StatefulWidget {
  final int guiaId;
  const GuideStatsTab({super.key, required this.guiaId});

  @override
  State<GuideStatsTab> createState() => _GuideStatsTabState();
}

class _GuideStatsTabState extends State<GuideStatsTab> {
  bool _isLoading = true;
  List<dynamic> _agendamentos = [];
  List<dynamic> _concluidas = [];
  List<dynamic> _atual = [];
  List<dynamic> _solicitacoes = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final dados = await apiService.getAgendamentosGuia(widget.guiaId);
      if (mounted) {
        setState(() {
          _agendamentos = dados;
          _concluidas = dados.where((a) => a['status'] == 'concluido').toList();
          _solicitacoes = dados
              .where((a) => a['status'] == 'pendente')
              .toList();

          final hoje = DateTime.now();
          _atual = dados.where((a) {
            if (a['status'] != 'confirmado' && a['status'] != 'em_andamento')
              return false;
            final dataAg = DateTime.parse(a['data_agendada']);
            return isSameDay(dataAg, hoje);
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getProximaTrilhaImediata() {
    final agora = DateTime.now();
    final futuras = _agendamentos.where((a) {
      if (a['status'] != 'confirmado') return false;
      final dataAg = DateTime.parse(a['data_agendada']);
      return dataAg.isAfter(agora);
    }).toList();

    futuras.sort(
      (a, b) => DateTime.parse(
        a['data_agendada'],
      ).compareTo(DateTime.parse(b['data_agendada'])),
    );

    if (futuras.isEmpty) return null;
    final proxima = futuras.first;
    final diff = DateTime.parse(
      proxima['data_agendada'],
    ).difference(agora).inMinutes;

    if (diff <= 60) return {...proxima, 'minutos_restantes': diff};
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final proxima = _getProximaTrilhaImediata();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAlertCard(proxima),
          const SizedBox(height: 20),

          const Text(
            "Gerenciamento",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          _buildExpandableCard(
            "Solicitações Pendentes",
            Icons.notifications_active,
            Colors.redAccent,
            _solicitacoes,
          ),
          _buildExpandableCard(
            "Trilha do Dia (Atual)",
            Icons.hiking,
            Colors.blue,
            _atual,
          ),
          _buildExpandableCard(
            "Histórico Concluído",
            Icons.check_circle,
            Colors.green,
            _concluidas,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic>? proxima) {
    bool temAlerta = proxima != null;
    return Card(
      color: temAlerta ? Colors.orange[50] : Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: temAlerta ? Colors.orange : Colors.green),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              temAlerta ? Icons.access_alarm : Icons.thumb_up,
              size: 40,
              color: temAlerta ? Colors.deepOrange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              temAlerta
                  ? "Sua Próxima Trilha Começa em Breve!"
                  : "Tudo tranquilo por aqui.",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (temAlerta) ...[
              const SizedBox(height: 4),
              Text(
                "Faltam ${proxima['minutos_restantes']} minutos para iniciar.",
                style: const TextStyle(color: Colors.deepOrange),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _mostrarDetalhes(context, proxima),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text(
                  "VER DETALHES",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCard(
    String title,
    IconData icon,
    Color color,
    List<dynamic> lista,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: lista.isNotEmpty ? color : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${lista.length}",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        children: lista.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Nenhum registro encontrado."),
                ),
              ]
            : lista
                  .map(
                    (item) => ListTile(
                      title: Text(item['nome_trilha']),
                      subtitle: Text(
                        DateFormat(
                          'dd/MM - HH:mm',
                        ).format(DateTime.parse(item['data_agendada'])),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _mostrarDetalhes(context, item),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}

void _mostrarDetalhes(BuildContext context, Map<String, dynamic> item) {
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(item['nome_trilha']),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow("Cliente:", item['nome_trilheiro']),
          _infoRow(
            "Data:",
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(DateTime.parse(item['data_agendada'])),
          ),
          _infoRow("Dificuldade:", item['dificuldade']),
          const SizedBox(height: 10),
          if (item['status'] == 'pendente')
            const Text(
              "⚠️ Esta trilha aguarda sua confirmação.",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text("Fechar"),
        ),
        if (item['status'] == 'confirmado')
          ElevatedButton(onPressed: () {}, child: const Text("INICIAR TRILHA")),
      ],
    ),
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
