import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';

class DeliveredViews extends StatefulWidget {
  @override
  _DeliveredViewsState createState() => _DeliveredViewsState();
}

class _DeliveredViewsState extends State<DeliveredViews> {
  final firebaseService = FirebaseServiceForItems();
  Map<String, int> boardSelectionCounts = {};
  List<String> boardNames = [];
  List<String> filteredBoardNames = [];
  final TextEditingController searchController = TextEditingController();

  bool isSearching = false;
  bool isLoading = false;


  @override
  void initState() {
    super.initState();
    fetchBoardData();
    searchController.addListener(filterBoards);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchBoardData() async {
    final snapshot = await FirebaseFirestore.instance.collection('boards').get();
    final Map<String, int> counts = {};
    final List<String> names = [];

    for (var doc in snapshot.docs) {
      names.add(doc.id);
      counts[doc.id] = doc.data()['selectionCount'] ?? 0;
    }

    setState(() {
      boardNames = names;
      filteredBoardNames = names;
      boardSelectionCounts = counts;
    });
  }

  void filterBoards() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredBoardNames = query.isEmpty
          ? boardNames
          : boardNames.where((board) => board.toLowerCase().contains(query)).toList();
    });
  }

  void _showReceiveSheet() {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedBoard;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Deliver Board",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Select Board",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: boardSelectionCounts.keys.map((boardName) {
                    return DropdownMenuItem(
                      value: boardName,
                      child: Text(boardName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedBoard = value;
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // This allows only digits
                  ],
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: "Delivered To (Note)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final qty = int.tryParse(quantityController.text);
                      final note = noteController.text.trim();
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid quantity.')),
                        );
                        return;
                      }
                      if (selectedBoard == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a board.')),
                        );
                        return;
                      }
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter who it was delivered to.')),
                        );
                        return;
                      }

                      final currentCount = boardSelectionCounts[selectedBoard!] ?? 0;
                      if (qty > currentCount) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Warning"),
                            content: Text(
                              "You cannot receive more than the available quantity.\nAvailable: $currentCount",
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

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Confirm"),
                          content: const Text("These boards are delivered."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Confirm"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        setState(() {
                          isLoading = true;
                        });

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        try {
                          final newCount = currentCount - qty;
                          await firebaseService.updateBoardSelectionCount(selectedBoard!, newCount);
                          await _saveReceiveLog(selectedBoard!, qty, note);

                          setState(() {
                            boardSelectionCounts[selectedBoard!] = newCount;
                          });

                          Navigator.pop(context); // Close the bottom sheet
                          Navigator.pop(context); // Close the loading dialog
                        } catch (e) {
                          Navigator.pop(context); // Close the loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error occurred: $e')),
                          );
                        } finally {
                          setState(() {
                            isLoading = false;
                          });
                        }
                      }

                    },
                    child: const Text("Confirm Deliver"),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveReceiveLog(String boardName, int qtyReceived, String note) async {
    final user = FirebaseAuth.instance.currentUser;
    final receiver = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : 'Unknown User';

    await FirebaseFirestore.instance.collection('board_receives').add({
      'boardName': boardName,
      'recievedBy': receiver,
      'quantity': qtyReceived,
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? const Text("Deliver", style: TextStyle(color: Colors.white))
            : TextField(
          controller: searchController,
          autofocus: true,
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary),
          cursorColor: theme.colorScheme.onPrimary,
          decoration: InputDecoration(
            hintText: 'Search Boards',
            hintStyle: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.7)),
            border: InputBorder.none,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.clear : Icons.search, color: theme.colorScheme.onPrimary),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  searchController.clear();
                  filteredBoardNames = boardNames;
                }
                isSearching = !isSearching;
              });
            },
          ),
          IconButton(
            onPressed: fetchBoardData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
        elevation: 4,
      ),
      body: RefreshIndicator(
        onRefresh: fetchBoardData,
        child: filteredBoardNames.isEmpty
            ? ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Text(
                  "No boards found",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: filteredBoardNames.length,
          itemBuilder: (_, index) {
            final name = filteredBoardNames[index];
            final count = boardSelectionCounts[name] ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 5,
              shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: count > 0
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    "Count: $count",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: count > 0
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onTap: _showReceiveSheet,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReceiveSheet,
        label: const Text("Deliver"),
        icon: const Icon(Icons.inventory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
