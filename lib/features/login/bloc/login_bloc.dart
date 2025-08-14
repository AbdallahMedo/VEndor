import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/firebase_services.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final FirebaseService firebaseService;

  LoginBloc(this.firebaseService) : super(LoginInitial()) {
    on<LoginButtonPressed>(_onLoginPressed);
  }

  Future<void> _onLoginPressed(LoginButtonPressed event, Emitter<LoginState> emit) async {
    emit(LoginLoading());
    final email = event.email;
    final password = event.password;

    if (!_isValidEmail(email)) {
      emit(LoginFailure("Please enter a valid email."));
      return;
    }

    final result = await firebaseService.signIn(email, password);

    if (result == null) {
      final prefs = await SharedPreferences.getInstance();
      final userData = await firebaseService.getUserInfo(email);

      if (userData != null) {
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        final isAdmin = userData['isAdmin'] ?? false;

        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
        await prefs.setBool('isAdmin', isAdmin);
        await prefs.setBool('stayConnected', event.rememberMe);
        await prefs.setBool('rememberMe', event.rememberMe);

        if (event.rememberMe) {
          await prefs.setString('savedEmail', email);
          await prefs.setString('savedPassword', password);
        } else {
          await prefs.remove('savedEmail');
          await prefs.remove('savedPassword');
        }

        emit(LoginSuccess(firstName, lastName, isAdmin));
      } else {
        emit(LoginFailure("Failed to retrieve user info."));
      }
    } else {
      emit(LoginFailure(result));
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }
}
