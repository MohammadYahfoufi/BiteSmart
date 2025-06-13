import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _stockController = TextEditingController();
  final _defaultStockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    resetDailyStock();
  }

  void resetDailyStock() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final metaRef = FirebaseFirestore.instance
        .collection('meta')
        .doc('stock_reset');

    final metaDoc = await metaRef.get();
    final lastReset =
        metaDoc.exists && metaDoc['lastReset'] != null
            ? (metaDoc['lastReset'] as Timestamp).toDate()
            : DateTime(2000);

    final isSameDay =
        lastReset.year == today.year &&
        lastReset.month == today.month &&
        lastReset.day == today.day;

    if (!isSameDay) {
      final foods = await FirebaseFirestore.instance.collection('foods').get();
      for (var doc in foods.docs) {
        final data = doc.data();
        if (data.containsKey('defaultStock')) {
          await doc.reference.update({'stock': data['defaultStock']});
        }
      }
      await metaRef.set({'lastReset': Timestamp.fromDate(today)});
      debugPrint('✅ Stock reset to default for today');
    } else {
      debugPrint('🔄 Stock already reset today');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildOrdersList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by item name or status...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.orange),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
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

              final filtered =
                  orders.where((order) {
                    final data = order.data() as Map<String, dynamic>;
                    final status =
                        (data['status'] ?? '').toString().toLowerCase();
                    final items = List.from(data['items'] ?? []);
                    final itemNames = items
                        .map((i) => (i['name'] ?? '').toString().toLowerCase())
                        .join(' ');
                    return status.contains(_searchQuery) ||
                        itemNames.contains(_searchQuery);
                  }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No matching orders.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final order = filtered[index];
                  final data = order.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final time = (data['timestamp'] as Timestamp?)?.toDate();
                  final items = List.from(data['items']);
                  final summary = items
                      .map((item) => '${item['quantity']} x ${item['name']}')
                      .join(', ');

                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(
                        summary,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time: ${time != null ? time.toLocal().toString() : 'Unknown'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Status: ${status == 'delivered' ? 'Delivered ✅' : 'Active 🚚'}',
                            style: TextStyle(
                              color:
                                  status == 'delivered'
                                      ? Colors.green
                                      : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();

  Future<void> _addFood() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final subtitle = _subtitleController.text.trim();
    final category = _categoryController.text.trim();
    final image = _imageUrlController.text.trim();

    if (name.isEmpty || image.isEmpty || price == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, image, and price.')),
      );
      return;
    }

    await _firestore.collection('foods').add({
      'name': name,
      'price': price,
      'subtitle': subtitle.isNotEmpty ? subtitle : '',
      'image': image,
      'category': category.isNotEmpty ? category : 'Uncategorized',
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'defaultStock': int.tryParse(_defaultStockController.text.trim()) ?? 0,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Food added successfully!')));

    _nameController.clear();
    _priceController.clear();
    _subtitleController.clear();
    _categoryController.clear();
    _imageUrlController.clear();
  }

  Future<void> _deleteFood(String id) async {
    await _firestore.collection('foods').doc(id).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Food deleted')));
  }

  Future<void> _updateFood(String id) async {
    await _firestore.collection('foods').doc(id).update({
      'name': _nameController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'subtitle': _subtitleController.text.trim(),
      'category': _categoryController.text.trim(),
      'image': _imageUrlController.text.trim(),
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'defaultStock': int.tryParse(_defaultStockController.text.trim()) ?? 0,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Food updated!')));
  }

  Future<void> fixOldFoodsWithStock() async {
    final foods = await FirebaseFirestore.instance.collection('foods').get();

    for (final doc in foods.docs) {
      final data = doc.data();
      if (!data.containsKey('stock') || !data.containsKey('defaultStock')) {
        await doc.reference.update({'stock': 10, 'defaultStock': 10});
      }
    }

    debugPrint('Fixed stock fields for old food items.');
  }

  void _showFoodDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      _nameController.text = doc['name'];
      _priceController.text = doc['price'].toString();
      _subtitleController.text = doc['subtitle'];
      _categoryController.text = doc['category'] ?? '';
      _imageUrlController.text = doc['image'];
      _stockController.text = doc['stock']?.toString() ?? '';
      _defaultStockController.text = doc['defaultStock']?.toString() ?? '';
    } else {
      _nameController.clear();
      _priceController.clear();
      _subtitleController.clear();
      _categoryController.clear();
      _imageUrlController.clear();
      _stockController.clear();
      _defaultStockController.clear();
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              doc == null ? 'Add Food' : 'Edit Food',
              style: const TextStyle(color: Colors.orange),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  _buildField('Name', _nameController),
                  _buildField(
                    'Price',
                    _priceController,
                    keyboardType: TextInputType.number,
                  ),
                  _buildField('Subtitle', _subtitleController),
                  _buildField('Category', _categoryController),
                  _buildField('Image URL', _imageUrlController),
                  _buildField(
                    'Current Stock',
                    _stockController,
                    keyboardType: TextInputType.number,
                  ),
                  _buildField(
                    'Default Stock',
                    _defaultStockController,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
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
                  if (doc == null) {
                    await _addFood();
                  } else {
                    await _updateFood(doc.id);
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                ),
                child: Text(doc == null ? 'Add' : 'Update'),
              ),
            ],
          ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.orange),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.orange),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.orangeAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('foods').snapshots(),
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
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No food items yet.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
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
                  doc['name'] ?? 'No Name',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['subtitle'] ?? 'No Description',
                      style: const TextStyle(color: Colors.white70),
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
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                      onPressed: () => _showFoodDialog(doc: doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFood(doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFABMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.orange),
                  title: const Text(
                    'Add Food',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showFoodDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.orange),
                  title: const Text(
                    'View Orders',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/adminOrders');
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: const Text('Admin Panel'),
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Foods'), Tab(text: 'Orders')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildFoodList(), _buildOrdersList()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black,
        onPressed: _showFABMenu,
        child: const Icon(Icons.more_vert),
      ),
    );
  }
}
