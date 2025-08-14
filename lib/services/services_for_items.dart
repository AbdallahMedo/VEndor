  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
import '../features/vendor_items/category_services/category_model.dart';
  class FirebaseServiceForItems {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    Future<void> editItemNameGlobally({
      required String categoryId,
      required String itemId,
      required String oldName,
      required String newName,
      required String updatedBy,
    }) async {
      final firestore = FirebaseFirestore.instance;

      try {
        // 1. Update name in the item document
        await firestore
            .collection('categories')
            .doc(categoryId)
            .collection('items')
            .doc(itemId)
            .update({
          'name': newName,
          'updatedBy': updatedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update all board components that refer to the old item name
        final boardsSnapshot = await firestore.collection('boards').get();

        for (final doc in boardsSnapshot.docs) {
          final boardData = doc.data();
          final List<dynamic> components = boardData['components'] ?? [];

          bool updated = false;

          for (int i = 0; i < components.length; i++) {
            final component = components[i];
            if (component['itemName'] == oldName &&
                component['categoryId'] == categoryId &&
                component['itemId'] == itemId) {
              components[i]['itemName'] = newName;
              updated = true;
            }
          }

          if (updated) {
            await firestore.collection('boards').doc(doc.id).update({
              'components': components,
            });
          }
        }

        print("Item name updated globally to $newName");
      } catch (e) {
        print("Error updating item name globally: $e");
      }
    }
    Future<void> addCategory(String name, String addedBy) async {
      try {
        final docRef = _firestore.collection('categories').doc(name);

        final doc = await docRef.get();
        if (doc.exists) return;

        await docRef.set({
          'name': name,
          'addedBy': addedBy,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error adding category: $e");
      }
    }
    Future<void> renameCategoryEverywhere({
      required String categoryId,
      required String newCategoryName,
      required String updatedBy,
    }) async {
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Update the category document name
      final categoryRef = firestore.collection('categories').doc(categoryId);
      final snapshot = await categoryRef.get();
      if (!snapshot.exists) throw Exception('Category not found');

      await categoryRef.update({
        'name': newCategoryName,
        'updatedBy': updatedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2️⃣ Update all items in this category's subcollection
      final itemsSnapshot = await categoryRef.collection('items').get();
      WriteBatch batch = firestore.batch();
      int opCount = 0;

      for (final item in itemsSnapshot.docs) {
        batch.update(item.reference, {
          'categoryName': newCategoryName,
        });

        opCount++;
        if (opCount == 450) {
          await batch.commit();
          batch = firestore.batch();
          opCount = 0;
        }
      }
      if (opCount > 0) await batch.commit();

      // 3️⃣ Update category name in boards
      final boardsSnapshot = await firestore
          .collection('boards')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      for (final doc in boardsSnapshot.docs) {
        await doc.reference.update({
          'categoryName': newCategoryName,
        });
      }

      // 4️⃣ Update category name in logs
      final logsSnapshot = await firestore
          .collection('logs')
          .where('categoryId', isEqualTo: categoryId)
          .get();
      for (final doc in logsSnapshot.docs) {
        await doc.reference.update({
          'categoryName': newCategoryName,
        });
      }
    }


    // Future<void> renameCategoryDoc(String oldCategoryId, String newCategoryName, String updatedBy) async {
    //   final firestore = FirebaseFirestore.instance;
    //   final oldDocRef = firestore.collection('categories').doc(oldCategoryId);
    //   final newDocRef = firestore.collection('categories').doc(newCategoryName);
    //
    //   // Fetch old doc
    //   final oldSnapshot = await oldDocRef.get();
    //   if (!oldSnapshot.exists) throw Exception('Old category does not exist');
    //
    //   final oldData = oldSnapshot.data()!;
    //   final newData = {
    //     ...oldData,
    //     'name': newCategoryName,
    //     'updatedBy': updatedBy,
    //     'updatedAt': FieldValue.serverTimestamp(),
    //   };
    //
    //   // Create new doc
    //   await newDocRef.set(newData);
    //
    //   // Copy items in batches (to avoid too many await calls)
    //   final oldItemsSnapshot = await oldDocRef.collection('items').get();
    //
    //   // Firestore batch write allows max 500 ops per batch
    //   WriteBatch batch = firestore.batch();
    //   int opCount = 0;
    //
    //   for (final item in oldItemsSnapshot.docs) {
    //     final newItemRef = newDocRef.collection('items').doc(item.id);
    //     batch.set(newItemRef, item.data());
    //     opCount++;
    //
    //     // If batch limit reached, commit and start new batch
    //     if (opCount == 450) {
    //       await batch.commit();
    //       batch = firestore.batch();
    //       opCount = 0;
    //     }
    //   }
    //
    //   // Commit remaining operations
    //   if (opCount > 0) {
    //     await batch.commit();
    //   }
    //
    //   // Delete the old category
    //   await oldDocRef.delete();
    // }

    Future<List<Map<String, dynamic>>> searchItems(String categoryName, String query) async {
      try {
        final snapshot = await _firestore
            .collection('categories')
            .doc(categoryName)
            .collection('items')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThan: query + 'z')
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      } catch (e) {
        print("Error searching items: $e");
        return [];
      }
    }
    Future<List<CategoryModel>> getCategories() async {
      try {
        final snapshot = await _firestore.collection('categories').get();
        return snapshot.docs
            .map((doc) => CategoryModel.fromDocument(doc))
            .toList();
      } catch (e) {
        print("Error fetching categories: $e");
        return [];
      }
    }
    Future<void> addItem(String itemName, String categoryId, String categoryName, int quantity) async {
      try {
        final user = FirebaseAuth.instance.currentUser;

        final addedBy = (user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!
            : (user?.email?.isNotEmpty ?? false)
            ? user!.email!
            : 'Unknown User';

        print("Adding item by: $addedBy");

        final categoryRef = _firestore.collection('categories').doc(categoryId);
        final itemsRef = categoryRef.collection('items');

        var existingItem = await itemsRef
            .where('name', isEqualTo: itemName)
            .get();

        if (existingItem.docs.isNotEmpty) {
          // Item exists: just increment quantity
          var itemId = existingItem.docs.first.id;
          await itemsRef.doc(itemId).update({
            'quantity': FieldValue.increment(quantity),
          });
        } else {
          await itemsRef.add({
            'name': itemName,
            'quantity': quantity,
            'addedBy': addedBy,
            'createdAt': FieldValue.serverTimestamp(),
            'categoryId': categoryId,
            'categoryName': categoryName,
          });
        }
      } catch (e) {
        print("Error adding item: $e");
      }
    }
    Future<void> deleteCategory(String categoryName, String deletedBy) async {
      try {
        final firestore = _firestore;
        final categoryRef = firestore.collection('categories').doc(categoryName);
        final snapshot = await categoryRef.get();

        if (!snapshot.exists) return;

        final categoryData = snapshot.data();
        final categoryNameStored = categoryData?['name'] ?? 'Unknown';

        // Log deleted category
        await firestore.collection('deleted_categories').add({
          'categoryName': categoryNameStored,
          'deletedBy': deletedBy,
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // Get all items
        final items = await categoryRef.collection('items').get();

        // Prepare batches
        List<WriteBatch> batches = [];
        WriteBatch currentBatch = firestore.batch();
        int opCount = 0;

        for (final item in items.docs) {
          // Add to deleted_items
          final deletedItemRef = firestore.collection('deleted_items').doc();
          currentBatch.set(deletedItemRef, {
            'itemId': item.id,
            'itemName': item['name'],
            'categoryName': categoryNameStored,
            'deletedBy': deletedBy,
            'deletedQuantity': item['quantity'],
            'deletedAt': FieldValue.serverTimestamp(),
          });

          // Delete item
          currentBatch.delete(item.reference);

          opCount += 2; // one for set, one for delete

          if (opCount >= 450) {
            batches.add(currentBatch);
            currentBatch = firestore.batch();
            opCount = 0;
          }
        }

        // Add last batch if not empty
        if (opCount > 0) {
          batches.add(currentBatch);
        }

        // Commit all batches
        for (final batch in batches) {
          await batch.commit();
        }

        // Delete the category doc after all items are handled
        await categoryRef.delete();
      } catch (e) {
        print("Error deleting category: $e");
      }
    }

    Future<List<Map<String, dynamic>>> globalItemSearch(String query) async {
      List<Map<String, dynamic>> results = [];

      try {
        final categorySnapshot = await _firestore.collection('categories').get();

        for (var categoryDoc in categorySnapshot.docs) {
          final categoryId = categoryDoc.id;

          final itemSnapshot = await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('items')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThan: query + 'z')
              .get();

          for (var itemDoc in itemSnapshot.docs) {
            final itemData = itemDoc.data();
            itemData['itemId'] = itemDoc.id;
            itemData['categoryId'] = categoryId;
            results.add(itemData);
          }
        }
      } catch (e) {
        print("Error in global item search: $e");
      }

      return results;
    }
    Future<int> getAvailableQuantity(String categoryName, String itemId) async {
      final snapshot = await _firestore
          .collection('categories')
          .doc(categoryName)
          .collection('items')
          .doc(itemId)
          .get();

      return snapshot.data()?['quantity'] ?? 0;
    }
    Future<void> updateBoardSelectionCount(String boardName, int newCount) async {
      await _firestore.collection('boards').doc(boardName).update({
        'selectionCount': newCount,
      });
    }
    Future<void> increaseItemQuantityFast({
      required String categoryName,
      required String itemId,
      required String itemName,
      required int addedQuantity,
      required String addedBy,
    }) async {
      try {
        final itemRef = _firestore
            .collection('categories')
            .doc(categoryName)
            .collection('items')
            .doc(itemId);

        // Single atomic increment
        await itemRef.update({
          'quantity': FieldValue.increment(addedQuantity),
        });

        // Log async (don't wait)
        _firestore.collection('added_component').add({
          'itemName': itemName,
          'addedQuantity': addedQuantity,
          'addedBy': addedBy,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error increasing quantity: $e");
      }
    }

    Future<void> decreaseItemQuantity({
      required String categoryName,
      required String itemId,
      required String itemName,
      required int deleteQuantity,
      required String deletedBy,
    }) async {
      try {
        final categoryRef = FirebaseFirestore.instance.collection('categories');
        final itemRef = categoryRef.doc(categoryName).collection('items').doc(itemId);

        print("Trying to access: categories/$categoryName/items/$itemId");

        DocumentSnapshot itemSnapshot = await itemRef.get();

        // Fallback if item by ID not found
        if (!itemSnapshot.exists) {
          print("Item not found by ID. Trying fallback by name: $itemName");

          final fallbackQuery = await categoryRef
              .doc(categoryName)
              .collection('items')
              .where('name', isEqualTo: itemName)
              .limit(1)
              .get();

          if (fallbackQuery.docs.isEmpty) {
            throw Exception("Item not found by ID or name: category=$categoryName, itemId=$itemId, itemName=$itemName");
          }

          itemSnapshot = fallbackQuery.docs.first;
        }

        final itemData = itemSnapshot.data() as Map<String, dynamic>;
        final currentQty = itemData['quantity'] ?? 0;
        final docRef = itemSnapshot.reference;

        if (deleteQuantity >= currentQty) {
          await docRef.delete();
          print("Item deleted: $itemName");
        } else {
          await docRef.update({'quantity': currentQty - deleteQuantity});
          print("Quantity updated: $itemName now has ${currentQty - deleteQuantity}");
        }

        final historyRef = FirebaseFirestore.instance.collection('deleted_items');
        await historyRef.add({
          'itemId': itemSnapshot.id,
          'itemName': itemName,
          'categoryName': categoryName,
          'deletedQuantity': deleteQuantity,
          'deletedBy': deletedBy,
          'deletedAt': FieldValue.serverTimestamp(),
        });

      } catch (e) {
        print("Error deleting item quantity: $e");
        rethrow;
      }
    }

    Future<CheckResult> checkAndDeductBoardItems({
      required String boardName,
      required int quantity,
    }) async {
      try {
        final firestore = FirebaseFirestore.instance;
        final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

        // 1. Get board components
        final boardQuery = await firestore
            .collection('boards')
            .where('boardName', isEqualTo: boardName)
            .limit(1)
            .get();

        if (boardQuery.docs.isEmpty) {
          return CheckResult(success: false, unavailableItems: ['Board not found']);
        }

        final boardDoc = boardQuery.docs.first;
        final components = boardDoc.data()['components'] as List<dynamic>;
        List<String> unavailableItems = [];

        // 2. Parallel fetch all items
        final itemFutures = components.map((comp) async {
          final categoryId = comp['categoryId'];
          final itemId = comp['itemId'];
          final itemQty = comp['quantity'];

          if (categoryId == null || itemId == null || itemQty == null) {
            return {'error': 'Missing data for component'};
          }

          final itemRef = firestore
              .collection('categories')
              .doc(categoryId)
              .collection('items')
              .doc(itemId);
          final snapshot = await itemRef.get();

          if (!snapshot.exists) {
            return {'error': 'Unknown item ($itemId)'};
          }

          final data = snapshot.data();
          final currentQty = data?['quantity'] ?? 0;
          final requiredQty = itemQty * quantity;

          if (currentQty is! int || currentQty < requiredQty) {
            final itemName = data?['name'] ?? 'Unnamed Item';
            return {
              'error': '$itemName (Need $requiredQty, Available $currentQty)'
            };
          }

          return {
            'ref': itemRef,
            'data': data,
            'itemQty': itemQty,
            'categoryId': categoryId,
            'itemId': itemId,
          };
        }).toList();

        final results = await Future.wait(itemFutures);

        final validItems = <Map<String, dynamic>>[];
        for (final result in results) {
          if (result.containsKey('error')) {
            unavailableItems.add(result['error']);
          } else {
            validItems.add(result);
          }
        }

        if (unavailableItems.isNotEmpty) {
          return CheckResult(success: false, unavailableItems: unavailableItems);
        }

        // 3. Prepare and commit batch updates
        final batch = firestore.batch();
        final deletedItems = <Map<String, dynamic>>[];

        for (var item in validItems) {
          final itemRef = item['ref'] as DocumentReference;
          final data = item['data'] as Map<String, dynamic>;
          final itemQty = item['itemQty'] as int;
          final categoryId = item['categoryId'] as String;
          final itemId = item['itemId'] as String;

          final currentQty = (data['quantity'] ?? 0) as int;
          final newQty = currentQty - (itemQty * quantity);

          batch.update(itemRef, {'quantity': newQty});

          deletedItems.add({
            'itemId': itemId,
            'itemName': data['name'] ?? 'Unknown',
            'categoryId': categoryId,
            'deletedQuantity': itemQty * quantity,
          });
        }

        await batch.commit();

        // 4. Fetch category names in parallel
        final categoryIds = deletedItems.map((e) => e['categoryId'] as String).toSet();
        final categoryFutures = categoryIds.map((id) async {
          final snap = await firestore.collection('categories').doc(id).get();
          return {id: snap.data()?['name'] ?? 'Unknown'};
        }).toList();

        final categoryNameMaps = await Future.wait(categoryFutures);
        final categoryNames = categoryNameMaps.fold<Map<String, String>>(
          {},
              (acc, map) => acc..addAll(map.cast<String, String>()),
        );


        // 5. Add logs to 'deleted_items' in parallel (fire-and-forget)
        for (var item in deletedItems) {
          firestore.collection('deleted_items').add({
            'itemId': item['itemId'],
            'itemName': item['itemName'],
            'categoryName': categoryNames[item['categoryId']] ?? 'Unknown',
            'deletedQuantity': item['deletedQuantity'],
            'deletedBy': userEmail,
            'deletedAt': FieldValue.serverTimestamp(),
          });
        }

        return CheckResult(success: true, unavailableItems: []);
      } catch (e) {
        debugPrint("Error: $e");
        return CheckResult(success: false, unavailableItems: ['Unexpected error occurred']);
      }
    }
    Future<Map<String, dynamic>?> getItemById(String itemId) async {
      try {
        final categorySnapshot = await _firestore.collection('categories').get();

        for (var categoryDoc in categorySnapshot.docs) {
          final itemsSnapshot = await categoryDoc.reference
              .collection('items')
              .where(FieldPath.documentId, isEqualTo: itemId)
              .get();

          if (itemsSnapshot.docs.isNotEmpty) {
            final itemDoc = itemsSnapshot.docs.first;
            final data = itemDoc.data();
            data['itemId'] = itemDoc.id;
            data['categoryId'] = categoryDoc.id;
            data['categoryName'] = categoryDoc['name'];
            return data;
          }
        }
        return null;
      } catch (e) {
        print("Error finding item by ID: $e");
        return null;
      }
    }

  }

  class CheckResult {
    final bool success;
    final List<String> unavailableItems;

    CheckResult({required this.success, required this.unavailableItems});
  }


