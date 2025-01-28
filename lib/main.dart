import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const OpenStreetMapRouteApp());
}

class OpenStreetMapRouteApp extends StatelessWidget {
  const OpenStreetMapRouteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapsPage(),
    );
  }
}

class MapsPage extends StatefulWidget {
  const MapsPage({Key? key}) : super(key: key);

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final LatLng _origin = const LatLng(40.7128, -74.0060); // New York
  final LatLng _destination = const LatLng(40.7831, -73.9712); // Manhattan
  
  List<LatLng> _routePoints = [];
  bool _isLoading = false;
  bool _showTraffic = false;
  Map<String, dynamic> _routeInfo = {};

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get route using OSRM
      final String coordinates =
          '${_origin.longitude},${_origin.latitude};${_destination.longitude},${_destination.latitude}';

      final response = await http.get(Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&annotations=true'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final List<dynamic> coordinates = route['geometry']['coordinates'];

        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          _routeInfo = {
            'distance': route['distance'], // in meters
            'duration': route['duration'], // in seconds
          };
        });
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading route: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getMapUrl() {
    if (_showTraffic) {
      // Using Thunderforest Atlas map style
      return 'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=4fe4cdb808254e38adb6efd7ed6f807e';
    }
    // Default OpenStreetMap layer
    return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  Widget _buildRouteInfo() {
    if (_routeInfo.isEmpty) return const SizedBox.shrink();

    final distance =
        (_routeInfo['distance'] / 1000).toStringAsFixed(2); // Convert to km
    final duration =
        (_routeInfo['duration'] / 60).toStringAsFixed(0); // Convert to minutes

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Icon(Icons.directions_car),
                  Text('$distance km'),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.access_time),
                  Text('$duration mins'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Map"),
        actions: [
          // Traffic toggle button
          IconButton(
            icon: Icon(_showTraffic ? Icons.traffic : Icons.traffic_outlined),
            onPressed: () {
              setState(() {
                _showTraffic = !_showTraffic;
              });
            },
            tooltip: 'Toggle Traffic View',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: _origin,
              zoom: 11.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _getMapUrl(),
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  _buildMarker(
                    point: _origin,
                    color: Colors.red,
                    icon: Icons.location_on,
                  ),
                  _buildMarker(
                    point: _destination,
                    color: Colors.green,
                    icon: Icons.location_pin,
                  ),
                ],
              ),
            ],
          ),
          _buildRouteInfo(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      // Refresh button
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRoute,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Marker _buildMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
  }) {
    return Marker(
      point: point,
      width: 60,
      height: 60,
      child: Icon(
        icon,
        color: color,
        size: 40,
      ),
    );
  }
}
