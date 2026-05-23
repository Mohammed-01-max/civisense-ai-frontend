import 'package:geolocator/geolocator.dart';

class LocationService {
  static const defaultLat = 17.4400;
  static const defaultLon = 78.3489;
  static const hyderabadBounds = {
    'minLat': 17.2,
    'maxLat': 17.65,
    'minLon': 78.2,
    'maxLon': 78.7,
  };

  /// Request location permission and get current position.
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openLocationSettings();
        return null;
      }

      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
        forceAndroidLocationManager: true,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if a location is within Hyderabad area bounds.
  static bool isInHyderabad(double lat, double lon) {
    return lat >= hyderabadBounds['minLat']! &&
        lat <= hyderabadBounds['maxLat']! &&
        lon >= hyderabadBounds['minLon']! &&
        lon <= hyderabadBounds['maxLon']!;
  }

  /// Get Hyderabad center coordinates for map initialization.
  static Map<String, double> getHyderabadCenter() {
    return {
      'lat': 17.4400,
      'lon': 78.3489,
    };
  }
}
