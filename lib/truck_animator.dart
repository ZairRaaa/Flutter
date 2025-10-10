// lib/truck_animator.dart
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_utils.dart';

typedef OnUpdatePos = void Function(LatLng position, double heading, int routeIndex);

class TruckAnimator {
  final List<LatLng> route;
  final OnUpdatePos onUpdate;
  bool _stopped = true;
  final int truckIconSize;

  TruckAnimator({
    required this.route,
    required this.onUpdate,
    this.truckIconSize = 64, // controla el tamaño aquí (px)
  }) : assert(route.length >= 2) {
    // No lanzamos la carga en ctor sin esperar; la cargamos en background.
  }

  /// Modo demo: recorre toda la ruta en [totalSeconds] segundos (suavizado).
  /// [stepMs] = frecuencia de actualización en ms.
  Future<void> startDemo({int totalSeconds = 40, int stepMs = 100}) async {
    _stopped = false;

    // Asegurarnos de que el icono esté listo (o al menos intentar cargarlo)


    final segmentLengths = <double>[];
    double totalLength = 0;
    for (var i = 0; i < route.length - 1; i++) {
      final d = distanceBetween(route[i], route[i + 1]);
      segmentLengths.add(d);
      totalLength += d;
    }
    if (totalLength <= 0) return;

    for (var i = 0; i < route.length - 1 && !_stopped; i++) {
      final start = route[i];
      final end = route[i + 1];
      final segLen = segmentLengths[i];
      final segDurationSec = (segLen / totalLength) * totalSeconds;
      final steps = (segDurationSec * 1000 / stepMs).clamp(1, 10000).toInt();
      for (var s = 0; s <= steps && !_stopped; s++) {
        final t = steps == 0 ? 1.0 : s / steps;
        final pos = interpolateLatLng(start, end, t);
        final heading = bearingBetween(start, end);

        // Llamamos al callback con los 3 parámetros esperados.
        onUpdate(pos, heading, i);

        await Future.delayed(Duration(milliseconds: stepMs));
      }
    }
  }

  /// Modo horario: recibe lista de strings "HH:mm" (misma longitud que stopsIndices)
  /// y lista de indices -> donde están las paradas en la ruta.
  /// [compressToSeconds] si se provee, escala la duración total programada a ese valor.
  Future<void> startSchedule({
    required List<String> times,
    required List<int> stopIndices,
    int stepMs = 100,
    int? compressToSeconds,
  }) async {
    _stopped = false;

    if (times.length != stopIndices.length) {
      throw Exception('times.length must equal stopIndices.length');
    }

    // Convertir times ("HH:mm") a duraciones relativas entre paradas
    final today = DateTime.now();
    final List<DateTime> dateTimes = times.map((s) {
      final parts = s.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateTime(today.year, today.month, today.day, h, m);
    }).toList();

    // Duraciones entre paradas (en segundos). Si negativo, convertimos a 0.
    final List<double> stopDurations = [];
    for (var i = 0; i < dateTimes.length - 1; i++) {
      final dur = dateTimes[i + 1].difference(dateTimes[i]).inSeconds.toDouble();
      stopDurations.add(dur < 1 ? 1.0 : dur);
    }
    // Si hay N stops => hay N-1 durations. Si solo 1 stop, no hay movimiento entre stops.
    if (stopDurations.isEmpty) {
      return;
    }

    // Calculamos el total de tiempo programado
    double totalScheduledSec = stopDurations.reduce((a, b) => a + b);

    // Si compressToSeconds se provee, calculamos factor de escala
    double scale = (compressToSeconds != null && totalScheduledSec > 0)
        ? (compressToSeconds / totalScheduledSec)
        : 1.0;

    // Para cada bloque entre stopIndices[i] -> stopIndices[i+1], calculamos longitud
    for (var block = 0; block < stopIndices.length - 1 && !_stopped; block++) {
      final int startIndex = stopIndices[block];
      final int endIndex = stopIndices[block + 1];

      // Clamp indices
      final int sIdx = startIndex.clamp(0, route.length - 1);
      final int eIdx = endIndex.clamp(0, route.length - 1);
      if (sIdx >= eIdx) continue;

      // Sumar longitudes dentro del bloque
      double blockLength = 0;
      for (var k = sIdx; k < eIdx; k++) {
        blockLength += distanceBetween(route[k], route[k + 1]);
      }

      // Duración del bloque (segundos), escalada
      final blockDurationSec = stopDurations[block] * scale;

      // Ahora repartimos blockDurationSec proporcionalmente entre los segmentos
      for (var seg = sIdx; seg < eIdx && !_stopped; seg++) {
        final segLen = distanceBetween(route[seg], route[seg + 1]);
        final segDurationSec = (blockLength == 0) ? (blockDurationSec / (eIdx - sIdx)) : (segLen / blockLength) * blockDurationSec;
        final steps = (segDurationSec * 1000 / stepMs).clamp(1, 20000).toInt();

        for (var s = 0; s <= steps && !_stopped; s++) {
          final t = steps == 0 ? 1.0 : s / steps;
          final pos = interpolateLatLng(route[seg], route[seg + 1], t);
          final heading = bearingBetween(route[seg], route[seg + 1]);
          onUpdate(pos, heading, seg);
          await Future.delayed(Duration(milliseconds: stepMs));
        }
      }
      // Opcional: pequeña pausa en la parada
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void stop() {
    _stopped = true;
  }
}
