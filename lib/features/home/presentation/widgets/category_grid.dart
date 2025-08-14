import 'package:flutter/material.dart';
import '../../../vendor_items/category_services/category_model.dart';
import '../../../vendor_items/presentation/views/category_item_view.dart';

class CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final String searchQuery;
  final bool isAdmin;

  const CategoryGrid({
    Key? key,
    required this.categories,
    required this.searchQuery,
    required this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filteredCategories = searchQuery.isEmpty
        ? categories
        : categories.where((category) {
      return category.name
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredCategories.isEmpty) {
      return const Center(
        child: Text(
          "No categories available",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: filteredCategories.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 4 / 3,
        ),
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return _CategoryCard(
            categoryName: category.name,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryItemsView(
                    categoryId: category.id,
                    categoryName: category.name,
                    isAdmin: isAdmin,
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

class _CategoryCard extends StatefulWidget {
  final String categoryName;
  final VoidCallback onTap;

  const _CategoryCard({
    Key? key,
    required this.categoryName,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _isHovered = false;
  late final AnimationController _controller;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
    );

    _controller.addListener(() {
      setState(() {
        _scale = _controller.value;
      });
    });

    _controller.value = 1.0;
    super.initState();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.forward();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : _scale,
          duration: const Duration(milliseconds: 150),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.indigo.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.categoryName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black45,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
