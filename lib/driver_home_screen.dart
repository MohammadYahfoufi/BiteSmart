import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hungertrack/main.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final Location _location = Location();
  final FirebaseAuth _auth = FirebaseAuth.instance;

@override
void initState() {
  super.initState();
  _saveFCMToken();
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
});

  _startLocationUpdates();
}

Future<void> _saveFCMToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}


  Future<void> _startLocationUpdates() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    if (permission == PermissionStatus.granted) {
      _location.onLocationChanged.listen((loc) {
        FirebaseFirestore.instance.collection('locations').doc(email).set({
          'lat': loc.latitude,
          'lng': loc.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  String _formatTime(Timestamp? t) {
    if (t == null) return 'No time';
    final date = t.toDate();
    return DateFormat('yyyy-MM-dd • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final driverEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Deliveries'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirmLogout = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.orange),
                      ),
                      content: const Text(
                        'Are you sure you want to logout?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );

              if (confirmLogout == true) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('orders')
                .where('driverId', isEqualTo: driverEmail)
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders assigned yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final items = List.from(order['items'] ?? []);
              final total = (order['total'] ?? 0).toDouble();
              final timestamp = order['timestamp'] as Timestamp?;
              final location = order['location'];
              final time = _formatTime(timestamp);

              LatLng? customerLocation;
              if (location != null &&
                  location['lat'] != null &&
                  location['lng'] != null) {
                customerLocation = LatLng(location['lat'], location['lng']);
              }

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ExpansionTile(
                  title: Text(
                    'Order • \$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    time,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  children: [
                    ...items.map(
                      (item) => ListTile(
                        title: Text(
                          item['name'] ?? 'Item',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Text(
                          'x${item['quantity'] ?? 1}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final driverEmail =
                            FirebaseAuth.instance.currentUser?.email
                                ?.toLowerCase();

                        if (driverEmail == null) return;


                        await FirebaseFirestore.instance
                            .collection('orders')
                            .doc(order.id)
                            .update({
                              'driverId': '',
                              'status': 'delivered', 
                            });

                        final driverDoc =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: driverEmail)
                                .get();

                        if (driverDoc.docs.isNotEmpty) {
                          final driverId = driverDoc.docs.first.id;

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(driverId)
                              .update({'available': true});
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Order marked as delivered, you are now available!',
                            ),
                          ),
                        );
                      },

                      child: const Text(
                        'Remove from Order',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                    if (customerLocation != null)
                      SizedBox(
                        height: 150,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: customerLocation,
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: customerLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
