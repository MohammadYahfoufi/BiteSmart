import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'TrackDriverScreen.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('Your Orders'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerEmail', isEqualTo: userEmail)
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
                'No orders yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView(
            children: orders.map((order) {
              final driverId = order.data().toString().contains('driverId')
                  ? order['driverId']
                  : null;
              final time = (order['timestamp'] as Timestamp?)?.toDate();
              final items = order['items'] as List<dynamic>;

              final summary = items
                  .map((item) {
                    final name = item['name'] ?? 'Item';
                    final qty = item['quantity'] ?? 1;
                    return '$qty x $name';
                  })
                  .join(', ');

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: ListTile(
                  title: Text(summary, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Time: ${time?.toLocal().toString() ?? 'Unknown'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: driverId != null
                      ? (driverId != ''
                          ? ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrackDriverScreen(driverEmail: driverId),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text("Track"),
                            )
                          : const Text(
                              "Food received ✅",
                              style: TextStyle(color: Colors.green),
                            ))
                      : const Text(
                          "No driver yet",
                          style: TextStyle(color: Colors.grey),
                        ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
