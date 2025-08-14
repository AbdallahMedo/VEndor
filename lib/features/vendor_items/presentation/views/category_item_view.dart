import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import '../../category_services/item_card.dart';

class CategoryItemsView extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final bool isAdmin;

  const CategoryItemsView({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.isAdmin,
  });

  @override
  State<CategoryItemsView> createState() => _CategoryItemsViewState();
}

class _CategoryItemsViewState extends State<CategoryItemsView> {
  bool _isSearchActive = false;
  String _searchQuery = "";

  CollectionReference get _itemsRef => FirebaseFirestore.instance
      .collection('categories')
      .doc(widget.categoryId)
      .collection('items');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildItemsList(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: _isSearchActive
          ? TextField(
        onChanged: (query) => setState(() => _searchQuery = query),
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search items...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      )
          : Text(
        'Items in ${widget.categoryName}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.indigoAccent,
      actions: [
        IconButton(
          icon: Icon(
            _isSearchActive ? Icons.close : Icons.search,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              if (_isSearchActive) _searchQuery = "";
              _isSearchActive = !_isSearchActive;
            });
          },
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _itemsRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No items found."));
        }

        final items = _filterItems(snapshot.data!.docs);

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final itemDoc = items[index];
            final itemData = itemDoc.data() as Map<String, dynamic>;
            final itemId = itemDoc.id;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ItemCard(
                name: itemData['name'] ?? 'Unnamed',
                quantity: itemData['quantity'] ?? 1,
                onDelete: () => _showDeleteDialog(context, itemData, itemId),
                onAdd: () => _showIncreaseQuantityDialog(context, itemData, itemId),
                isAdmin: widget.isAdmin,
              ),
            );
          },
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterItems(List<QueryDocumentSnapshot> items) {
    if (_searchQuery.isEmpty) return items;

    return items.where((item) {
      final itemData = item.data() as Map<String, dynamic>;
      final name = itemData['name']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showDeleteDialog(
      BuildContext context, Map<String, dynamic> itemData, String itemId) {
    final qtyController = TextEditingController();
    bool deleteAll = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Delete Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Item: ${itemData['name']}"),
              Text("Available quantity: ${itemData['quantity']}"),
              const SizedBox(height: 10),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                enabled: !deleteAll,
                decoration: const InputDecoration(labelText: "Quantity to delete"),
              ),
              CheckboxListTile(
                title: const Text("Delete all"),
                value: deleteAll,
                onChanged: (value) => setState(() => deleteAll = value ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final int currentQty = itemData['quantity'] ?? 1;
                final deleteQty = deleteAll
                    ? currentQty
                    : int.tryParse(qtyController.text.trim());
// <=
                if (deleteQty == null || deleteQty < 0 || deleteQty > currentQty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        deleteQty == null || deleteQty < 0
                            ? "Enter a valid quantity to delete"
                            : "Only $currentQty available. You can't delete more.",
                      ),
                    ),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                final deletedBy = user?.displayName?.isNotEmpty == true
                    ? user!.displayName!
                    : user?.email ?? 'Unknown';

                await FirebaseServiceForItems().decreaseItemQuantity(
                  categoryName: widget.categoryName,
                  itemId: itemId,
                  itemName: itemData['name'],
                  // currentQuantity: currentQty,
                  deleteQuantity: deleteQty,
                  deletedBy: deletedBy,
                );

                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }



  void _showIncreaseQuantityDialog(
      BuildContext context, Map<String, dynamic> itemData, String itemId) {
    int quantity = 1;
    final quantityController = TextEditingController(text: quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Increase Quantity"),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (quantity > 1) {
                      setState(() {
                        quantity--;
                        quantityController.text = quantity.toString();
                      });
                    }
                  },
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      final newVal = int.tryParse(value);
                      if (newVal != null && newVal > 0) {
                        setState(() => quantity = newVal);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      quantity++;
                      quantityController.text = quantity.toString();
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              final addedBy = (user?.displayName?.isNotEmpty ?? false)
                  ? user!.displayName!
                  : (user?.email ?? 'Unknown');

              await FirebaseServiceForItems().increaseItemQuantityFast(
                categoryName: widget.categoryId, // categoryName is your doc ID
                itemId: itemId,
                itemName: itemData['name'] ?? 'Unknown',
                addedQuantity: quantity,
                addedBy: addedBy,
              );

              Navigator.pop(context);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}
