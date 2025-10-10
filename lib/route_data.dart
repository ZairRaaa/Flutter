// lib/route_data.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Ruta de ejemplo que recorre el distrito Chilca (Huancayo) en forma aproximada.
/// Estos puntos son aproximados y sirven para simular el recorrido del recolector.
final List<LatLng> recolectorRoute = [
  LatLng(-12.083200, -75.197500), // 0 - Jr Manco Cápac (inicio)
  LatLng(-12.083000, -75.198800),
  LatLng(-12.082000, -75.200500),
  LatLng(-12.081000, -75.203000), // 3
  LatLng(-12.078000, -75.205000),
  LatLng(-12.075500, -75.206500),
  LatLng(-12.073500, -75.208000), // 6
  LatLng(-12.071000, -75.209500),
  LatLng(-12.069000, -75.210500),
  LatLng(-12.067000, -75.209000), // 9
  LatLng(-12.066000, -75.207000),
  LatLng(-12.066500, -75.204000),
  LatLng(-12.067500, -75.202000), // 12
  LatLng(-12.068500, -75.200500),
  LatLng(-12.070000, -75.199500),
  LatLng(-12.072000, -75.198000), // 15
  LatLng(-12.074000, -75.197500),
  LatLng(-12.076000, -75.197000),
  LatLng(-12.078500, -75.196800), // 18
  LatLng(-12.080500, -75.196900),
  LatLng(-12.082000, -75.197200),
  LatLng(-12.083000, -75.197400), // 21
];

/// Índices de puntos que consideramos "paradas" (matching con tu horario).
/// Ajusta si deseas que las paradas estén en otros puntos.
final List<int> routeStopIndices = [0, 3, 6, 9, 12, 15, 18, 21];

/// Horarios que nos diste (strings "HH:mm"). Puedes editarlos desde aquí.
/// Nota: el code luego convierte estos tiempos a DateTime (hoy).
final List<String> routeScheduleTimes = [
  '06:00',
  '06:52',
  '07:42',
  '09:21',
  '10:15',
  '11:36',
  '12:25',
  '12:25', // último punto: descarga (puedes ajustar)
];

/// Carga el polígono de Chilca desde un archivo GeoJSON en assets.
/// Debes tener un archivo en assets/geojson/chilca.json
Future<List<LatLng>> loadChilcaPolygon() async {
  final String data = await rootBundle.loadString('assets/chilcapdf.json');
  final Map<String, dynamic> geojson = jsonDecode(data);

  final List<dynamic> coordinates =
      geojson['features'][0]['geometry']['coordinates'][0];

  return coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
}