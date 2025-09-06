import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../widgets/loading_ui.dart';
import '../../../widgets/try_again_ui.dart';
import '../cubit/posts_cubit.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class PostsListScreen extends StatelessWidget {
  const PostsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PostsCubit()..getPosts(),
      child: BlocConsumer<PostsCubit, PostsState>(
        listener: (context, state) {},
        builder: (context, state) {
          final cubit = context.read<PostsCubit>();

          if (state is PostsLoading) {
            return const LoadingUi();
          }

          if (state is PostsError) {
            return TryAgainUi(
              message: state.message,
              onRetry: () => cubit.getPosts(),
            );
          }

          return cubit.posts.isEmpty
              ? const Center(
                  child: Text(
                    "No posts available",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: cubit.posts.length,
                  itemBuilder: (context, index) {
                    final post = cubit.posts[index];
                    return PostCard(post: post);
                  },
                );
        },
      ),
    );
  }
}
