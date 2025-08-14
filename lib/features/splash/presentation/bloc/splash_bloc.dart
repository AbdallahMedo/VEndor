import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_event.dart';
import 'splash_state.dart';
import '../../../../services/firebase_services.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final FirebaseService firebaseService;

  SplashBloc(this.firebaseService) : super(SplashInitial()) {
    on<CheckAuthentication>(_onCheckAuthentication);
  }

  Future<void> _onCheckAuthentication(
      CheckAuthentication event,
      Emitter<SplashState> emit,
      ) async {
    emit(SplashLoading());

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        final userData = await firebaseService.getUserInfo(user.email!);

        if (userData != null) {
          emit(SplashAuthenticated(
            firstName: userData['firstName'] ?? '',
            lastName: userData['lastName'] ?? '',
            isAdmin: userData['isAdmin'] ?? false,
          ));
          return;
        }
      }

      emit(SplashUnauthenticated());
    } catch (e) {
      emit(SplashError("An error occurred while checking authentication."));
    }
  }
}
