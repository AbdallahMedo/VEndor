import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import '../../../../core/utils/first_time_dialog.dart';
import '../../../completed_boards/completed_boards.dart';
import '../../../report/report_service.dart';
import '../../../vendor_items/category_services/category_model.dart';
import '../../../water_mark/water_mark_view.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/action_buttons.dart';
import '../widgets/category_grid.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/home_drawer.dart';
import '../widgets/search_item_page.dart';

class HomeView extends StatefulWidget {
  final String firstName;
  final String lastName;
  final bool isAdmin;

  const HomeView({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.isAdmin,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FirebaseServiceForItems firebase = FirebaseServiceForItems();
  bool _isSearchActive = false;
  String _searchQuery = "";
  bool _isFabMenuOpen = false;


  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadCategories());
    _showWelcomeIfFirstTime();
  }
  void _showWelcomeIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('first_time_dialog_shown') ?? false;

    if (!alreadyShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => FirstTimeDialog(
            firstName: widget.firstName,
            lastName: widget.lastName,
            isAdmin: widget.isAdmin,
          ),
        );
      });
      await prefs.setBool('first_time_dialog_shown', true);
    }
  }
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Category"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Category Name"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<HomeBloc>().add(AddCategory(
                      nameController.text,
                      "${widget.firstName} ${widget.lastName}",
                    ));
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
  void _showAddItemDialog() async {
    final itemNameController = TextEditingController();
    final limitController = TextEditingController(text: '1'); // default limit 1

    List<CategoryModel> categories = await firebase.getCategories();
    CategoryModel? selectedCategory;

    // Fetch current limits
    final limitsDocRef = FirebaseFirestore.instance
        .collection('shortageLimits')
        .doc('itemLimits');
    final limitsSnapshot = await limitsDocRef.get();
    final Map<String, int> customLimits = {};
    if (limitsSnapshot.exists) {
      final data = limitsSnapshot.data()!;
      data.forEach((key, value) {
        customLimits[key] =
            value is int ? value : int.tryParse(value.toString()) ?? 1;
      });
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemNameController,
                decoration: const InputDecoration(labelText: "Item Name"),
                onChanged: (val) {
                  // Update limit input with current limit for the entered name, or 1 if none
                  final limit = customLimits[val.trim()] ?? 1;
                  setState(() {
                    limitController.text = limit.toString();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownSearch<CategoryModel>(
                items: categories,
                itemAsString: (cat) => cat.name,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Search Category"),
                  ),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Select Category",
                  ),
                ),
                selectedItem: selectedCategory,
                onChanged: (cat) {
                  setState(() {
                    selectedCategory = cat;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitController,
                decoration: const InputDecoration(labelText: "Limit"),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // This allows only digits
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final name = itemNameController.text.trim();
                final limit = int.tryParse(limitController.text.trim()) ?? 1;
                if (name.isNotEmpty && selectedCategory != null) {
                  // Save/update limit for this item name
                  customLimits[name] = limit;
                  await limitsDocRef.set(customLimits);

                  // Add the item (assuming your addItem supports these args)
                  await firebase.addItem(
                    name,
                    selectedCategory!.id,
                    selectedCategory!.name,
                    0,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("Please enter item name and select category."),
                    ),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }
  void _showDeleteCategoryDialog() async {
    List<CategoryModel> categories = await firebase.getCategories();
    CategoryModel? selectedCategory;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Delete Category"),
          content: isLoading
              ? const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownSearch<CategoryModel>(
                items: categories,
                itemAsString: (cat) => cat.name,
                selectedItem: selectedCategory,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: "Search Category",
                    ),
                  ),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Select Category to Delete",
                  ),
                ),
                onChanged: (cat) {
                  setState(() {
                    selectedCategory = cat;
                  });
                },
              ),
            ],
          ),
          actions: isLoading
              ? []
              : [
            TextButton(
              onPressed: () async {
                if (selectedCategory != null) {
                  try {
                    setState(() => isLoading = true);

                    await firebase.deleteCategory(
                      selectedCategory!.id,
                      "${widget.firstName} ${widget.lastName}",
                    );

                    context.read<HomeBloc>().add(LoadCategories());
                    Navigator.pop(context);
                  } catch (e) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error deleting category: $e")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please select a category to delete.")),
                  );
                }
              },
              child: const Text("Delete"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }
  void _showEditCategoryDialog() async {
    List<CategoryModel> categories = await firebase.getCategories();
    CategoryModel? selectedCategory;
    final newNameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Category"),
          content: isLoading
              ? const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownSearch<CategoryModel>(
                items: categories,
                itemAsString: (cat) => cat.name,
                popupProps: const PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Search Category"),
                  ),
                ),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: "Select Category to Edit",
                  ),
                ),
                selectedItem: selectedCategory,
                onChanged: (cat) {
                  setState(() {
                    selectedCategory = cat;
                    if (cat != null) {
                      newNameController.text = cat.name;
                    } else {
                      newNameController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newNameController,
                decoration: const InputDecoration(labelText: "New Category Name"),
              ),
            ],
          ),
          actions: isLoading
              ? []
              : [
            TextButton(
              onPressed: () async {
                final newName = newNameController.text.trim();
                if (selectedCategory != null && newName.isNotEmpty) {
                  try {
                    setState(() => isLoading = true);

                    // 🔹 Call the updated rename method
                    await firebase.renameCategoryEverywhere(
                      categoryId: selectedCategory!.id,
                      newCategoryName: newName,
                      updatedBy: "${widget.firstName} ${widget.lastName}",
                    );

                    // Refresh UI
                    context.read<HomeBloc>().add(LoadCategories());
                    Navigator.pop(context); // Close dialog
                  } catch (e) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error renaming category: $e")),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Select category and enter new name.")),
                  );
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
  void _showSheetSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Sheets to Export',
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
              const SizedBox(height: 16),

              // Sheet selection list
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildSheetTile(
                      context,
                      icon: Icons.category,
                      title: 'Categories',
                      subtitle: 'Items organized by category',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadCategorySheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.delete_outline,
                      title: 'Deleted Items',
                      subtitle: 'History of removed inventory items',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadDeletedItemsSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.delete_forever,
                      title: 'Deleted Categories',
                      subtitle: 'Removed product categories',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadDeletedCategoriesSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.warning_amber,
                      title: 'Defected Items',
                      subtitle: 'Damaged or faulty inventory',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadSynthesizeSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.developer_board,
                      title: 'Boards',
                      subtitle: 'Circuit board inventory',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadBoardsSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.local_shipping,
                      title: 'Board Deliveries',
                      subtitle: 'Received board shipments',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadBoardReceivesSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.inventory,
                      title: 'On-Shelf Inventory',
                      subtitle: 'Current stock availability',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadOnShelfInventorySheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.add_circle_outline,
                      title: 'Added Components',
                      subtitle: 'New component additions',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadAddedComponentsSheet(context);
                      }),
                    ),
                    _buildSheetTile(
                      context,
                      icon: Icons.add_circle_outline,
                      title: 'Extensions logs',
                      subtitle: 'extensions logs',
                      onTap: () => _downloadWithLoading(context, () {
                        return ExcelExportService()
                            .downloadExtensionsLogsSheet(context);
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  void _showEditItemNameDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String searchQuery = '';
        String? selectedItemId;
        String? selectedCategoryId;
        String? selectedOldName;
        String newName = '';
        bool isLoading = true;
        List<Map<String, dynamic>> allItems = [];
        List<Map<String, dynamic>> filteredItems = [];

        return StatefulBuilder(
          builder: (context, setState) {
            // Load items initially
            if (isLoading) {
              FirebaseServiceForItems().globalItemSearch('').then((items) {
                setState(() {
                  allItems = items;
                  filteredItems = items;
                  isLoading = false;
                });
              });
            }

            return AlertDialog(
              title: const Text('Edit Item Name'),
              content: SizedBox(
                width: 400,
                height: 450,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                  children: [
                    TextField(
                      decoration:
                      const InputDecoration(labelText: 'Search item'),
                      onChanged: (value) {
                        searchQuery = value;
                        setState(() {
                          filteredItems = allItems
                              .where((item) => item['name']
                              .toString()
                              .toLowerCase()
                              .contains(searchQuery.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected =
                              selectedItemId == item['itemId'];

                          return ListTile(
                            title: Text(item['name']),
                            subtitle:
                            Text('Category: ${item['categoryId']}'),
                            tileColor: isSelected
                                ? Colors.green.shade100
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                color: Colors.green)
                                : null,
                            onTap: () {
                              setState(() {
                                selectedItemId = item['itemId'];
                                selectedCategoryId = item['categoryId'];
                                selectedOldName = item['name'];
                                newName = item['name'];
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedItemId != null)
                      TextField(
                        decoration:
                        const InputDecoration(labelText: 'New Name'),
                        onChanged: (value) => newName = value,
                        controller:
                        TextEditingController(text: newName),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (selectedItemId != null &&
                        selectedCategoryId != null &&
                        selectedOldName != null &&
                        newName.trim().isNotEmpty &&
                        newName.trim() != selectedOldName) {
                      final user =
                          FirebaseAuth.instance.currentUser;
                      final updatedBy =
                          user?.email ?? 'Unknown';

                      await FirebaseServiceForItems()
                          .editItemNameGlobally(
                        categoryId: selectedCategoryId!,
                        itemId: selectedItemId!,
                        oldName: selectedOldName!,
                        newName: newName.trim(),
                        updatedBy: updatedBy,
                      );
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildSheetTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.download, size: 24),
            ],
          ),
        ),
      ),
    );}

  Future<void> _downloadWithLoading(
    BuildContext context,
    Future Function() downloadFunction,
  ) async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Preparing Export...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await downloadFunction();

      // Close loading dialog on success
      if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export completed successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog on error
      if (Navigator.of(dialogContext, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext, rootNavigator: true).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        isSearchActive: _isSearchActive,
        firstName: widget.firstName,
        lastName: widget.lastName,
        refresh: () async {
          context.read<HomeBloc>().add(LoadCategories());
        },
        // onLogout: () => _logout(context),
        onSearchChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
        onSearchToggle: () {
          setState(() {
            if (_isSearchActive) {
              _searchQuery = "";
            }
            _isSearchActive = !_isSearchActive;
          });
        },
      ),
      drawer: AppDrawer(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // First secondary FAB (topmost)
          if (_isFabMenuOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Custom Sheet Download',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    heroTag: 'customDownload',
                    onPressed: () {
                      setState(() => _isFabMenuOpen = false);
                      _showSheetSelectionDialog(context);
                    },
                    child: const Icon(Icons.download_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

          // Second secondary FAB
          if (_isFabMenuOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Download Full Report',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    heroTag: 'fullDownload',
                    onPressed: () async {
                      setState(() => _isFabMenuOpen = false);
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                      );
                      await ExcelExportService().exportFullInventoryReport(context);
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    child: const Icon(Icons.save_alt, color: Colors.indigoAccent),
                  ),
                ],
              ),
            ),

          FloatingActionButton(
            heroTag: 'mainFab',
            onPressed: () => setState(() => _isFabMenuOpen = !_isFabMenuOpen),
            child: Icon(_isFabMenuOpen ? Icons.close : Icons.add),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: WatermarkPainter(
              text: "${widget.firstName} ${widget.lastName}",
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                /// Show Search Button to both admin and user
                if (!widget.isAdmin)
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SearchPage(
                                isAdmin: widget.isAdmin,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 60,
                          width: 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.indigoAccent,
                                Colors.deepPurpleAccent
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(2, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.search, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Search Items",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                /// Only show admin-specific buttons if admin
                if (widget.isAdmin)
                  if (widget.isAdmin)
                    ActionButtons(
                      isAdmin: widget.isAdmin,
                      onAddCategory: _showAddCategoryDialog,
                      onAddItem: _showAddItemDialog,
                      onDeleteCategory: _showDeleteCategoryDialog,
                      onCompletedBoards: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CompletedBoardView()));
                      },
                      onEditCategory: _showEditCategoryDialog,
                      onSearchItems: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => SearchPage(isAdmin: widget.isAdmin),
                        ));
                      },
                      onEditItemName: _showEditItemNameDialog, // ✅ NEW
                    ),


                const SizedBox(height: 10),

                /// Main content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadCategories());
                    },
                    child: BlocBuilder<HomeBloc, HomeState>(
                      builder: (context, state) {
                        if (state is HomeLoading) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (state is HomeError) {
                          return Center(
                              child: Text("Error: ${state.message}",
                                  style: const TextStyle(color: Colors.white)));
                        } else if (state is HomeLoaded) {
                          final filteredCategories = state.categories;
                          if (filteredCategories.isEmpty) {
                            return const Center(
                                child: Text("No categories available",
                                    style: TextStyle(color: Colors.grey)));
                          }
                          return CategoryGrid(
                            categories: filteredCategories,
                            searchQuery: _searchQuery,
                            isAdmin: widget.isAdmin,
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]

      ),
    );
  }
}
