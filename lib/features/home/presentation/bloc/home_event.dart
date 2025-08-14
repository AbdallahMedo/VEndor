abstract class HomeEvent {}

class LoadCategories extends HomeEvent {}

class SearchCategories extends HomeEvent {
  final String query;
  SearchCategories(this.query);
}

class AddCategory extends HomeEvent {
  final String name;
  final String addedBy;
  AddCategory(this.name, this.addedBy);
}
