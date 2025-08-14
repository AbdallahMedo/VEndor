import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BoardItemsView extends StatefulWidget {
  final String boardName;

  const BoardItemsView({super.key, required this.boardName});

  @override
  State<BoardItemsView> createState() => _BoardItemsViewState();
}

class _BoardItemsViewState extends State<BoardItemsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  List<Map<String, dynamic>> _boardComponents = [];
  List<Map<String, dynamic>> _allItems = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBoardItems();
  }
  void _confirmDeleteItem(int index) {
    final item = _boardComponents[index];
    final itemName = item['itemName'] as String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$itemName" from the board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItemFromBoard(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  Future<void> _deleteItemFromBoard(int index) async {
    final item = _boardComponents[index];
    final categoryId = item['categoryId'] as String;
    final itemId = item['itemId'] as String;
    final quantity = item['quantity'] as int;

    final currentQty = await _getOriginalItemQuantity(categoryId, itemId);
    await _updateOriginalItemQuantity(categoryId, itemId, currentQty + quantity);

    setState(() {
      _boardComponents.removeAt(index);
    });

    await _updateBoardComponents();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted from board')),
      );
    }
  }
  Future<void> _loadBoardItems() async {
    setState(() => _isLoading = true);

    final boardDoc =
    await _firestore.collection('boards').doc(widget.boardName).get();
    final data = boardDoc.data();

    if (data != null && data['components'] != null) {
      _boardComponents = List<Map<String, dynamic>>.from(data['components']);
    } else {
      _boardComponents = [];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadAllItems() async {
    List<Map<String, dynamic>> allItems = [];
    final categoriesSnapshot = await _firestore.collection('categories').get();

    for (var categoryDoc in categoriesSnapshot.docs) {
      final itemsSnapshot =
      await categoryDoc.reference.collection('items').get();
      for (var itemDoc in itemsSnapshot.docs) {
        allItems.add({
          'categoryId': categoryDoc.id,
          'categoryName': categoryDoc['name'],
          'itemId': itemDoc.id,
          'name': itemDoc['name'],
          'quantity': itemDoc['quantity'],
        });
      }
    }

    _allItems = allItems;
  }

  Future<int> _getOriginalItemQuantity(String categoryId, String itemId) async {
    final itemDoc = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('items')
        .doc(itemId)
        .get();

    if (itemDoc.exists) {
      return (itemDoc.data()?['quantity'] ?? 0) as int;
    }
    return 0;
  }

  Future<void> _updateOriginalItemQuantity(
      String categoryId, String itemId, int newQuantity) async {
    if (newQuantity <= 0) {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('items')
          .doc(itemId)
          .delete();
    } else {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('items')
          .doc(itemId)
          .update({'quantity': newQuantity});
    }
  }

  Future<void> _updateBoardComponents() async {
    await _firestore.collection('boards').doc(widget.boardName).update({
      'components': _boardComponents,
    });
  }

  void _showAddItemDialog() {
    Map<String, dynamic>? selectedItem;
    final quantityController = TextEditingController();
    final searchController = TextEditingController();

    bool isDialogLoading = true;
    List<Map<String, dynamic>> filteredItems = [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Item to Board'),
          content: StatefulBuilder(
            builder: (context, setState) {
              if (isDialogLoading) {
                _loadAllItems().then((_) {
                  filteredItems = List.from(_allItems);
                  isDialogLoading = false;
                  setState(() {});
                });

                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search items',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            filteredItems = _allItems
                                .where((item) =>
                            item['name']
                                .toLowerCase()
                                .contains(value.toLowerCase()) ||
                                item['categoryName']
                                    .toLowerCase()
                                    .contains(value.toLowerCase()))
                                .toList();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected = selectedItem == item;

                            return ListTile(
                              title: Text(
                                  '${item['name']} (Available: ${item['quantity']})'),
                              subtitle:
                              Text('Category: ${item['categoryName']}'),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                                  : null,
                              selected: isSelected,
                              selectedTileColor: Colors.blue.shade50,
                              onTap: () {
                                setState(() {
                                  selectedItem = item;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedItem == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an item')),
                  );
                  return;
                }

                int qtyToAdd = int.tryParse(quantityController.text) ?? 0;
                if (qtyToAdd <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid quantity')),
                  );
                  return;
                }

                final originalQty = await _getOriginalItemQuantity(
                  selectedItem!['categoryId'],
                  selectedItem!['itemId'],
                );

                if (originalQty < qtyToAdd) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Only $originalQty items available in stock')),
                  );
                  return;
                }

                await _updateOriginalItemQuantity(
                    selectedItem!['categoryId'],
                    selectedItem!['itemId'],
                    originalQty - qtyToAdd);

                int index = _boardComponents.indexWhere((comp) =>
                comp['categoryId'] == selectedItem!['categoryId'] &&
                    comp['itemId'] == selectedItem!['itemId']);

                if (index >= 0) {
                  _boardComponents[index]['quantity'] += qtyToAdd;
                } else {
                  _boardComponents.add({
                    'categoryId': selectedItem!['categoryId'],
                    'categoryName': selectedItem!['categoryName'],
                    'itemId': selectedItem!['itemId'],
                    'itemName': selectedItem!['name'],
                    'quantity': qtyToAdd,
                  });
                }

                await _updateBoardComponents();
                await _loadBoardItems();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item added successfully')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeQuantity(int index, int delta) async {
    final component = _boardComponents[index];
    final categoryId = component['categoryId'];
    final itemId = component['itemId'];
    final currentBoardQty = component['quantity'];

    final originalQty = await _getOriginalItemQuantity(categoryId, itemId);

    if (delta > 0) {
      if (originalQty < delta) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only $originalQty items available to add')),
        );
        return;
      }

      await _updateOriginalItemQuantity(
          categoryId, itemId, originalQty - delta);

      _boardComponents[index]['quantity'] = currentBoardQty + delta;
    } else {
      int decreaseAmount = -delta;
      if (decreaseAmount > currentBoardQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot decrease below zero')),
        );
        return;
      }

      int newBoardQty = currentBoardQty - decreaseAmount;
      await _updateOriginalItemQuantity(
          categoryId, itemId, originalQty + decreaseAmount);

      if (newBoardQty <= 0) {
        _boardComponents.removeAt(index);
      } else {
        _boardComponents[index]['quantity'] = newBoardQty;
      }
    }

    await _updateBoardComponents();
    await _loadBoardItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
            onPressed: _showAddItemDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await _loadBoardItems();
              await _loadAllItems();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _boardComponents.isEmpty
          ? const Center(child: Text("No components in this board."))
          : ListView.builder(
        itemCount: _boardComponents.length,
        itemBuilder: (context, index) {
          final component = _boardComponents[index];
          final itemName = component['itemName'] ?? 'Unknown';
          final quantity = component['quantity'] ?? 0;

          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      itemName[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Qty: $quantity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      IconButton(
                        icon:
                        const Icon(Icons.remove_circle_outline),
                        onPressed: () =>
                            _changeQuantity(index, -1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _changeQuantity(index, 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteItem(index),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
