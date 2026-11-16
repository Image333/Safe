import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Best-effort GPS for emergency alerts. Never blocks the alert flow.
class LocationService {
  /// Returns current position or null if permission/GPS/timeout fails.
  Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('📍 LocationService: GPS désactivé');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('📍 LocationService: permission refusée ($permission)');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      ).timeout(timeout);
    } catch (e) {
      debugPrint('📍 LocationService: échec GPS ($e)');
      return null;
    }
  }
}
