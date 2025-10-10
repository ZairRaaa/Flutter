// lib/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_data.dart';
import 'truck_animator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _truckIcon;

  // Estado del mapa: polylines, polygon, markers
  final Set<Polyline> _polylines = {};
  final Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};

  // Animador del camión
  TruckAnimator? _animator;

  // UI state
  bool _isRunning = false;
  int _demoDurationSeconds = 40; // tiempo total demo
  bool _compressSchedule = true;
  String _status = 'Listo';

  @override
  void initState() {
    super.initState();
    _loadTruckIcon();
    _setupStaticMapElements();
    _animator = TruckAnimator(route: recolectorRoute, onUpdate: _onTruckUpdate);
  }

  Future<void> _loadTruckIcon() async {
    try {
      final bmp = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(32, 32)), // controla el tamaño aquí
        'assets/truck.png',
      );
      setState(() {
        _truckIcon = bmp;
      });
    } catch (_) {
      _truckIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  Future<void> _setupStaticMapElements() async {
    // Cargar polígono de Chilca desde GeoJSON
    final chilcaPolygonCoords = await loadChilcaPolygon();

    // Polilínea (ruta)
    _polylines.add(Polyline(
      polylineId: const PolylineId('ruta_recolector'),
      points: recolectorRoute,
      color: Colors.blueAccent,
      width: 6,
    ));

    // Polígono Chilca
    _polygons.add(Polygon(
      polygonId: const PolygonId('chilca_poly'),
      points: chilcaPolygonCoords,
      fillColor: Colors.green.withOpacity(0.12),
      strokeColor: Colors.green,
      strokeWidth: 2,
    ));

    // Marcadores: paradas
    final stopMarkers = routeStopIndices.map((idx) {
      final pos = recolectorRoute[idx.clamp(0, recolectorRoute.length - 1)];
      return Marker(
        markerId: MarkerId('stop_$idx'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Parada ${routeStopIndices.indexOf(idx) + 1}'),
      );
    }).toSet();

    // Marcador descarga
    final descargaIdx = routeStopIndices.last;
    final descargaMarker = Marker(
      markerId: const MarkerId('descarga'),
      position: recolectorRoute[descargaIdx],
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: const InfoWindow(title: 'Descarga residuos'),
    );

    setState(() {
      _markers = {...stopMarkers, descargaMarker};
    });
  }

  void _onTruckUpdate(LatLng pos, double heading, int routeIndex) {
    final marker = Marker(
      markerId: const MarkerId('truck'),
      position: pos,
      rotation: heading,
      icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: 'Recolector', snippet: 'Index: $routeIndex'),
    );

    setState(() {
      // Mantener marcadores estáticos + el truck dinámico
      _markers = _markers.where((m) => m.markerId.value != 'truck').toSet();
      _markers.add(marker);
    });
  }

  void _startDemo() async {
    if (_isRunning) return;
    setState(() {
      _status = 'Iniciando demo...';
      _isRunning = true;
    });

    // Asegúrate de que el mapa esté listo
    await Future.delayed(const Duration(milliseconds: 200));
    _animator?.stop();
    _animator = TruckAnimator(route: recolectorRoute, onUpdate: _onTruckUpdate);
    await _animator?.startDemo(totalSeconds: _demoDurationSeconds, stepMs: 100);
    setState(() {
      _status = 'Demo finalizado';
      _isRunning = false;
    });
  }

  void _startScheduleMode() async {
    if (_isRunning) return;
    setState(() {
      _status = 'Iniciando modo horario...';
      _isRunning = true;
    });

    _animator?.stop();
    _animator = TruckAnimator(route: recolectorRoute, onUpdate: _onTruckUpdate);

    // Comprimir a demoDurationSeconds para visualización (evita esperar horas reales).
    final compressTo = _compressSchedule ? _demoDurationSeconds : null;

    try {
      await _animator?.startSchedule(
        times: routeScheduleTimes,
        stopIndices: routeStopIndices,
        stepMs: 120,
        compressToSeconds: compressTo,
      );
      setState(() {
        _status = 'Recorrido por horario finalizado';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en modo horario: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _stopAnimation() {
    _animator?.stop();
    setState(() {
      _isRunning = false;
      _status = 'Animación detenida';
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Centrar en Chilca
    final LatLng center = recolectorRoute[0];
    controller.moveCamera(CameraUpdate.newLatLngZoom(center, 14));
  }

  @override
  void dispose() {
    _animator?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraPosition(target: recolectorRoute[0], zoom: 14);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrido Recolectores - Chilca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLng(recolectorRoute[0]));
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCamera,
            onMapCreated: _onMapCreated,
            polylines: _polylines,
            polygons: _polygons,
            markers: _markers,
            zoomControlsEnabled: true,
            myLocationEnabled: false,
            mapType: MapType.normal,
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isRunning ? null : _startDemo,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Demo rápido'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isRunning ? null : _startScheduleMode,
                          icon: const Icon(Icons.schedule),
                          label: const Text('Modo horario'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isRunning ? _stopAnimation : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Detener'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Duración demo (s): '),
                        Expanded(
                          child: Slider(
                            value: _demoDurationSeconds.toDouble(),
                            min: 10,
                            max: 180,
                            divisions: 17,
                            label: '$_demoDurationSeconds s',
                            onChanged: (v) {
                              setState(() {
                                _demoDurationSeconds = v.toInt();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$_demoDurationSeconds s'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _compressSchedule,
                          onChanged: (v) {
                            setState(() {
                              _compressSchedule = v ?? true;
                            });
                          },
                        ),
                        const Flexible(
                          child: Text('Comprimir horarios para demo (recomendado)'),
                        ),
                        const SizedBox(width: 12),
                        Text(_status),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
