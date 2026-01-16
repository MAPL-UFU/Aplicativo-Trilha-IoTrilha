// lib/screens/tag_manager_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/services/nfc_service.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';

class TagManagerScreen extends StatefulWidget {
  const TagManagerScreen({super.key});

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  bool _isScanning = false;
  bool _isProcessing = false;
  int? _idPendente;

  String _statusMsg = "Toque em 'Analisar' e aproxime uma tag.";
  TagDiagnosis? _diagnosis;
  List<dynamic> _tagsCadastradas = [];

  @override
  void initState() {
    super.initState();
    _carregarListaTags();
  }

  Future<void> _carregarListaTags() async {
    try {
      final tags = await apiService.getTagsFisicas();
      if (mounted) {
        setState(() {
          _tagsCadastradas = tags;
        });
      }
    } catch (e) {
      print("Erro ao carregar lista: $e");
    }
  }

  void _startAnalysis() async {
    if (_isProcessing || _isScanning) return;
    if (_idPendente != null) {
      setState(
        () => _statusMsg =
            "Resolva a pendência do ID $_idPendente antes de ler outra tag.",
      );
      return;
    }

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() => _statusMsg = "NFC desativado no celular.");
      return;
    }

    setState(() {
      _isScanning = true;
      _diagnosis = null;
      _statusMsg = "Aproxime a tag para ler...";
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final diagnosis = await nfcService.checkTagStatus(tag);

          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}

          if (mounted) {
            setState(() {
              _diagnosis = diagnosis;
              _isScanning = false;
              _statusMsg = "Leitura concluída.";
            });
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _iniciarGravacaoComGps() async {
    final TextEditingController _idController = TextEditingController();
    final String? userId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Vincular Tag a Usuário"),
        content: TextField(
          controller: _idController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "ID do Usuário",
            hintText: "Ex: 15",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _idController.text),
            child: const Text("Gravar"),
          ),
        ],
      ),
    );

    if (userId == null || userId.isEmpty) return;

    setState(() {
      _isScanning = true;
      _statusMsg = "Obtendo GPS...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permissão de GPS negada.");
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _statusMsg =
            "GPS OK! Aproxime a Tag para gravar.\nID: $userId\nLoc: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
      });

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final success = await nfcService.writeOperatorTag(
            tag,
            userId: userId,
            lat: position.latitude,
            lon: position.longitude,
          );

          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}

          if (mounted) {
            setState(() {
              _isScanning = false;
              _statusMsg = success
                  ? "SUCESSO! Tag vinculada ao User $userId na posição atual."
                  : "ERRO ao gravar na tag.";
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success ? "Tag Gravada com Sucesso!" : "Falha na gravação",
                ),
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = "Erro ao iniciar processo: $e";
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _provisionarTag() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMsg = _idPendente != null
          ? "Tentando gravar novamente o ID $_idPendente..."
          : "Gerando novo ID no servidor...";
    });

    int? idParaGravar;

    try {
      if (_idPendente != null) {
        idParaGravar = _idPendente;
      } else {
        idParaGravar = await apiService.provisionarTag("manual_via_app");
      }

      if (!mounted) return;
      setState(
        () => _statusMsg =
            "ID $idParaGravar pronto. APROXIME A TAG PARA GRAVAR...",
      );

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final success = await nfcService.formatTag(tag, idParaGravar!);

          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}

          if (!success) {
            if (mounted) {
              setState(() {
                _idPendente = idParaGravar;
                _statusMsg =
                    "Falha ao gravar ID $idParaGravar. Tente novamente ou cancele.";
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _statusMsg = "SUCESSO! Tag gravada com ID $idParaGravar.";
                _diagnosis = null;
                _idPendente = null;
              });
              _carregarListaTags();
            }
          }

          if (mounted) setState(() => _isProcessing = false);
        },
      );
    } catch (e) {
      setState(() {
        _statusMsg = "Erro de conexão: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _cancelarPendencia() async {
    if (_idPendente == null) return;

    setState(() => _isProcessing = true);

    try {
      await apiService.deletarTag(_idPendente!);

      if (mounted) {
        setState(() {
          _statusMsg = "ID $_idPendente cancelado e removido do banco.";
          _idPendente = null;
        });
        _carregarListaTags();
      }
    } catch (e) {
      if (mounted) setState(() => _statusMsg = "Erro ao cancelar: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _limparTag() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMsg = "Aproxime a tag para LIMPAR dados...";
    });

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final success = await nfcService.cleanTagData(tag);
          try {
            await NfcManager.instance.stopSession();
          } catch (_) {}

          if (mounted) {
            setState(() {
              _isProcessing = false;
              _diagnosis = null;
              _statusMsg = success
                  ? "Tag formatada (limpa) com sucesso!"
                  : "Falha ao limpar tag.";
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMsg = "Erro ao tentar limpar: $e";
        });
      }
    }
  }

  Future<void> _deletarTagManual(int id) async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Apagar Tag $id?"),
        content: const Text(
          "Isso remove o registro do banco. A tag física precisará ser reformatada para ser usada novamente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              "Apagar Definitivamente",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      await apiService.deletarTag(id);
      await _carregarListaTags();
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Registro apagado.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Gerenciador de Tags",
          style: TextStyle(color: Colors.white),
        ),

        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isProcessing
                          ? Colors.yellow[100]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: _isProcessing
                          ? Border.all(color: Colors.orange)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing || _isScanning) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            _statusMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isProcessing &&
                      !_isScanning &&
                      _diagnosis == null &&
                      _idPendente == null)
                    ElevatedButton.icon(
                      onPressed: _startAnalysis,
                      icon: const Icon(Icons.nfc),
                      label: const Text("ANALISAR TAG"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    "OPERAÇÕES DE CAMPO",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _iniciarGravacaoComGps,
                      icon: const Icon(Icons.gps_fixed),
                      label: const Text("VINCULAR TAG (COM GPS ATUAL)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  if (_diagnosis != null || _idPendente != null) ...[
                    if (_diagnosis != null && _idPendente == null) ...[
                      const SizedBox(height: 20),
                      _buildDiagnosisCard(),
                    ],
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ),
          const Divider(thickness: 2),

          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Tags Ativas no Banco",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isProcessing ? null : _carregarListaTags,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tagsCadastradas.isEmpty
                        ? const Center(
                            child: Text(
                              "Nenhuma tag cadastrada.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _tagsCadastradas.length,
                            itemBuilder: (context, index) {
                              final tag = _tagsCadastradas[index];
                              final numeroSequencial = index + 1;

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  visualDensity: VisualDensity.compact,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0xFF1B5E20),
                                    child: Text(
                                      "$numeroSequencial",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    "ID Lógico: ${tag['id']}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    tag['criado_em'] ?? '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _deletarTagManual(tag['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard() {
    String titulo = "";
    Color cor = Colors.grey;
    IconData icone = Icons.help;

    switch (_diagnosis!.status) {
      case TagStatus.formatted_valid:
        titulo = "Tag Válida (ID: ${_diagnosis!.logicalId})";
        cor = Color(0xFF1B5E20);
        icone = Icons.check_circle;
        break;
      case TagStatus.empty_formatable:
        titulo = "Tag Virgem (Sem dados)";
        cor = Colors.orange;
        icone = Icons.new_releases;
        break;
      case TagStatus.formatted_invalid:
        titulo = "Tag Inválida / Dados Corrompidos";
        cor = Colors.red;
        icone = Icons.warning;
        break;
      case TagStatus.unknown:
        titulo = "Leitura Falhou";
        cor = Colors.purple;
        icone = Icons.question_mark;
        break;
      default:
        titulo = "Erro";
        cor = Colors.red;
        icone = Icons.error;
    }
    return Card(
      color: cor.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icone, color: cor, size: 40),
        title: Text(
          titulo,
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: const Text("Selecione uma ação abaixo:"),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isProcessing) {
      return const Center(
        child: Text(
          "Processando... Por favor, aguarde.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (_idPendente != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  "Atenção: O ID $_idPendente foi gerado mas a gravação falhou.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.brown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Deseja tentar gravar este mesmo ID novamente ou descartá-lo?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.brown, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text("TENTAR GRAVAR ID $_idPendente NOVAMENTE"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: _provisionarTag,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: Text("Descartar ID $_idPendente (Apagar do Banco)"),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _cancelarPendencia,
          ),
        ],
      );
    }

    switch (_diagnosis!.status) {
      case TagStatus.empty_formatable:
      case TagStatus.formatted_invalid:
      case TagStatus.unknown:
        return Column(
          children: [
            ElevatedButton.icon(
              onPressed: _provisionarTag,
              icon: const Icon(Icons.save),
              label: const Text("FORMATAR (CRIAR NOVO ID)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _startAnalysis,
              child: const Text("Cancelar e Ler Outra Tag"),
            ),
          ],
        );

      case TagStatus.formatted_valid:
        return Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.nfc_outlined),
              label: const Text("LER PRÓXIMA TAG"),
              onPressed: _startAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                elevation: 4,
              ),
            ),

            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "MANUTENÇÃO",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text("Limpar"),
                    onPressed: _limparTag,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reformatar"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _provisionarTag,
                  ),
                ),
              ],
            ),
          ],
        );

      default:
        return OutlinedButton(
          onPressed: _startAnalysis,
          child: const Text("Tentar Novamente"),
        );
    }
  }
}
