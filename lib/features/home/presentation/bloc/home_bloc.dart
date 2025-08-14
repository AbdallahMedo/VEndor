import 'package:bloc/bloc.dart';
import 'package:vendor_chem_tech/services/services_for_items.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FirebaseServiceForItems firebase;

  HomeBloc(this.firebase) : super(HomeInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<SearchCategories>(_onSearch);
    on<AddCategory>(_onAddCategory);
  }

  Future<void> _onLoadCategories(
      LoadCategories event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    try {
      final data = await firebase.getCategories();
      emit(HomeLoaded(data));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  void _onSearch(SearchCategories event, Emitter<HomeState> emit) {
    if (state is HomeLoaded) {
      final all = (state as HomeLoaded).categories;
      final filtered = all
          .where((cat) =>
          cat.name.toLowerCase().contains(event.query.toLowerCase()))
          .toList();
      emit(HomeLoaded(filtered));
    }
  }

  Future<void> _onAddCategory(
      AddCategory event, Emitter<HomeState> emit) async {
    await firebase.addCategory(event.name, event.addedBy);
    add(LoadCategories());
  }
}
