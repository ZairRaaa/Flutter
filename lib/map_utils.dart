// lib/map_utils.dart
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Calcula distancia aproximada entre dos LatLng en metros (haversine).
double distanceBetween(LatLng a, LatLng b) {
  const R = 6371000.0; // radios terrestre en metros
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;

  final hav = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  return R * c;
}

/// Interpola entre dos LatLng (t entre 0..1)
LatLng interpolateLatLng(LatLng a, LatLng b, double t) {
  final lat = a.latitude + (b.latitude - a.latitude) * t;
  final lng = a.longitude + (b.longitude - a.longitude) * t;
  return LatLng(lat, lng);
}

/// Devuelve el bearing/heading (grados) entre dos puntos (0..360).
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;

  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final brng = math.atan2(y, x);
  var brngDeg = (brng * 180 / math.pi + 360) % 360;
  return brngDeg;
}

/// Carga un asset y lo convierte en BitmapDescriptor redimensionado.
Future<BitmapDescriptor> bitmapDescriptorFromAsset(
  String path, {
  int width = 80,
}) async {
  final ByteData data = await rootBundle.load(path);
  final ui.Codec codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: width,
  );
  final ui.FrameInfo fi = await codec.getNextFrame();
  final Uint8List resizedData =
      (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
  return BitmapDescriptor.fromBytes(resizedData);
}