import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManufacturingOrderView extends StatefulWidget {
  const ManufacturingOrderView({Key? key}) : super(key: key);

  @override
  State<ManufacturingOrderView> createState() => _ManufacturingOrderViewState();
}

class _ManufacturingOrderViewState extends State<ManufacturingOrderView> {
  bool isAdmin = false;
  List<String> boardNames = [];
  String? selectedBoard;
  Set<String> selectedRequestIds = {};
  bool isLoading = false;

  final TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadBoards();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();
      setState(() {
        isAdmin = doc['isAdmin'] == true;
      });
    }
  }

  Future<void> _loadBoards() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('boards').get();
    setState(() {
      boardNames = snapshot.docs
          .map((doc) => (doc.data()['boardName'] ?? doc.id).toString())
          .toList();
    });
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final quantity = int.tryParse(quantityController.text);

    if (selectedBoard == null || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select a board and enter valid quantity.")),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      final existingQuery = await firestore
          .collection('manufacturing_requests')
          .where('boardName', isEqualTo: selectedBoard)
          .get();

      String message;
      if (existingQuery.docs.isNotEmpty) {
        final existingDoc = existingQuery.docs.first;
        final existingQuantity = existingDoc['quantity'] as int? ?? 0;

        await existingDoc.reference.update({
          'quantity': existingQuantity + quantity,
          'requestedBy': user?.email ?? 'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        });

        message = "Request updated successfully.";
      } else {
        await firestore.collection('manufacturing_requests').add({
          'requestedBy': user?.email ?? 'Unknown',
          'boardName': selectedBoard,
          'quantity': quantity,
          'timestamp': DateTime.now().toIso8601String(),
        });

        message = "Manufacturing request submitted.";
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting request: ${e.toString()}")),
      );
      return;
    }

    setState(() {
      selectedBoard = null;
      quantityController.clear();
    });
  }

  Future<void> _calculateSelectedRequests() async {
    if (selectedRequestIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No requests selected.")));
      return;
    }

    setState(() => isLoading = true);

    Map<String, Map<String, dynamic>> itemTotals = {}; // key: categoryId|itemId

    for (String requestId in selectedRequestIds) {
      final requestSnap = await FirebaseFirestore.instance
          .collection('manufacturing_requests')
          .doc(requestId)
          .get();

      if (!requestSnap.exists) continue;

      final requestData = requestSnap.data()!;
      final boardName = requestData['boardName'];
      final qty = requestData['quantity'];

      final boardSnap = await FirebaseFirestore.instance
          .collection('boards')
          .doc(boardName)
          .get();

      final components =
          boardSnap.data()?['components'] as List<dynamic>? ?? [];

      for (var comp in components) {
        final itemId = comp['itemId'];
        final categoryId = comp['categoryId'];
        final itemName = comp['itemName'] ?? 'Unknown';
        final unitQty = comp['quantity'] ?? 0;

        if (itemId == null || categoryId == null || unitQty == null) continue;

        final key = '$categoryId|$itemId';
        final totalQty = (unitQty * qty).toInt();

        if (!itemTotals.containsKey(key)) {
          itemTotals[key] = {
            'itemName': itemName,
            'categoryId': categoryId,
            'itemId': itemId,
            'totalQuantity': totalQty,
          };
        } else {
          itemTotals[key]!['totalQuantity'] += totalQty;
        }
      }
    }

    for (final key in itemTotals.keys) {
      final itemData = itemTotals[key]!;
      final categoryId = itemData['categoryId'];
      final itemId = itemData['itemId'];

      final itemSnap = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .collection('items')
          .doc(itemId)
          .get();

      final availableQty = itemSnap.data()?['quantity'] ?? 0;
      itemData['availableQuantity'] = availableQty;
    }

    setState(() => isLoading = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Item Requirements Summary",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(thickness: 1),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: itemTotals.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = itemTotals.values.elementAt(index);
                    final itemName = item['itemName'];
                    final available = item['availableQuantity'];
                    final needed = item['totalQuantity'];
                    final isEnough = available >= needed;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isEnough ? Colors.green[50] : Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEnough ? Icons.check : Icons.warning,
                            color: isEnough ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(
                          itemName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Column(
                              children: [
                                _buildQuantityIndicator(
                                    "Available", available, Colors.blue),
                                const SizedBox(width: 16),
                                _buildQuantityIndicator(
                                    "Needed", needed, Colors.orange),
                              ],
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isEnough ? Colors.green[50] : Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isEnough ? "In Stock" : "Shortage",
                            style: TextStyle(
                              color: isEnough ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuantityIndicator(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Manufacturing Orders",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          if (isAdmin) ...[
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBoard,
                      decoration: InputDecoration(
                        labelText: "Select Board",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.dashboard),
                      ),
                      hint: const Text("Select a board"),
                      items: boardNames.map((board) {
                        return DropdownMenuItem(
                          value: board,
                          child: Text(
                            board,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedBoard = val),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Quantity",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _submitRequest,
                      icon: const Icon(Icons.add),
                      label: const Text("Submit Request"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  "Manufacturing Requests",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                ),
                const Spacer(),
                if (isAdmin && selectedRequestIds.isNotEmpty)
                  Text(
                    "${selectedRequestIds.length} selected",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildRequestList()),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: isLoading ? null : _calculateSelectedRequests,
              icon: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : const Icon(
                      Icons.calculate,
                      color: Colors.white,
                    ),
              label: isLoading
                  ? const Text(
                      "Calculating...",
                      style: TextStyle(color: Colors.white),
                    )
                  : const Text(
                      "Calculate",
                      style: TextStyle(color: Colors.white),
                    ),
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildRequestList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('manufacturing_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No manufacturing requests found",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final docId = doc.id;
            final isSelected = selectedRequestIds.contains(docId);

            final String boardName = data['boardName'] ?? 'Unknown';
            final int quantity = data['quantity'] ?? 0;
            final String requestedBy = data['requestedBy'] ?? 'N/A';
            final String timestamp = DateTime.parse(data['timestamp'])
                .toLocal()
                .toString()
                .split('.')[0];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.white,
              child: InkWell(
                onTap: () {
                  if (isAdmin) {
                    setState(() {
                      if (isSelected) {
                        selectedRequestIds.remove(docId);
                      } else {
                        selectedRequestIds.add(docId);
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (isAdmin)
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedRequestIds.add(docId);
                              } else {
                                selectedRequestIds.remove(docId);
                              }
                            });
                          },
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )
                      else
                        const SizedBox(width: 0),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row with boardName and quantity
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    boardName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                              ],
                            ),
                            const SizedBox(height: 8),

                            // Column with email and date below
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        requestedBy,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        timestamp,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "×$quantity",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

///////abdalla ayman
