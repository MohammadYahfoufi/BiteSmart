import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'CustomerOrdersScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int> _cart = {};
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _categoryKeys = {};
  LatLng? _userLocation;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    print('Notification system initialized.');
  }

  Future<void> _showOrderPlacedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'order_channel',
          'Order Notifications',
          channelDescription: 'Notifications about order status',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Order Placed',
      'Your order was placed successfully!',
      platformChannelSpecifics,
    );
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    }
  }

  Future<void> _placeOrder(List cartItems, double total) async {
    if (_userLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location not found.')));
      return;
    }

    final snapshot = await _firestore.collection('foods').get();
    final allFoods = snapshot.docs;

    for (var item in cartItems) {
      final foodDoc = allFoods.firstWhere((doc) => doc.id == item['id']);
      final currentStock = foodDoc['stock'] ?? 0;
      final requestedQty = item['quantity'];

      if (requestedQty > currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough stock for ${item['name']} (only $currentStock left)',
            ),
          ),
        );
        return;
      }
    }

    const adminLat = 33.222405;
    const adminLng = 35.3120683;

    final distanceInMeters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      adminLat,
      adminLng,
    );

    if (distanceInMeters > 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorry, you are too far to place an order.'),
        ),
      );
      return;
    }

    for (var item in cartItems) {
      final docRef = _firestore.collection('foods').doc(item['id']);
      await docRef.update({'stock': FieldValue.increment(-item['quantity'])});
    }

    await _firestore.collection('orders').add({
      'items': cartItems,
      'total': total,
      'timestamp': FieldValue.serverTimestamp(),
      'customerId': FirebaseAuth.instance.currentUser?.uid,
      'customerEmail': FirebaseAuth.instance.currentUser?.email,
      'location': {
        'lat': _userLocation!.latitude,
        'lng': _userLocation!.longitude,
      },
    });

    setState(() {
      _cart.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));

    await _showOrderPlacedNotification();
  }

  double _getCartTotal(List<DocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      final price = doc['price'] ?? 0;
      final qty = _cart[doc.id] ?? 0;
      total += price * qty;
    }
    return total;
  }

  double _getTotalPrice(List<DocumentSnapshot> docs) {
    double total = 0.0;
    for (var doc in docs) {
      if (_cart.containsKey(doc.id)) {
        total += doc['price'] * _cart[doc.id]!;
      }
    }
    return total;
  }

  void _addToCart(String id) {
    setState(() {
      _cart[id] = (_cart[id] ?? 0) + 1;
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      if (_cart.containsKey(id)) {
        if (_cart[id]! > 1) {
          _cart[id] = _cart[id]! - 1;
        } else {
          _cart.remove(id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('BiteSmart'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.orange),
                    ),
                    content: const Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(color: Colors.white),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 180),
            child: ListView(
              controller: _scrollController,
              children: [
                if (_userLocation != null)
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _userLocation!,
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
                              point: _userLocation!,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Fetching location...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('foods').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    final grouped = <String, List<DocumentSnapshot>>{};

                    for (var doc in docs) {
                      final category =
                          doc.data().toString().contains('category')
                              ? doc['category']
                              : 'Uncategorized';
                      grouped.putIfAbsent(category, () => []).add(doc);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children:
                                grouped.keys.map((category) {
                                  _categoryKeys.putIfAbsent(
                                    category,
                                    () => GlobalKey(),
                                  );

                                  return GestureDetector(
                                    onTap: () {
                                      final keyContext =
                                          _categoryKeys[category]
                                              ?.currentContext;
                                      if (keyContext != null) {
                                        Scrollable.ensureVisible(
                                          keyContext,
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),

                        ...grouped.entries.map((entry) {
                          final category = entry.key;
                          final items = entry.value;

                          return Column(
                            key: _categoryKeys[category],
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 20,
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.orange,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      category,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              ...items.map((doc) {
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      doc['image'] ?? '',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white70,
                                            ),
                                          ),
                                    ),
                                  ),
                                  title: Text(
                                    doc['name'],
                                    style: const TextStyle(
                                      color: Colors.orange,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['subtitle'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${(doc['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () => _removeFromCart(doc.id),
                                      ),
                                      SizedBox(
                                        width: 24,
                                        child: Center(
                                          child: Text(
                                            _cart[doc.id]?.toString() ?? '0',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add,
                                          color: Colors.green,
                                        ),
                                        onPressed: () => _addToCart(doc.id),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<QuerySnapshot>(
                    future: _firestore.collection('foods').get(),
                    builder: (context, snapshot) {
                      double total = 0.0;
                      if (snapshot.hasData) {
                        total = _getCartTotal(snapshot.data!.docs);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total: \$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerOrdersScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View My Orders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/contact');
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Us'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_cart.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '🛒 Your cart is empty. Please add food first!',
                            ),
                          ),
                        );
                        return;
                      }

                      final docs = await _firestore.collection('foods').get();
                      final cartItems =
                          docs.docs
                              .where((doc) => _cart.containsKey(doc.id))
                              .map(
                                (doc) => {
                                  'id': doc.id,
                                  'name': doc['name'],
                                  'quantity': _cart[doc.id],
                                  'price': doc['price'],
                                },
                              )
                              .toList();

                      final total = _getTotalPrice(docs.docs);

                      await _placeOrder(cartItems, total);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(250, 48),
                    ),
                    child: const Text('Place Order'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 5.0, bottom: 20.0),
        child: Align(
          alignment: Alignment.bottomRight,
          child: FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ChatbotPopup(),
              );
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.chat, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class ChatbotPopup extends StatefulWidget {
  const ChatbotPopup({super.key});

  @override
  State<ChatbotPopup> createState() => _ChatbotPopupState();
}

class _ChatbotPopupState extends State<ChatbotPopup> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  String getSmartResponse(String input) {
    final text = input.toLowerCase();

    if (text.contains('hello') || text.contains('hi') || text.contains('hey')) {
      return "Hello! 👋 Welcome to BiteSmart.\nYou can ask about the menu, how to order, or track your delivery.";
    }

    if (text.contains('menu') ||
        text.contains('food') ||
        text.contains('available items')) {
      return "Here’s our top picks today:\n"
          "🍔 Burgers (Beef, Chicken, Veggie)\n"
          "🍟 Fries\n"
          "🥤 Milkshakes & Sodas\n"
          "🍰 Desserts\n\nUse the ➕ buttons to add items to your cart!";
    }

    if (text.contains('place order') ||
        text.contains('buy') ||
        text.contains('how to order')) {
      return "To order:\n1. Add items using the ➕ button\n2. Tap 'Place Order' at the bottom\n3. Make sure your location is enabled 🧭\n\nThat's it! Your order goes to our kitchen 😋.";
    }

    if (text.contains('track') ||
        text.contains('driver') ||
        text.contains('where is my order')) {
      return "🚚 You can track your driver after placing an order.\nGo to 'My Orders' and tap 'Track' when your order is on the way.";
    }

    if (text.contains('open') && text.contains('hours')) {
      return "⏰ We’re open daily from 10:00 AM to 11:00 PM.\nWeekend hours may vary slightly.";
    }

    if (text.contains('contact') ||
        text.contains('help') ||
        text.contains('support')) {
      return "Need help? We're here for you 💬:\n📞 Call: +961-123456\n📧 Email: support@bitesmart.com\nYou can also chat here anytime!";
    }

    if (text.contains('cancel') ||
        text.contains('change') ||
        text.contains('edit order')) {
      return "⚠️ Orders can’t be changed or canceled in the app once placed.\nPlease contact support immediately for urgent issues.";
    }

    if (text.contains('payment') ||
        text.contains('pay') ||
        text.contains('card')) {
      return "We accept cash on delivery 💵.\nCard payments and online options coming soon!";
    }

    if (text.contains('location') ||
        text.contains('gps') ||
        text.contains('not working')) {
      return "📍 Make sure your GPS is enabled.\nIf you're still seeing 'Fetching location...', try restarting the app or granting location permission from settings.";
    }

    if (text.contains('discount') ||
        text.contains('promo') ||
        text.contains('offer')) {
      return "🎉 Special offers are announced on our homepage.\nStay tuned for weekly deals and promo codes!";
    }

    if (text.contains('feedback') || text.contains('review')) {
      return "We’d love to hear your feedback! 📝\nPlease email us at support@bitesmart.com or leave a review in the app.";
    }

    if (text.contains('bug') ||
        text.contains('issue') ||
        text.contains('not working') ||
        text.contains('error')) {
      return "Oops! 😓 Sorry for the trouble.\nPlease restart the app. If the problem persists, contact support with a description of the issue.";
    }

    if (text.contains('joke') || text.contains('funny')) {
      return "😄 Why don’t burgers tell secrets?\nBecause they might spill the beans!";
    }

    if (text.contains('about you') ||
        text.contains('who are you') ||
        text.contains('bitesmart')) {
      return "We're BiteSmart — a smart, fast, and friendly food delivery app 🍴.\nWe focus on quality, speed, and customer joy.";
    }

    return "🤖 I'm still learning!\nTry asking about the menu, placing an order, tracking your driver, or app support.";
  }

  void _sendMessage() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final botReply = getSmartResponse(input);
    setState(() {
      _messages.add({'role': 'user', 'content': input});
      _messages.add({'role': 'bot', 'content': botReply});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "BiteSmart Assistant",
        style: TextStyle(color: Colors.orange),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children:
                    _messages.map((msg) {
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment:
                            isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.orange : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['content']!,
                            style: TextStyle(
                              color: isUser ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Close", style: TextStyle(color: Colors.orange)),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
