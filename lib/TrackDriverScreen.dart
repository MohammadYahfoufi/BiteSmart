import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrackDriverScreen extends StatefulWidget {
  final String driverEmail;

  const TrackDriverScreen({super.key, required this.driverEmail});

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen> {
  LatLng? _driverLocation;

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
  }

  void _listenToDriverLocation() {
    FirebaseFirestore.instance
        .collection('locations')
        .doc(widget.driverEmail)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['lat'] != null && data['lng'] != null) {
        setState(() {
          _driverLocation = LatLng(data['lat'], data['lng']);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Track Driver: ${widget.driverEmail}'),
        backgroundColor: Colors.orange,
      ),
      body: _driverLocation == null
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : FlutterMap(
              options: MapOptions(
                initialCenter: _driverLocation ?? LatLng(0.0, 0.0),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.hungertrack',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.directions_bike,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
