// lib/screens/live_trail_screen.dart
// ignore_for_file: unused_import

import 'dart:async';
import 'package:aplicativo_trilha/screens/start_trail_form_screen.dart';
import 'package:aplicativo_trilha/screens/trail_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lottie/lottie.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:aplicativo_trilha/widgets/nfc_interaction_dialog.dart';
import 'package:aplicativo_trilha/widgets/trail_drawer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aplicativo_trilha/main.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:convert';

final Map<int, LatLng> tagCoordinates = {
  1: LatLng(-19.348935, -43.619372),
  2: LatLng(-19.349137, -43.616880),
  3: LatLng(-19.349398, -43.615951),
  4: LatLng(-19.350161, -43.612595),
  5: LatLng(-19.354978, -43.606314),
  6: LatLng(-19.371427, -43.600635),
  7: LatLng(-19.383878, -43.590989),
  8: LatLng(-19.384595, -43.589932),
  9: LatLng(-19.379513, -43.576581),
};

class LiveTrailScreen extends StatefulWidget {
  const LiveTrailScreen({super.key});

  @override
  State<LiveTrailScreen> createState() => _LiveTrailScreenState();
}

class _LiveTrailScreenState extends State<LiveTrailScreen> {
  int? _idTrilhaAtiva;
  final _storage = const FlutterSecureStorage();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final MapController _mapController = MapController();
  LatLng? _userLocation;
  double? _heading;
  StreamSubscription? _positionSub;
  StreamSubscription? _compassSub;

  int? _tagProximaId;
  bool _isGeofencingAtivo = false;
  static const double RAIO_PROXIMIDADE_METROS = 20.0;

  @override
  void initState() {
    super.initState();
    _verificarTrilhaAtiva();
  }

  Future<void> _verificarTrilhaAtiva() async {
    final id = await _storage.read(key: 'active_trail_id');
    if (id != null) {
      setState(() {
        _idTrilhaAtiva = int.parse(id);
      });
      _iniciarGeofencing();
      _initLiveTracking();
    }
  }

  Future<void> _iniciarNovaTrilha() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissão de localização é necessária!'),
          ),
        );
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    final novoIdTrilha = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => const StartTrailFormScreen()),
    );

    if (novoIdTrilha != null) {
      await _storage.write(
        key: 'active_trail_id',
        value: novoIdTrilha.toString(),
      );
      setState(() {
        _idTrilhaAtiva = novoIdTrilha;
      });
      _iniciarGeofencing();
      _initLiveTracking();
    }
  }

  void _onTrilhaFinalizada() async {
    print("[LiveTrailScreen] Recebido callback de finalização.");
    await _storage.delete(key: 'active_trail_id');

    _positionSub?.cancel();
    _compassSub?.cancel();

    setState(() {
      _idTrilhaAtiva = null;
      _tagProximaId = null;
      _isGeofencingAtivo = false;
      _userLocation = null;
      _heading = null;
    });
    Navigator.pop(context);
  }

  void _initLiveTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (pos) {
            if (mounted) {
              setState(() {
                _userLocation = LatLng(pos.latitude, pos.longitude);
              });
            }
          },
        );
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 17.0);
    }
  }

  void _iniciarGeofencing() {
    if (_isGeofencingAtivo) return;
    _isGeofencingAtivo = true;
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          _verificarProximidade(position);
        });
  }

  void _verificarProximidade(Position userPosition) {
    int? tagMaisProximaEncontrada;
    for (var entry in tagCoordinates.entries) {
      final int tagId = entry.key;
      final LatLng tagPos = entry.value;
      final double distancia = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        tagPos.latitude,
        tagPos.longitude,
      );
      if (distancia <= RAIO_PROXIMIDADE_METROS) {
        tagMaisProximaEncontrada = tagId;
        break;
      }
    }
    if (_tagProximaId != tagMaisProximaEncontrada) {
      setState(() {
        _tagProximaId = tagMaisProximaEncontrada;
      });
    }
  }

  void _onNfcButtonPressed() async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aguardando sinal de GPS..."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? sucesso = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return NfcInteractionDialog(userLocation: _userLocation);
      },
    );

    if (sucesso == true) {}
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Widget _buildOciosoState() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text("Ínicio")),
      drawer: TrailDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Lottie.asset(
              'assets/animations/hiking_animation.json',
              height: 300,
            ),
            const SizedBox(height: 30),
            Text(
              'Nenhuma trilha em andamento',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Quando estiver pronto, inicie sua atividade para começar o monitoramento.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _iniciarNovaTrilha,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Iniciar nova trilha',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtivoState() {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hiking, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Trilha em Andamento",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ),
      ),

      drawer: TrailDrawer(
        trilhaId: _idTrilhaAtiva,
        onTrilhaFinalizada: _onTrilhaFinalizada,
        userLocation: _userLocation,
      ),

      body: Stack(
        children: [
          TrailMapScreen(
            mapController: _mapController,
            userLocation: _userLocation,
            heading: _heading,
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMapControl(
                    icon: Icons.my_location,
                    label: "Recetralizar",
                    onTap: _centerOnUser,
                    isPrimary: false,
                  ),

                  Transform.translate(
                    offset: const Offset(0, 0),
                    child: SizedBox(
                      height: 70,
                      width: 70,
                      child: FloatingActionButton(
                        onPressed: _onNfcButtonPressed,
                        backgroundColor: _tagProximaId != null
                            ? const Color(0xFFFF6D00)
                            : Colors.grey,
                        elevation: 10,
                        shape: const CircleBorder(),
                        child: const Icon(
                          Icons.nfc,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  _buildMapControl(
                    icon: Icons.compass_calibration,
                    label: "Norte",
                    isPrimary: false,
                    onTap: () {
                      _mapController.rotate(0);
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_tagProximaId != null)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sensors, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Ponto de checagem próximo!",
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isPrimary ? Colors.orange : Colors.grey.shade600,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _idTrilhaAtiva == null ? _buildOciosoState() : _buildAtivoState();
  }
}
