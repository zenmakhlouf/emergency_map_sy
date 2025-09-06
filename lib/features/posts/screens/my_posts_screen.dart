import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../widgets/loading_ui.dart';
import '../../../widgets/try_again_ui.dart';
import '../cubit/posts_cubit.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'publish_post_screen.dart';

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = {'auth': '1'};

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Posts"),
      ),
      body: BlocProvider(
        create: (context) => PostsCubit()..getPosts(query: query),
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
                onRetry: () => cubit.getPosts(query: query),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PublishPostScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("New Post"),
      ),
    );
  }
}
