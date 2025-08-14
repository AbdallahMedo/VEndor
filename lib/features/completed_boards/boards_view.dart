import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import 'board_items_view.dart';

class BoardsView extends StatefulWidget {
  final String deletedBy;

  BoardsView({required this.deletedBy});

  @override
  _BoardsViewState createState() => _BoardsViewState();
}

class _BoardsViewState extends State<BoardsView> {
  final FirebaseServiceForItems firebaseService = FirebaseServiceForItems();
  final TextEditingController _searchController = TextEditingController();
  List<String> boardNames = [];
  List<String> filteredBoardNames = [];
  Set<String> selectedBoards = {};
  Map<String, int> selectedBoardsCount = {};
  String searchQuery = '';
  bool isSearching = false;
  bool isloading = true;
  bool isAdmin = false;
  bool isLoading = false;
  bool isSelectionMode = false;
  Set<String> selectedBoardsForDeletion = {};

  Future<void> _fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        final data = doc.data();

        if (data != null) {
          setState(() {
            isAdmin = data['isAdmin'] == true;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  void _showSettingsSheet() {
    final Map<String, TextEditingController> limitControllers = {
      for (var board in boardNames) board: TextEditingController()
    };

    final Map<String, Future<int?>> limitFutures = {
      for (var board in boardNames) board: _getBoardLimit(board)
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isSaving = false;
        final TextEditingController searchController = TextEditingController();
        List<String> filteredBoardNames = List.from(boardNames);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            for (var board in boardNames) {
              limitFutures[board]!.then((limit) {
                if (limit != null && limitControllers[board]!.text.isEmpty) {
                  limitControllers[board]!.text = limit.toString();
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set Board Limits',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setSheetState(() {
                        filteredBoardNames = boardNames
                            .where((board) => board
                            .toLowerCase()
                            .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search boards...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 400,
                    child: ListView.separated(
                      itemCount: filteredBoardNames.length,
                      separatorBuilder: (_, __) => Divider(),
                      itemBuilder: (context, index) {
                        final boardName = filteredBoardNames[index];
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    boardName,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: limitControllers[boardName],
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Limit',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                        setSheetState(() => isSaving = true);
                        bool hasError = false;

                        final saveOperations = <Future>[];

                        for (var board in boardNames) {
                          final limitText = limitControllers[board]?.text;
                          if (limitText != null &&
                              limitText.isNotEmpty) {
                            final limit = int.tryParse(limitText);
                            if (limit != null) {
                              saveOperations.add(FirebaseFirestore
                                  .instance
                                  .collection('board_limits')
                                  .doc(board)
                                  .set({'limit': limit}).catchError((e) {
                                hasError = true;
                                debugPrint(
                                    'Error saving limit for $board: $e');
                              }));
                            }
                          }
                        }

                        await Future.wait(saveOperations);
                        setSheetState(() => isSaving = false);

                        if (!hasError) {
                          Navigator.pop(context);
                          loadBoards();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                Text('Some limits failed to save')),
                          );
                        }
                      },
                      icon: isSaving
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(Icons.save,color: Colors.white,),
                      label: Text(isSaving ? 'Saving...' : 'Save Limits',style: TextStyle(color: Colors.white),),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<int?> _getBoardLimit(String boardName) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('board_limits')
          .doc(boardName)
          .get();
      return doc.data()?['limit'] as int?;
    } catch (e) {
      print('Error getting limit: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    loadBoards();
    _searchController.addListener(_updateSearchQuery);
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearchQuery);
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchQuery() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      filteredBoardNames = boardNames
          .where((board) => board.toLowerCase().contains(searchQuery))
          .toList();
    });
  }

  Future<void> loadBoards() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('boards').get();
    final List<String> names = [];
    final Map<String, int> countMap = {};

    for (var doc in snapshot.docs) {
      final boardData = doc.data();
      final boardNameFromField = boardData['boardName'] ?? doc.id;

      names.add(boardNameFromField);
      countMap[boardNameFromField] = boardData['selectionCount'] ?? 0;
    }

    setState(() {
      boardNames = names;
      filteredBoardNames = names;
      selectedBoardsCount = countMap;
      selectedBoardsForDeletion.clear();
      isSelectionMode = false;
    });
  }
  void showAlertDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  void onBoardSelected(String boardName) async {
    final result = await firebaseService.checkAndDeductBoardItems(
      boardName: boardName,
      quantity: 1,
    );

    if (!result.success) {
      final message = result.unavailableItems.isNotEmpty
          ? result.unavailableItems.join('\n')
          : 'Not enough stock to add this board.';

      showAlertDialog('Insufficient Stock', message);
      return;
    }

    setState(() {
      selectedBoards.add(boardName);
      selectedBoardsCount[boardName] =
          (selectedBoardsCount[boardName] ?? 0) + 1;
    });

    await firebaseService.updateBoardSelectionCount(
      boardName,
      selectedBoardsCount[boardName]!,
    );
  }
  void _showBoardActionSheet() {
    String? selectedBoard;
    final TextEditingController countController = TextEditingController();
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool sheetLoading = false;
        List<String> filteredBoards = List.from(boardNames);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// 🔍 Search Box
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search boards',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (query) {
                      setSheetState(() {
                        filteredBoards = boardNames
                            .where((board) => board
                            .toLowerCase()
                            .contains(query.toLowerCase()))
                            .toList();
                        if (!filteredBoards.contains(selectedBoard)) {
                          selectedBoard = null;
                          countController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  /// 📋 List of Boards
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredBoards.length,
                      itemBuilder: (context, index) {
                        final board = filteredBoards[index];
                        final isSelected = selectedBoard == board;

                        return ListTile(
                          title: Text(board),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () {
                            setSheetState(() {
                              selectedBoard = board;
                              countController.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  /// ✅ Input & Button
                  if (selectedBoard != null) ...[
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Enter number to add',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: sheetLoading
                          ? null
                          : () async {
                        final parsedInput =
                        int.tryParse(countController.text);
                        if (parsedInput == null || parsedInput <= 0) {
                          showAlertDialog('Invalid Input',
                              'Please enter a valid positive number.');
                          return;
                        }

                        setSheetState(() => sheetLoading = true);

                        final stockResult = await firebaseService
                            .checkAndDeductBoardItems(
                          boardName: selectedBoard!,
                          quantity: parsedInput,
                        );

                        if (!stockResult.success) {
                          setSheetState(() => sheetLoading = false);
                          showAlertDialog(
                            'Insufficient Stock',
                            stockResult.unavailableItems.isNotEmpty
                                ? stockResult.unavailableItems.join('\n')
                                : 'Not enough stock to add this board.',
                          );
                          return;
                        }

                        _processManufacturingRequests(
                          selectedBoard!,
                          parsedInput,
                        );

                        setState(() {
                          selectedBoardsCount[selectedBoard!] =
                              (selectedBoardsCount[selectedBoard!] ?? 0) +
                                  parsedInput;
                        });

                        unawaited(firebaseService
                            .updateBoardSelectionCount(
                            selectedBoard!,
                            selectedBoardsCount[selectedBoard!]!));

                        Navigator.pop(context);
                      },
                      icon: sheetLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.add),
                      label: Text(sheetLoading ? 'Loading...' : 'Add'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _processManufacturingRequests(
      String boardName, int quantity) async {
    try {
      int remaining = quantity;
      final query = await FirebaseFirestore.instance
          .collection('manufacturing_requests')
          .where('boardName', isEqualTo: boardName)
          .orderBy('timestamp')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in query.docs) {
        final currentQty = doc['quantity'] as int? ?? 0;

        if (remaining >= currentQty) {
          batch.delete(doc.reference);
          remaining -= currentQty;
        } else {
          batch.update(doc.reference, {'quantity': currentQty - remaining});
          remaining = 0;
        }

        if (remaining <= 0) break;
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error processing manufacturing requests: $e');
      // You might want to add retry logic here
    }
  }
  void _showEditBoardNameDialog() {
    String? selectedBoard;
    final TextEditingController newNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Board Name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedBoard,
                    hint: Text('Select board'),
                    isExpanded: true,
                    items: boardNames.map((board) {
                      return DropdownMenuItem(
                        value: board,
                        child: Text(board),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedBoard = value;
                        newNameController.text = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newNameController,
                    decoration: InputDecoration(
                      labelText: 'New Board Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = newNameController.text.trim();

                    if (selectedBoard == null || newName.isEmpty) {
                      showAlertDialog('Invalid Input', 'Please select a board and enter a new name.');
                      return;
                    }

                    if (boardNames.contains(newName)) {
                      showAlertDialog('Name Taken', 'Another board already has this name.');
                      return;
                    }

                    Navigator.pop(context);
                    await _renameBoard(selectedBoard!, newName);
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _renameBoard(String oldName, String newName) async {
    try {
      final oldDocRef = FirebaseFirestore.instance.collection('boards').doc(oldName);
      final newDocRef = FirebaseFirestore.instance.collection('boards').doc(newName);

      final oldDoc = await oldDocRef.get();
      if (!oldDoc.exists) {
        showAlertDialog('Error', 'Board "$oldName" not found.');
        return;
      }

      final oldData = oldDoc.data()!;
      await newDocRef.set({...oldData, 'boardName': newName});
      await oldDocRef.delete();

      // Rename related 'board_limits' document if it exists
      final oldLimitRef = FirebaseFirestore.instance.collection('board_limits').doc(oldName);
      final oldLimitDoc = await oldLimitRef.get();
      if (oldLimitDoc.exists) {
        final limitData = oldLimitDoc.data()!;
        await FirebaseFirestore.instance.collection('board_limits').doc(newName).set(limitData);
        await oldLimitRef.delete();
      }

      showAlertDialog('Success', 'Board name updated successfully.');
      loadBoards(); // Refresh the board list
    } catch (e) {
      showAlertDialog('Error', 'Failed to rename board: $e');
    }
  }


  void _navigateToBoardItems(String boardName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoardItemsView(boardName: boardName),
      ),
    ).then((_) => loadBoards());
  }

  void _toggleBoardSelection(String boardName) {
    if(!isAdmin) return;
    setState(() {
      if (selectedBoardsForDeletion.contains(boardName)) {
        selectedBoardsForDeletion.remove(boardName);
      } else {
        selectedBoardsForDeletion.add(boardName);
      }

      // Exit selection mode if no boards are selected
      if (selectedBoardsForDeletion.isEmpty) {
        isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedBoards() async {
    if (selectedBoardsForDeletion.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete ${selectedBoardsForDeletion.length} board(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var boardName in selectedBoardsForDeletion) {
        final docRef = FirebaseFirestore.instance
            .collection('boards')
            .doc(boardName);
        batch.delete(docRef);

        // Also delete the corresponding limit if it exists
        final limitRef = FirebaseFirestore.instance
            .collection('board_limits')
            .doc(boardName);
        batch.delete(limitRef);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted ${selectedBoardsForDeletion.length} board(s)'),
          backgroundColor: Colors.green,
        ),
      );

      loadBoards(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting boards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSearching
            ? Text(isSelectionMode
            ? '${selectedBoardsForDeletion.length} selected'
            : 'Completed Boards')
            : TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search boards...',
            border: InputBorder.none,
          ),
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                setState(() {
                  isSelectionMode = false;
                  selectedBoardsForDeletion.clear();
                });
              },
            ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  _searchController.clear();
                  filteredBoardNames = boardNames;
                }
                isSearching = !isSearching;
              });
            },
          ),
          if (!isSelectionMode)
            IconButton(
              onPressed: loadBoards,
              icon: Icon(Icons.refresh),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: loadBoards,
            child: filteredBoardNames.isEmpty
                ? const Center(child: Text("There is nothing found"))
                : Column(
              children: [
                if (!isSelectionMode) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    width: 300,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey, width: 1),
                              ),
                            ),
                            const Text(
                              " Below limit",
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey, width: 1),
                              ),
                            ),
                            const Text(
                              " Above limit",
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredBoardNames.length,
                    gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 4 / 3,
                    ),
                    itemBuilder: (context, index) {
                      final boardName = filteredBoardNames[index];
                      final count = selectedBoardsCount[boardName] ?? 0;

                      return GestureDetector(
                        onLongPress: () {
                          if (isAdmin &&!isSelectionMode) {
                            setState(() {
                              isSelectionMode = true;
                              selectedBoardsForDeletion.add(boardName);
                            });
                          }
                        },
                        onSecondaryTap: () {
                          // Right click for Windows app
                          if (isAdmin && !isSelectionMode) {
                            setState(() {
                              isSelectionMode = true;
                              selectedBoardsForDeletion.add(boardName);
                            });
                          }
                        },
                        onTap: () {
                          if (isSelectionMode) {
                            if(isAdmin)
                            {
                              _toggleBoardSelection(boardName);

                            }
                          } else {
                            if (isAdmin) {
                              _navigateToBoardItems(boardName);
                            } else {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Access Denied'),
                                    content: const Text(
                                      'Sorry, only administrators can access this page.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isSelectionMode &&
                                    selectedBoardsForDeletion.contains(boardName) &&
                                    isAdmin // Only show selection color if admin
                                    ? Colors.blue[300]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedBoards.contains(boardName)
                                      ? Colors.blue
                                      : isSelectionMode &&
                                      selectedBoardsForDeletion.contains(boardName) &&
                                      isAdmin // Only show selection border if admin
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    boardName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            if (count > 0)
                              FutureBuilder<int?>(
                                future: _getBoardLimit(boardName),
                                builder: (context, snapshot) {
                                  final limit = snapshot.data;
                                  final isOverLimit =
                                      limit != null && count > limit;

                                  return Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: isOverLimit
                                          ? Colors.red
                                          : Colors.yellow,
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          color: isOverLimit
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (isSelectionMode && isAdmin)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Checkbox(
                                  value: selectedBoardsForDeletion
                                      .contains(boardName),
                                  onChanged: (value) {
                                    _toggleBoardSelection(boardName);
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (isSelectionMode && isAdmin)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton.extended(
                  onPressed: _deleteSelectedBoards,
                  icon: Icon(Icons.delete, color: Colors.white),
                  label: Text(
                    'Delete (${selectedBoardsForDeletion.length})',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  elevation: 4,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAdmin)
            FloatingActionButton(
              heroTag: 'settings_fab',
              onPressed: _showSettingsSheet,
              child: Icon(Icons.settings),
            ),
          SizedBox(height: 16),
          if (isAdmin)
            FloatingActionButton(
              heroTag: 'edit_board_fab',
              onPressed: _showEditBoardNameDialog,
              child: Icon(Icons.edit),
            ),
          SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _showBoardActionSheet,
            child: Icon(Icons.add),
          ),
        ],
      ),

    );
  }
}