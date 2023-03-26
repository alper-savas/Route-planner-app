// ignore_for_file: file_names

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import './directions.dart';
import '../config/config.dart';

class DirectionsRepo {
  Config config = Config();
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json?';
  final Dio _dio;
  DirectionsRepo({Dio? dio}) : _dio = dio ?? Dio();

  Future<Directions> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': config.GOOGLE_API,
      },
    );

    // Check if response is successful
    if (response.statusCode == 200) {
      return Directions.fromMap(response.data);
    } else {
      throw Error();
    }
  }
}
