import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortageItemsPage extends StatefulWidget {
  const ShortageItemsPage({Key? key}) : super(key: key);

  @override
  State<ShortageItemsPage> createState() => _ShortageItemsPageState();
}

class _ShortageItemsPageState extends State<ShortageItemsPage> {
  List<Map<String, dynamic>> shortageItems = [];

  @override
  void initState() {
    super.initState();
    _fetchAllShortageItems();
  }

  Future<void> _fetchAllShortageItems() async {
    final itemsRef = FirebaseFirestore.instance.collectionGroup('items');
    final QuerySnapshot snapshot = await itemsRef.get();
    final limitsDocRef = FirebaseFirestore.instance.collection('shortageLimits').doc('itemLimits');
    final limitsSnapshot = await limitsDocRef.get();

    final Map<String, int> customLimits = {};
    if (limitsSnapshot.exists) {
      final data = limitsSnapshot.data()!;
      data.forEach((key, value) {
        customLimits[key] = value is int ? value : int.tryParse(value.toString()) ?? 1;
      });
    }

    final List<Map<String, dynamic>> allShortageItems = [];

    for (var doc in snapshot.docs) {
      final itemData = doc.data() as Map<String, dynamic>;
      final itemName = itemData['name'] ?? 'Unnamed';
      final quantity = itemData['quantity'] ?? 0;
      final limit = customLimits[itemName] ?? 1;

      if (quantity < limit) {
        allShortageItems.add({
          ...itemData,
          'limit': limit,
        });
      }
    }

    setState(() {
      shortageItems = allShortageItems;
    });
  }

  void _showLimitDialog() async {
    final itemsRef = FirebaseFirestore.instance.collectionGroup('items');
    final QuerySnapshot itemSnapshot = await itemsRef.get();
    final List<QueryDocumentSnapshot> items = itemSnapshot.docs;

    final Map<String, int> customLimits = {}; // itemName -> limit

    final limitsDocRef =
    FirebaseFirestore.instance.collection('shortageLimits').doc('itemLimits');
    final limitsSnapshot = await limitsDocRef.get();
    if (limitsSnapshot.exists) {
      final data = limitsSnapshot.data()!;
      data.forEach((key, value) {
        customLimits[key] = value is int ? value : int.tryParse(value.toString()) ?? 1;
      });
    }

    final Set<String> seenNames = {};
    final List<Map<String, dynamic>> uniqueItems = [];

    for (var doc in items) {
      final itemData = doc.data() as Map<String, dynamic>;
      final name = itemData['name'];
      if (name != null && !seenNames.contains(name)) {
        seenNames.add(name);
        uniqueItems.add(itemData);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        List<Map<String, dynamic>> filteredItems = List.from(uniqueItems);

        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              expand: false,
              maxChildSize: 0.9,
              initialChildSize: 0.8,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Set Shortage Limits Per Item',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            filteredItems = uniqueItems
                                .where((item) =>
                            item['name']
                                ?.toLowerCase()
                                .contains(value.toLowerCase()) ??
                                false)
                                .toList();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final itemName = item['name'];
                            final initialLimit = customLimits[itemName] ?? 1;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        itemName,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        initialValue: initialLimit.toString(),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                          hintText: 'Limit',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 10),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          customLimits[itemName] =
                                              int.tryParse(value) ?? 1;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await limitsDocRef.set(customLimits);
                              Navigator.of(context).pop();
                              _fetchAllShortageItems(); // Refresh list
                            },
                            icon: const Icon(Icons.save,color: Colors.white,),
                            label: const Text('Save',style: TextStyle(color: Colors.white),),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShortageTile(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unnamed';
    final int quantity = item['quantity'] ?? 0;
    final int limit = item['limit'] ?? 1;

    final bool isCritical = quantity < limit;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isCritical
              ? [Colors.red.shade100, Colors.red.shade50]
              : [Colors.green.shade100, Colors.green.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isCritical ? Colors.red : Colors.teal,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Available: $quantity / Limit: $limit',
          style: TextStyle(
            color: isCritical ? Colors.red.shade800 : Colors.teal.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          isCritical ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
          color: isCritical ? Colors.red : Colors.green,
          size: 28,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shortage Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllShortageItems,
            tooltip: 'Refresh Items',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllShortageItems,
        color: Colors.red.shade100,
        backgroundColor: Colors.red.shade50,
        child: shortageItems.isEmpty
            ?  ListView(
          children: [Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('No shortage items'),
          ))],
        )
            : ListView.builder(
          itemCount: shortageItems.length,
          itemBuilder: (context, index) {
            final item = shortageItems[index];
            return _buildShortageTile(item);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLimitDialog,
        label: const Text(
          "Set Limits",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.settings),
        backgroundColor: const Color(0xFF4DB6AC),
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

}
