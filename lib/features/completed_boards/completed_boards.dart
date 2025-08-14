import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/services.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';

class CompletedBoardView extends StatefulWidget {
  const CompletedBoardView({super.key});

  @override
  State<CompletedBoardView> createState() => _CompletedBoardViewState();
}
class _CompletedBoardViewState extends State<CompletedBoardView> {
  final FirebaseServiceForItems firebase = FirebaseServiceForItems();
  final TextEditingController _boardNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String? selectedItemId;
  String? selectedItemName;
  String? selectedCategoryId;
  bool isLoading = false;

  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> selectedComponents = [];
  Map<String, int> availableQuantities = {};

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
    });

    final categories = await firebase.getCategories();
    allItems.clear();
    availableQuantities.clear();

    final allItemResults = await Future.wait(
      categories.map((cat) async {
        final items = await firebase.searchItems(cat.id, '');
        return items.map((item) {
          return {
            'itemId': item['id'] ?? '',
            'itemName': item['name'] ?? '',
            'categoryId': cat.id,
            'categoryName': cat.name,
          };
        }).toList();
      }),
    );

    final flatItems = allItemResults.expand((list) => list).toList();
    allItems = flatItems;

    final quantityFutures = allItems.map((item) async {
      final itemId = item['itemId'] as String;
      final categoryId = item['categoryId'] as String;
      final qty = await firebase.getAvailableQuantity(categoryId, itemId);
      return MapEntry(itemId, qty.toInt());
    });

    final quantityResults = await Future.wait(quantityFutures);
    availableQuantities = Map.fromEntries(quantityResults);

    final uniqueItemsMap = <String, Map<String, dynamic>>{};
    for (var item in allItems) {
      final id = item['itemId'] ?? '';
      if (!uniqueItemsMap.containsKey(id)) {
        uniqueItemsMap[id] = item;
      }
    }
    allItems = uniqueItemsMap.values.toList();

    setState(() {
      selectedItemId = null;
      selectedItemName = null;
      selectedCategoryId = null;
      isLoading = false;
    });
  }

  void _addComponentToList() {
    if (selectedItemId == null || _quantityController.text.isEmpty) return;

    int requestedQty = int.tryParse(_quantityController.text) ?? 0;
    if (requestedQty <= 0) return;

    int currentAvailable = availableQuantities[selectedItemId!] ?? 0;

    if (requestedQty > currentAvailable) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Insufficient Quantity"),
          content: Text(
            "Only $currentAvailable available for '${selectedItemName ?? ''}'. Please reduce the quantity.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    int existingIndex = selectedComponents
        .indexWhere((comp) => comp['itemId'] == selectedItemId);

    if (existingIndex >= 0) {
      int existingQty =
          selectedComponents[existingIndex]['quantity'] as int? ?? 0;
      selectedComponents[existingIndex]['quantity'] =
          existingQty + requestedQty;
    } else {
      selectedComponents.add({
        'itemId': selectedItemId,
        'itemName': selectedItemName,
        'categoryId': selectedCategoryId,
        'quantity': requestedQty,
      });
    }

    availableQuantities[selectedItemId!] = currentAvailable - requestedQty;

    _quantityController.clear();
    selectedItemId = null;
    selectedItemName = null;
    selectedCategoryId = null;

    setState(() {});
  }

  Future<void> _createBoardAsCategory() async {
    if (_boardNameController.text.isEmpty || selectedComponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter board name and add components.")),
      );
      return;
    }

    final boardName = _boardNameController.text.trim();

    final existingBoard = await FirebaseFirestore.instance
        .collection('boards')
        .doc(boardName)
        .get();

    if (existingBoard.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Board '$boardName' already exists. Use a new name.")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final addedBy = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : 'Unknown User';

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('boards').doc(boardName).set({
      'boardName': boardName,
      'addedBy': addedBy,
      'components': selectedComponents,
      'createdAt': FieldValue.serverTimestamp(),
    });

    selectedComponents.clear();
    unawaited(loadItems());

    setState(() => isLoading = false);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Board '$boardName' created successfully!")),
    );
  }

  @override
  void dispose() {
    _boardNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Completed Board"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _boardNameController,
                        decoration: InputDecoration(
                          labelText: 'Board Name',
                          prefixIcon: const Icon(Icons.dashboard),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Searchable Items Dropdown
                      DropdownSearch<Map<String, dynamic>>(
                        items: allItems,
                        itemAsString: (item) => item['itemName'] ?? '',
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: const TextFieldProps(
                            decoration: InputDecoration(
                              labelText: "Search Items",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          menuProps: MenuProps(
                            borderRadius: BorderRadius.circular(8),
                            elevation: 4,
                          ),
                        ),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: "Select Item",
                            prefixIcon: const Icon(Icons.inventory_2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        selectedItem: selectedItemId == null
                            ? null
                            : allItems.firstWhere(
                              (item) => item['itemId'] == selectedItemId,
                          orElse: () => <String, dynamic>{},
                        ),
                        onChanged: (item) {
                          if (item != null) {
                            setState(() {
                              selectedItemId = item['itemId'] as String?;
                              selectedItemName = item['itemName'] as String?;
                              selectedCategoryId = item['categoryId'] as String?;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: "Quantity",
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _addComponentToList,
                            icon: const Icon(Icons.add),
                            label: const Text("Add"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Board Components",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Total Components: ${selectedComponents.length}",
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              if (selectedComponents.isEmpty)
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      Text(
                        "No components added yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedComponents.length,
                  itemBuilder: (_, index) {
                    final comp = selectedComponents[index];
                    final itemId = comp['itemId'] as String? ?? '';
                    int compQty = comp['quantity'] as int? ?? 0;
                    int availableQty = availableQuantities[itemId] ?? 0;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    comp['itemName'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      availableQuantities[itemId] =
                                          availableQty + compQty;
                                      selectedComponents.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    "ID: ${comp['itemId']}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.blue[50],
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    "Category: ${comp['categoryId']}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.green[50],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Quantity",
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline,
                                          color: Colors.red),
                                      onPressed: () {
                                        if (compQty > 1) {
                                          setState(() {
                                            comp['quantity'] = compQty - 1;
                                            availableQuantities[itemId] =
                                                availableQty + 1;
                                          });
                                        } else {
                                          setState(() {
                                            selectedComponents.removeAt(index);
                                            availableQuantities[itemId] =
                                                availableQty + 1;
                                          });
                                        }
                                      },
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        compQty.toString(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline,
                                          color: Colors.green),
                                      onPressed: () {
                                        if (availableQty > 0) {
                                          setState(() {
                                            comp['quantity'] = compQty + 1;
                                            availableQuantities[itemId] =
                                                availableQty - 1;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Available in stock: $availableQty",
                              style: TextStyle(
                                color: availableQty > 0 ? Colors.green : Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _createBoardAsCategory,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Create Board",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}