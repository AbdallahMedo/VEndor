import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vendor_chem_tech/features/synthesize_view/shimmer/shimmer.dart';

class SynthesizeView extends StatefulWidget {
  const SynthesizeView({Key? key}) : super(key: key);

  @override
  State<SynthesizeView> createState() => _SynthesizeViewState();
}

class _SynthesizeViewState extends State<SynthesizeView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterItems();
      });
    });
  }

  Future<void> _fetchItems() async {
    final allItems = await _getAllItems();
    setState(() {
      _allItems = allItems;
      if (_searchQuery.isEmpty) {
        _filteredItems = allItems;
      } else {
        _filteredItems = allItems.where((item) =>
            item['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
      }
    });
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = _allItems;
    } else {
      _filteredItems = _allItems
          .where((item) => item['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  // Future<List<Map<String, dynamic>>> _getAllItems() async {
  //   List<Map<String, dynamic>> allItems = [];
  //   final categoriesSnapshot = await _firestore.collection('categories').get();
  //
  //   for (var categoryDoc in categoriesSnapshot.docs) {
  //     final itemsSnapshot =
  //     await categoryDoc.reference.collection('items').get();
  //     for (var itemDoc in itemsSnapshot.docs) {
  //       allItems.add({
  //         'categoryId': categoryDoc.id,
  //         'categoryName': categoryDoc['name'],
  //         'itemId': itemDoc.id,
  //         'name': itemDoc['name'],
  //         'quantity': int.tryParse(itemDoc['quantity'].toString()) ?? 0,
  //       });
  //     }
  //   }
  //   return allItems;
  // }
  Future<List<Map<String, dynamic>>> _getAllItems() async {
    final categoriesSnapshot = await _firestore.collection('categories').get();

    // Fetch items for each category in parallel
    final futures = categoriesSnapshot.docs.map((categoryDoc) async {
      final itemsSnapshot = await categoryDoc.reference.collection('items').get();
      return itemsSnapshot.docs.map((itemDoc) {
        return {
          'categoryId': categoryDoc.id,
          'categoryName': categoryDoc['name'],
          'itemId': itemDoc.id,
          'name': itemDoc['name'],
          'quantity': int.tryParse(itemDoc['quantity'].toString()) ?? 0,
        };
      }).toList();
    }).toList();

    final allItemsNested = await Future.wait(futures);
    return allItemsNested.expand((list) => list).toList();
  }

  /// Ensure user doc exists, create if not
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("No authenticated user found.");
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      // Create new user doc with default isAdmin = false
      await docRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return await docRef.get(); // get the newly created doc
    }

    return docSnapshot;
  }

  Future<void> _handleDeleteQuantity(
      String categoryId,
      String categoryName,
      String itemId,
      String name,
      int currentQuantity,
      int deleteQuantity,
      String note,
      ) async {
    final itemRef = _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('items')
        .doc(itemId);
    final deletedRef = _firestore.collection('deleted_synthesizes').doc();
    final deletionRequestRef = _firestore.collection('deletion_requests').doc();

    final user = FirebaseAuth.instance.currentUser;
    final deletedBy = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : 'Unknown User';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get user doc with creation if not exists
      final userDoc = await _getUserDoc();
      final isAdmin = userDoc.data()?['isAdmin'] == true;

      if (isAdmin) {
        // Admin deletes directly, no request sent
        await deletedRef.set({
          'name': name,
          'deletedQuantity': deleteQuantity,
          'deletedAt': FieldValue.serverTimestamp(),
          'originalQuantity': currentQuantity,
          'categoryId': categoryId,
          'categoryName': categoryName,
          'deletedBy': deletedBy,
          'note': note,
        });

        if (deleteQuantity >= currentQuantity) {
          await itemRef.delete();
        } else {
          await itemRef.update({'quantity': currentQuantity - deleteQuantity});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Deleted and archived successfully")),
          );
        }
      } else {
        // User sends a deletion request

        await deletionRequestRef.set({
          'name': name,
          'requestedQuantity': deleteQuantity,
          'requestedAt': FieldValue.serverTimestamp(),
          'originalQuantity': currentQuantity,
          'categoryId': categoryId,
          'categoryName': categoryName,
          'requestedBy': deletedBy,
          'userId': user!.uid,
          'note': note,
          'itemId': itemId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Deletion request sent for admin approval")),
          );
        }
      }

      await _fetchItems();
    } catch (e) {
      print("Error handling deletion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred during deletion")),
      );
    } finally {
      Navigator.pop(context); // remove loading
    }
  }

  void _promptDeleteItem(Map<String, dynamic> item) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${item['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity to delete",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Reason / Notes",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              final int deleteQuantity = int.tryParse(quantityController.text) ?? 0;
              final String note = noteController.text.trim();
              if (deleteQuantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Quantity must be more than 0")),
                );
                return;
              }
              if (deleteQuantity > item['quantity']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("You only have ${item['quantity']} items")),
                );
                return;
              }
              Navigator.pop(context);
              _handleDeleteQuantity(
                item['categoryId'],
                item['categoryName'],
                item['itemId'],
                item['name'],
                item['quantity'],
                deleteQuantity,
                note,
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _filteredItems = _allItems;
      }
      _isSearching = !_isSearching;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchItems,
        child: _filteredItems.isEmpty
            ? ListView(
          children: [
            // Center(
            //   heightFactor: 20,
            //   child: Text(
            //     "There is nothing found",
            //     style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            //   ),
            // ),
            ShimmerLoadingColumn(),
            ShimmerLoadingColumn(),
            ShimmerLoadingColumn(),
            ShimmerLoadingColumn(),
            ShimmerLoadingColumn(),
            ShimmerLoadingColumn(),
          ],
        )
            : ListView.builder(
          itemCount: _filteredItems.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final item = _filteredItems[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        item['name'][0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${item['categoryName']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quantity: ${item['quantity']}',
                            style: const TextStyle(fontSize: 16,fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _promptDeleteItem(item);
                      },
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                      tooltip: "Delete quantity",
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: !_isSearching
          ? const Text('Defected View')
          : TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search items...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white60),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
          tooltip: _isSearching ? "Close search" : "Search",
        ),
        IconButton(onPressed: _fetchItems, icon: Icon(Icons.refresh))
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
