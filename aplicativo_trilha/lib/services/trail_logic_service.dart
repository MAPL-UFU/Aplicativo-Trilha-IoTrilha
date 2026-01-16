// lib/services/trail_logic_service.dart
import 'package:aplicativo_trilha/services/database_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:location/location.dart';
import 'package:aplicativo_trilha/main.dart';

class SensorData {
  final LocationData? location;
  final double heading;
  SensorData(this.location, this.heading);
}

class TrailLogicService {
  final DatabaseService _dbService = DatabaseService.instance;
  final Location _location = Location();

  Future<SensorData> _getSensorData() async {
    print("[TrailLogic] Coletando dados dos sensores...");
    LocationData? currentLocation;
    double currentHeading = 0.0;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      print("[TrailLogic] Serviço de GPS desabilitado. Solicitando...");
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print("[TrailLogic] Usuário NÃO ativou o serviço de GPS.");
      }
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      print("[TrailLogic] Permissão de GPS negada. Solicitando...");
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print("[TrailLogic] Usuário NÃO concedeu permissão de GPS.");
      }
    }

    if (permissionGranted == PermissionStatus.granted && serviceEnabled) {
      try {
        currentLocation = await _location.getLocation();
        print(
          "[TrailLogic] GPS OK: Lat ${currentLocation.latitude}, Lng ${currentLocation.longitude}",
        );
      } catch (e) {
        print("[TrailLogic] Erro ao pegar GPS (mesmo com permissão): $e");
      }
    }

    try {
      final compassEvent = await FlutterCompass.events!.first;
      currentHeading = compassEvent.heading ?? 0.0;
      print("[TrailLogic] Bússola OK: $currentHeading graus");
    } catch (e) {
      print("[TrailLogic] Erro ao pegar Bússola: $e");
    }

    return SensorData(currentLocation, currentHeading);
  }

  Future<Map<String, dynamic>> processTagRead(String tagId) async {
    final sensorData = await _getSensorData();
    final double currentHeading = sensorData.heading;
    final LocationData? currentLocation = sensorData.location;

    final lastEvent = await _dbService.getLastEvent();
    final int currentTagId = int.tryParse(tagId) ?? 0;

    String direcao = 'ida';

    if (lastEvent == null) {
      direcao = 'ida';
      print("[TrailLogic] Primeiro evento. Direção = 'ida'");
    } else {
      final int lastTagId = lastEvent['id_tag'];
      final String lastDirecao = lastEvent['direcao'];
      final double lastHeading = lastEvent['heading_graus'];

      if (currentTagId < lastTagId) {
        direcao = 'volta';
        print(
          "[TrailLogic] Tag atual ($currentTagId) < anterior ($lastTagId). Direção = 'volta'",
        );
      } else if (currentTagId > lastTagId) {
        direcao = 'ida';
        print(
          "[TrailLogic] Tag atual ($currentTagId) > anterior ($lastTagId). Direção = 'ida'",
        );
      } else {
        print("[TrailLogic] Leitura dupla da Tag $currentTagId.");

        double headingDifference = (currentHeading - lastHeading).abs();
        if (headingDifference > 180) {
          headingDifference = 360 - headingDifference;
        }

        if (headingDifference > 150 && headingDifference < 210) {
          direcao = (lastDirecao == 'ida') ? 'volta' : 'ida';
          print(
            "[TrailLogic] Mudança de bússola detectada! Nova Direção = '$direcao'",
          );
        } else {
          direcao = lastDirecao;
          print(
            "[TrailLogic] Sem mudança de bússola. Direção mantida = '$direcao'",
          );
        }
      }
    }

    String? usuarioIdString = await authService.getLoggedInUserId();

    if (usuarioIdString == null) {
      print(
        "[TrailLogic] ERRO CRÍTICO: Tentando registrar evento sem usuário logado.",
      );
      usuarioIdString = '0';
    }

    final Map<String, dynamic> eventoParaSalvar = {
      'id_usuario': int.parse(usuarioIdString),
      'id_tag': currentTagId,
      'timestamp_leitura': DateTime.now().toIso8601String(),
      'direcao': direcao,
      'heading_graus': currentHeading,
      'latitude': currentLocation?.latitude ?? 0.0,
      'longitude': currentLocation?.longitude ?? 0.0,
    };

    return eventoParaSalvar;
  }
}
