// lib/screens/start_trail_form_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class StartTrailFormScreen extends StatefulWidget {
  const StartTrailFormScreen({super.key});

  @override
  State<StartTrailFormScreen> createState() => _StartTrailFormScreenState();
}

class _StartTrailFormScreenState extends State<StartTrailFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeTrilhaController = TextEditingController();
  final TextEditingController _duracaoController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();

  String _dificuldadeSelecionada = 'Fácil';
  String _tipoSelecionado = 'Individual';
  bool _solicitarGuia = false;
  DateTime? _dataAgendamento;
  final List<Map<String, dynamic>> _participantesSelecionados = [];

  bool _isLoading = false;

  void _abrirPopupAdicionarParticipante() async {
    setState(() => _isLoading = true);
    List<dynamic> todosUsuarios = [];

    try {
      todosUsuarios = await apiService.getUsuarios(tipoPerfil: 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar usuários: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String termoBusca = "";
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final usuariosFiltrados = todosUsuarios.where((u) {
              final nome = u['nome'].toString().toLowerCase();
              final email = u['email'].toString().toLowerCase();
              return nome.contains(termoBusca.toLowerCase()) ||
                  email.contains(termoBusca.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text("Adicionar Participante"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Nome ou E-mail...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) =>
                          setStateDialog(() => termoBusca = val),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: usuariosFiltrados.isEmpty && termoBusca.isNotEmpty
                          ? _buildBotaoAdicionarExterno(termoBusca)
                          : ListView.separated(
                              itemCount: usuariosFiltrados.length,
                              separatorBuilder: (c, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final user = usuariosFiltrados[index];
                                final jaAdicionado = _participantesSelecionados
                                    .any((p) => p['id'] == user['id']);
                                final fotoUrl = user['url_foto_perfil'];

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: (fotoUrl != null)
                                        ? CachedNetworkImageProvider(
                                            fotoUrl.startsWith('http')
                                                ? fotoUrl
                                                : '${apiService.baseUrl}/uploads/$fotoUrl',
                                          )
                                        : null,
                                    child: fotoUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(user['nome']),
                                  subtitle: Text(user['email']),
                                  trailing: jaAdicionado
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                      : const Icon(Icons.add_circle_outline),
                                  onTap: jaAdicionado
                                      ? null
                                      : () {
                                          setState(() {
                                            _participantesSelecionados.add({
                                              'id': user['id'],
                                              'nome': user['nome'],
                                              'tipo': 'app',
                                              'foto': fotoUrl,
                                            });
                                          });
                                          Navigator.pop(context);
                                        },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Fechar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBotaoAdicionarExterno(String nomeDigitado) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person_off, size: 40, color: Colors.orange),
        const SizedBox(height: 10),
        Text("'$nomeDigitado' não encontrado."),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _participantesSelecionados.add({
                'id': null,
                'nome': nomeDigitado,
                'tipo': 'externo',
                'foto': null,
              });
            });
            Navigator.pop(context);
          },
          icon: const Icon(Icons.person_add),
          label: const Text("Adicionar como Convidado Externo"),
        ),
      ],
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _dataAgendamento = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_solicitarGuia && _dataAgendamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Defina a data para o agendamento do Guia.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await authService.getLoggedInUserId();
      if (userId == null) throw Exception('Usuário não está logado.');

      final internos = _participantesSelecionados
          .where((p) => p['tipo'] == 'app')
          .map((p) => p['id'])
          .toList();
      final externos = _participantesSelecionados
          .where((p) => p['tipo'] == 'externo')
          .map((p) => p['nome'])
          .toList();

      final Map<String, dynamic> dadosTrilha = {
        'id_usuario_lider': int.parse(userId),
        'nome': _nomeTrilhaController.text,
        'dificuldade': _dificuldadeSelecionada,
        'tipo': _tipoSelecionado,
        'duracao_estimada': _duracaoController.text,
        'notas': _notasController.text,
        'participantes_ids': internos,
        'participantes_externos': externos,
        'solicitar_guia': _solicitarGuia,
        'data_agendada': _dataAgendamento?.toIso8601String(),
      };

      final response = await apiService.iniciarTrilha(dadosTrilha);
      final novaTrilhaId = response['trilha_id'];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trilha ID $novaTrilhaId iniciada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, novaTrilhaId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar trilha: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Nova Trilha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preencha os dados da sua atividade',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nomeTrilhaController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Trilha (ex: Minha Caminhada)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.isEmpty ?? true) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Dificuldade',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _dificuldadeSelecionada,
                      items: ['Fácil', 'Média', 'Difícil', 'Extrema']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _dificuldadeSelecionada = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _duracaoController,
                      decoration: const InputDecoration(
                        labelText: 'Duração (min)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) =>
                          (v?.isEmpty ?? true) ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Modalidade",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Individual',
                    label: Text('Individual'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment(
                    value: 'Grupo',
                    label: Text('Grupo'),
                    icon: Icon(Icons.groups),
                  ),
                ],
                selected: {_tipoSelecionado},
                emptySelectionAllowed: false,
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    if (newSelection.isNotEmpty) {
                      _tipoSelecionado = newSelection.first;
                      if (_tipoSelecionado == 'Individual')
                        _participantesSelecionados.clear();
                    }
                  });
                },
              ),

              if (_tipoSelecionado == 'Grupo') ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _abrirPopupAdicionarParticipante,
                  icon: const Icon(Icons.person_add),
                  label: const Text("Adicionar Participante"),
                ),
                Wrap(
                  spacing: 8.0,
                  children: _participantesSelecionados.map((p) {
                    final isExterno = p['tipo'] == 'externo';
                    return Chip(
                      label: Text(p['nome'] + (isExterno ? " (Ext)" : "")),
                      avatar: isExterno
                          ? const Icon(Icons.person_outline)
                          : const Icon(Icons.face),
                      backgroundColor: isExterno
                          ? Colors.orange[100]
                          : Colors.blue[100],
                      onDeleted: () =>
                          setState(() => _participantesSelecionados.remove(p)),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Solicitar Guia Profissional?"),
                      value: _solicitarGuia,
                      onChanged: (val) => setState(() {
                        _solicitarGuia = val;
                        if (!val) _dataAgendamento = null;
                      }),
                    ),
                    if (_solicitarGuia)
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          _dataAgendamento == null
                              ? "Toque para agendar data/hora"
                              : DateFormat(
                                  'dd/MM HH:mm',
                                ).format(_dataAgendamento!),
                        ),
                        onTap: _pickDateTime,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas (ex: Levarei lanterna)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('INICIAR TRILHA'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
