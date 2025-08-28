part of 'profile_cubit.dart';

@immutable
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserProfile userProfile;
  ProfileLoaded(this.userProfile);
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}
