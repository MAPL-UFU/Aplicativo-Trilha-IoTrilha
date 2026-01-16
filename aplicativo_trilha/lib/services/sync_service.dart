// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:aplicativo_trilha/services/mqtt_service.dart';

class SyncService {
  final DatabaseService _dbService;
  final MqttService _mqttService;

  StreamSubscription? _connectivitySubscription;

  bool _isSyncing = false;

  SyncService(this._dbService, this._mqttService);

  void init() {
    print("[SyncService] Iniciando e ouvindo mudanças de conectividade...");

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      bool hasConnection = !results.contains(ConnectivityResult.none);

      if (hasConnection) {
        print("[SyncService] Detectada conexão de rede!");
        syncPendingEvents();
      } else {
        print("[SyncService] Detectada perda de conexão de rede.");
      }
    });

    syncPendingEvents();
  }

  Future<void> syncPendingEvents() async {
    if (_isSyncing || !_mqttService.isConnected.value) {
      if (_isSyncing)
        print("[SyncService] Sincronização já em progresso. Aguardando.");
      if (!_mqttService.isConnected.value)
        print("[SyncService] MQTT desconectado. Sincronização abortada.");
      return;
    }

    _isSyncing = true;
    print("[SyncService] ===== INICIANDO SINCRONIZAÇÃO DE PENDENTES =====");

    try {
      final pendingEvents = await _dbService.getPendingEvents();

      if (pendingEvents.isEmpty) {
        print("[SyncService] Buffer local está limpo. Nada a sincronizar.");
        _isSyncing = false;
        return;
      }

      print(
        "[SyncService] ${pendingEvents.length} eventos encontrados no buffer. Enviando...",
      );

      for (final event in pendingEvents) {
        final Map<String, dynamic> payload = {
          'id_usuario': event['id_usuario'],
          'id_tag': event['id_tag'],
          'timestamp_leitura': event['timestamp_leitura'],
          'direcao': event['direcao'],

          'latitude': event['latitude'],
          'longitude': event['longitude'],
        };

        _mqttService.publish(payload);
        print("[SyncService] Evento ID: ${event['id']} publicado no MQTT.");

        await _dbService.updateEventStatus(event['id'], 'concluido');
        print(
          "[SyncService] Evento ID: ${event['id']} marcado como 'concluido'.",
        );

        await Future.delayed(const Duration(milliseconds: 100));
      }

      print("[SyncService] ===== SINCRONIZAÇÃO CONCLUÍDA =====");
    } catch (e) {
      print("[SyncService] ERRO durante a sincronização: $e");
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    print("[SyncService] Encerrando.");
    _connectivitySubscription?.cancel();
  }
}
