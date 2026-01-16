// lib/widgets/nfc_interaction_dialog.dart
import 'dart:async';
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/models/nfc_read_result.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:latlong2/latlong.dart';

enum NfcStatus { ready, processing, success, error }

class NfcInteractionDialog extends StatefulWidget {
  final LatLng? userLocation;

  const NfcInteractionDialog({super.key, this.userLocation});

  @override
  State<NfcInteractionDialog> createState() => _NfcInteractionDialogState();
}

class _NfcInteractionDialogState extends State<NfcInteractionDialog> {
  NfcStatus _status = NfcStatus.ready;
  String _message = "Aproxime o celular da Tag ...";

  @override
  void initState() {
    super.initState();
    _startNfcSession();
  }

  Future<void> _startNfcSession() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() {
        _status = NfcStatus.error;
        _message = "NFC desativado ou indisponível.";
      });
      return;
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: _onNfcDiscovered,
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      );
    } catch (e) {
      setState(() {
        _status = NfcStatus.error;
        _message = "Erro ao iniciar sessão NFC: $e";
      });
      await _stopSessionAfterDelay(success: false);
    }
  }

  Future<void> _onNfcDiscovered(NfcTag tag) async {
    if (_status == NfcStatus.processing || _status == NfcStatus.success) return;

    setState(() {
      _status = NfcStatus.processing;
      _message = "Tag lida! Lendo ID Mestre...";
    });

    final NfcReadResult nfcData = await nfcService.readTagData(tag);

    final int? logicalId = nfcData.logicalId;

    if (logicalId == null) {
      setState(() {
        _status = NfcStatus.error;
        _message = "Tag inválida! Não é uma tag da trilha.";
      });
      await _stopSessionAfterDelay(success: false);
      return;
    }

    setState(() => _message = "Tag $logicalId encontrada! Gravando seu log...");

    final bool success = await tagReadService.handleRealNfcRead(
      logicalId.toString(),
      tag,
      currentLat: widget.userLocation?.latitude,
      currentLon: widget.userLocation?.longitude,
    );

    if (success) {
      setState(() {
        _status = NfcStatus.success;
        _message = "Sucesso! Evento registrado na Tag $logicalId.";
      });
      await _stopSessionAfterDelay(success: true);
    } else {
      setState(() {
        _status = NfcStatus.error;
        _message = "Erro ao processar. Tente novamente.";
      });
      await _stopSessionAfterDelay(success: false);
    }
  }

  Future<void> _stopSessionAfterDelay({required bool success}) async {
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      print("[NfcInteractionDialog] Erro ao parar sessão: $e");
    }

    if (mounted) {
      Navigator.pop(context, success);
    }
  }

  @override
  void dispose() {
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      print("[NfcInteractionDialog] Erro ao parar sessão no dispose: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Leitura NFC",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 150,
              width: 150,
              child: _buildAnimationForStatus(),
            ),

            const SizedBox(height: 24),

            Text(
              _message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            if (_status == NfcStatus.ready || _status == NfcStatus.error)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text("CANCELAR"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationForStatus() {
    switch (_status) {
      case NfcStatus.ready:
        return Lottie.asset(
          'assets/animations/nfc_scan_animation.json',
          fit: BoxFit.contain,
        );
      case NfcStatus.processing:
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            strokeWidth: 4,
          ),
        );
      case NfcStatus.success:
        return Lottie.asset(
          'assets/animations/success_animation.json',
          repeat: false,
        );
      case NfcStatus.error:
        return const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 80,
        );
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case NfcStatus.ready:
        return Colors.grey.shade700;
      case NfcStatus.processing:
        return const Color(0xFF2E7D32);
      case NfcStatus.success:
        return const Color(0xFF2E7D32);
      case NfcStatus.error:
        return Colors.redAccent;
    }
  }
}
