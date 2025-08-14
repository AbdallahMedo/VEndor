import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DeletionRequestsView extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DeletionRequestsView({super.key});

  // Function to simulate creating a deletion request (for demo/testing)
  Future<void> createDeletionRequestExample() async {
    final user = FirebaseAuth.instance.currentUser;
    final requestedBy = user?.displayName ?? user?.email ?? "Unknown";

    await _firestore.collection('deletion_requests').add({
      'name': 'Test Item',
      'requestedQuantity': 5,
      'categoryId': 'cat123',
      'categoryName': 'Test Category',
      'itemId': 'item123',
      'note': 'Damaged',
      'requestedBy': requestedBy,
      'requestedAt': FieldValue.serverTimestamp(), // ✅ Add timestamp
    });
  }

  Future<void> _confirmDeletion(BuildContext context, DocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    final deletedBy = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : (user?.email?.isNotEmpty ?? false)
        ? user!.email!
        : 'Unknown User';
    final data = doc.data() as Map<String, dynamic>;

    final itemRef = _firestore
        .collection('categories')
        .doc(data['categoryId'])
        .collection('items')
        .doc(data['itemId']);

    final deletedRef = _firestore.collection('deleted_synthesizes').doc();

    try {
      final itemSnap = await itemRef.get();
      final currentQuantity = itemSnap.exists ? (itemSnap.data()?['quantity'] ?? 0) : 0;

      await deletedRef.set({
        'name': data['name'],
        'deletedQuantity': data['requestedQuantity'],
        'deletedAt': FieldValue.serverTimestamp(), // ✅ Confirmation time
        'originalQuantity': currentQuantity,
        'categoryId': data['categoryId'],
        'categoryName': data['categoryName'],
        'note': data['note'],
        'requestedBy': data['requestedBy'],
        'deletedBy': deletedBy,
        'requestedAt': data['requestedAt'], // ✅ Keep original request time
      });

      if (data['requestedQuantity'] >= currentQuantity) {
        await itemRef.delete();
      } else {
        await itemRef.update({'quantity': currentQuantity - data['requestedQuantity']});
      }

      await doc.reference.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request confirmed and item deleted")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> _rejectRequest(BuildContext context, DocumentSnapshot doc) async {
    await doc.reference.delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Request rejected")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Deletion Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await createDeletionRequestExample();
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('deletion_requests')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(child: Text("No pending deletion requests"));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final doc = requests[index];
              final request = doc.data() as Map<String, dynamic>;

              // Format requestedAt timestamp
              String formattedRequestedAt = 'Unknown Time';
              if (request['requestedAt'] is Timestamp) {
                final DateTime dateTime = (request['requestedAt'] as Timestamp).toDate();
                formattedRequestedAt = DateFormat('yyyy-MM-dd – hh:mm a').format(dateTime);
              }

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text("${request['name']} (Qty: ${request['requestedQuantity']})"),
                  subtitle: Text(
                    "Note: ${request['note']}\n"
                        "By: ${request['requestedBy']}\n"
                        "Requested At: $formattedRequestedAt",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _confirmDeletion(context, doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => _rejectRequest(context, doc),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
