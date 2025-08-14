import '../../../vendor_items/category_services/category_model.dart';

abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<CategoryModel> categories;
  HomeLoaded(this.categories);
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
