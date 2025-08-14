abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final String firstName;
  final String lastName;
  final bool isAdmin;

  LoginSuccess(this.firstName, this.lastName, this.isAdmin);
}

class LoginFailure extends LoginState {
  final String error;

  LoginFailure(this.error);
}
