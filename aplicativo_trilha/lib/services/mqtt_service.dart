// lib/services/mqtt_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String _broker = '200.19.144.16';
  final int _port = 1883;
  final String _topicoPublicacao = 'trilha/eventos/passagem';
  final String _clientId =
      'flutter_app_client_${DateTime.now().millisecondsSinceEpoch}';

  late MqttServerClient _client;

  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  MqttService() {
    _client = MqttServerClient(_broker, _clientId);
    _client.port = _port;
    _client.logging(on: true);
    _client.keepAlivePeriod = 60;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;
    _client.autoReconnect = true;
  }

  Future<void> connect() async {
    if (isConnected.value) {
      print('MQTT_SERVICE :: Já está conectado.');
      return;
    }

    print('MQTT_SERVICE :: Conectando ao broker $_broker...');
    try {
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain();

      _client.connectionMessage = connMessage;

      _client.onAutoReconnect = () {
        print('MQTT_SERVICE :: RECONEXÃO AUTOMÁTICA EM PROGRESSO...');
      };
      _client.onAutoReconnected = () {
        print('MQTT_SERVICE :: RECONEXÃO AUTOMÁTICA BEM-SUCEDIDA!');
        isConnected.value = true;
      };

      await _client.connect('trilheiro_mqtt', 'mapl_mqtt_2025');
    } catch (e) {
      print('MQTT_SERVICE :: Exceção ao conectar: $e');
      _client.disconnect();
    }
  }

  void publishSplitPayload({
    required String idPessoa,
    required String idTag,
    required String idLeitor,
    required String timestamp,
    required String lat,
    required String lon,
  }) {
    if (!isConnected.value) {
      print('MQTT_SERVICE :: Abortado: Sem conexão.');
      return;
    }

    print('MQTT_SERVICE :: Enviando pacote LoRa (6 tópicos)...');

    void _pub(String subtopic, String value) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(value);
      _client.publishMessage(
        'trilha/$subtopic',
        MqttQos.atLeastOnce,
        builder.payload!,
      );
    }

    _pub('id_leitor', idLeitor);
    _pub('id_pessoa', idPessoa);
    _pub('id_tag', idTag);
    _pub('time_stamp', timestamp);
    _pub('gps_lat', lat);
    _pub('gps_lon', lon);
  }

  void disconnect() {
    print('MQTT_SERVICE :: Desconectando...');
    _client.disconnect();
    isConnected.value = false;
  }

  void publish(Map<String, dynamic> payload) {
    if (!isConnected.value) {
      print('MQTT_SERVICE :: Não conectado. Não é possível publicar.');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    final jsonPayload = jsonEncode(payload);
    builder.addString(jsonPayload);

    print(
      'MQTT_SERVICE :: Publicando no tópico $_topicoPublicacao: $jsonPayload',
    );

    _client.publishMessage(
      _topicoPublicacao,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void _onConnected() {
    isConnected.value = true;
    print('MQTT_SERVICE :: Conectado ao Broker!');
  }

  void _onDisconnected() {
    isConnected.value = false;
    print('MQTT_SERVICE :: Desconectado do Broker.');
  }

  void _onSubscribed(String topic) {
    print('MQTT_SERVICE :: Inscrito no tópico: $topic');
  }
}
