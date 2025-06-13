import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No date';
    final date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd • hh:mm a').format(date);
  }

  void _assignDriverDialog(
    BuildContext context,
    String orderId,
    String? currentDriver,
  ) async {
    if (currentDriver != null && currentDriver != 'Unassigned') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Driver already assigned')));
      return;
    }

    final driversSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .where('available', isEqualTo: true)
            .get();

    final drivers = driversSnapshot.docs;

    String? selectedDriverEmail;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Assign Driver',
              style: TextStyle(color: Colors.orange),
            ),
            content: DropdownButtonFormField<String>(
              value: selectedDriverEmail,
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(
                labelText: 'Available Drivers',
                labelStyle: TextStyle(color: Colors.orange),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              items:
                  drivers.map<DropdownMenuItem<String>>((doc) {
                    final name = doc['name'];
                    final email = doc['email'];
                    return DropdownMenuItem<String>(
                      value: email,
                      child: Text(
                        '$name • $email',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                selectedDriverEmail = value;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedDriverEmail != null) {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({'driverId': selectedDriverEmail});

                    final driverDocs =
                        await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isEqualTo: selectedDriverEmail)
                            .get();

                    for (var doc in driverDocs.docs) {
                      await doc.reference.update({'available': false});

                      final driverToken = doc['fcmToken'];
                      if (driverToken != null) {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .add({
                              'to': driverToken,
                              'title': 'New Delivery Assigned',
                              'body': 'You have a new delivery to handle!',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                      }
                    }

                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a driver')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Assign'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('All Orders'),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('orders')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders yet.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final List items = order['items'];
              final total = order['total'];
              final time = _formatTimestamp(order['timestamp']);
              final driverId =
                  order.data().toString().contains('driverId')
                      ? order['driverId']
                      : 'Unassigned';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ExpansionTile(
                  collapsedIconColor: Colors.orange,
                  iconColor: Colors.orange,
                  title: Text(
                    'Order • \$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, style: const TextStyle(color: Colors.white70)),
                      Text(
                        'Driver: $driverId',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  children: [
                    ...items.map<Widget>((item) {
                      return ListTile(
                        title: Text(
                          item['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Text(
                          'x${item['quantity']}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed:
                            () => _assignDriverDialog(
                              context,
                              order.id,
                              driverId == 'Unassigned' ? null : driverId,
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.person),
                        label: const Text('Assign Driver'),
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
