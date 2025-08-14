abstract class LoginEvent {}

class LoginButtonPressed extends LoginEvent {
  final String email;
  final String password;
  final bool rememberMe;

  LoginButtonPressed(this.email, this.password, this.rememberMe);
}
