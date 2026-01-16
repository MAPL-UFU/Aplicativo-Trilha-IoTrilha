// lib/services/tag_read_service.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/services/sync_service.dart';
import 'package:aplicativo_trilha/services/trail_logic_service.dart';
import 'package:aplicativo_trilha/services/nfc_service.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';

class TagReadService {
  final TrailLogicService _logicService = TrailLogicService();
  final DatabaseService _dbService = DatabaseService.instance;
  final SyncService _syncService;
  final NfcService _nfcService = NfcService();

  TagReadService(this._syncService);

  Future<Map<String, dynamic>?> _processAndSave(String tagId) async {
    try {
      final Map<String, dynamic> eventoParaSalvar = await _logicService
          .processTagRead(tagId);

      await _dbService.insertEvent(eventoParaSalvar);
      print(
        "[TagReadService] Evento processado e SALVO NO BUFFER LOCAL com sucesso!",
      );

      _syncService.syncPendingEvents();

      return eventoParaSalvar;
    } catch (e) {
      print("[TagReadService] ERRO INTERNO _processAndSave: $e");
      return null;
    }
  }

  Future<bool> handleRealNfcRead(
    String tagId,
    NfcTag nfcTagObject, {
    double? currentLat,
    double? currentLon,
    String? rawPayload,
  }) async {
    print("[TagReadService] Processando LEITURA REAL da tag: $tagId");

    if (currentLat != null &&
        currentLon != null &&
        rawPayload != null &&
        rawPayload.contains('|')) {
      try {
        final parts = rawPayload.split('|');
        if (parts.length >= 3) {
          final double tagLat = double.parse(parts[1]);
          final double tagLon = double.parse(parts[2]);
          final distance = Geolocator.distanceBetween(
            currentLat,
            currentLon,
            tagLat,
            tagLon,
          );

          print(
            "[TagReadService] Distância da Tag: ${distance.toStringAsFixed(2)}m",
          );

          if (distance > 10.0) {
            print(
              "[TagReadService] BLOQUEIO: Usuário fora do perímetro (10m).",
            );
          }
        }
      } catch (e) {
        print(
          "[TagReadService] Erro ao validar GPS da tag (ignorando validação): $e",
        );
      }
    }

    final String cleanId = tagId.contains('|') ? tagId.split('|')[0] : tagId;

    try {
      final eventoParaSalvar = await _processAndSave(cleanId);
      if (eventoParaSalvar == null) {
        print("[TagReadService] Falha ao processar e salvar. Abortando.");
        return false;
      }

      if (currentLat != null && currentLon != null) {
        print("[TagReadService] Disparando MQTT Sequencial para LoRa...");
        mqttService.publishSplitPayload(
          idPessoa: eventoParaSalvar['id_usuario'].toString(),
          idTag: cleanId,
          idLeitor: "mobile_app",
          timestamp: eventoParaSalvar['timestamp_leitura'],
          lat: currentLat.toString(),
          lon: currentLon.toString(),
        );
      }

      await _nfcService.writeToTag(
        nfcTagObject,
        userId: eventoParaSalvar['id_usuario'].toString(),
        timestamp: eventoParaSalvar['timestamp_leitura'],
        lat: currentLat,
        lon: currentLon,
      );

      return true;
    } catch (e) {
      print("[TagReadService] Erro geral: $e");
      return false;
    }
  }
}
