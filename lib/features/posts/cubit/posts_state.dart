part of 'posts_cubit.dart';

@immutable
sealed class PostsState {}

final class PostsInitial extends PostsState {}

final class PostsLoading extends PostsState {}

final class PostsSuccess extends PostsState {}

final class PostsError extends PostsState {
  final String message;

  PostsError({required this.message});
}

final class ImagePicked extends PostsState {}

final class PublishLoading extends PostsState {}

final class PublishSuccess extends PostsState {}

final class PublishError extends PostsState {
  final String message;

  PublishError({required this.message});
}

final class ChangedSelection extends PostsState {}
