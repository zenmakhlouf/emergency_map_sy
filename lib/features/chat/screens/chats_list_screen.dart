import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import 'chat_conversation_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final Duration _pollInterval = const Duration(seconds: 20);
  Timer? _poller;
  List<ConversationSummary> _cachedChats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final auth = context.read<AuthCubit>();
    if (auth.isAuthenticated && mounted) {
      await context.read<ChatCubit>().loadChats(bearer: auth.token!);
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final currentUserId = authCubit.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) {
          if (state is ChatError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is ChatListLoaded) {
            _cachedChats = state.chats;
          }

          if (_cachedChats.isEmpty) {
            if (state is ChatLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: Text(
                'No conversations yet.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadChats,
            child: ListView.builder(
              itemCount: _cachedChats.length,
              itemBuilder: (context, index) {
                final chat = _cachedChats[index];
                final otherParticipant =
                    chat.getOtherParticipant(currentUserId ?? 0);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(
                        otherParticipant?.user.initials ?? '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ),
                    title: Text(
                      chat.getChatTitle(currentUserId ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      chat.lastMessageText ?? 'Tap to view conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (currentUserId == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<ChatCubit>(),
                            child: ChatConversationScreen(
                              chatId: chat.id,
                              chatTitle: chat.getChatTitle(currentUserId),
                              bearerToken: authCubit.token!,
                              currentUserId: currentUserId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
