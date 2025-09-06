import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import 'chat_conversation_screen.dart'; // Assuming this will be localized
import '../../../widgets/user_profile_modal.dart';
import '../../../services/report_details_service.dart';

// Note: This file is a localized version of ChatsListScreen.
// For a production app, use a dedicated localization library like `flutter_localizations`.

class ChatsListScreenAR extends StatefulWidget {
  const ChatsListScreenAR({super.key});

  @override
  State<ChatsListScreenAR> createState() => _ChatsListScreenARState();
}

class _ChatsListScreenARState extends State<ChatsListScreenAR> {
  final Duration _pollInterval = const Duration(seconds: 5);
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
      await context.read<ChatCubit>().loadChats();
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadChats();
    });
  }

  void _showEmergencyReport(BuildContext context, ConversationSummary chat) {
    final reportId = chat.topic.id;
    final success = ReportDetailsService.showReport(reportId);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل تفاصيل البلاغ. يرجى المحاولة مرة أخرى.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.watch<AuthCubit>();
    final currentUserId = authCubit.userId;

    // Root Directionality widget for full RTL support
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadChats,
              tooltip: 'تحديث',
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

            final filteredChats = _cachedChats.where((chat) {
              final status = chat.topic.latestStatus?.status.toLowerCase();
              return status != 'deleted' && status != 'closed';
            }).toList();

            if (filteredChats.isEmpty) {
              if (state is ChatLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Text(
                  'لا توجد محادثات حتى الآن.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView.builder(
                itemCount: filteredChats.length,
                itemBuilder: (context, index) {
                  final chat = filteredChats[index];
                  final otherParticipant =
                      chat.getOtherParticipant(currentUserId ?? 0);

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              if (otherParticipant != null) {
                                showUserProfile(
                                  context,
                                  user: otherParticipant.user,
                                  onMessage: () {
                                    Navigator.of(context).pop();
                                    if (currentUserId != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: context.read<ChatCubit>(),
                                            child: ChatConversationScreen(
                                              chatId: chat.id,
                                              chatTitle: chat
                                                  .getChatTitle(currentUserId),
                                              currentUserId: currentUserId,
                                              participants: chat.participants,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              }
                            },
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getUserRoleColor(
                                      otherParticipant?.user.roles ?? []),
                                  backgroundImage: otherParticipant
                                              ?.user.profileImage?.publicPath !=
                                          null
                                      ? NetworkImage(otherParticipant!
                                          .user.profileImage!.publicPath)
                                      : null,
                                  child: otherParticipant?.user.profileImage ==
                                          null
                                      ? Text(
                                          otherParticipant?.user.initials ??
                                              '؟',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                if (otherParticipant?.user.roles
                                        .contains('ai-agent') ==
                                    true)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.smart_toy,
                                        color: Colors.orange,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chat.getChatTitle(currentUserId ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (chat.topic.latestStatus != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                        chat.topic.latestStatus!.statusColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    // This text comes from the backend, assuming it might not be translated here.
                                    chat.topic.latestStatus!.status
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (chat.topic.report?.description.isNotEmpty ==
                                  true)
                                Text(
                                  chat.topic.report!.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                Text(
                                  chat.lastMessageText ?? 'انقر لعرض المحادثة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 4),
                              if (chat.topic.report != null ||
                                  chat.topic.latestStatus != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.emergency,
                                      size: 14,
                                      color: Colors.red.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'بلاغ طارئ',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (chat.topic.createdAt != null) ...[
                                      Text(
                                        ' • ',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        chat.topic.createdAt!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              else if (chat.topic.createdAt != null)
                                Text(
                                  chat.topic.createdAt!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          // RTL-friendly icon
                          trailing: const Icon(Icons.chevron_left),
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
                                    currentUserId: currentUserId,
                                    participants: chat.participants,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (chat.topic.report != null ||
                            chat.topic.latestStatus != null ||
                            chat.participants
                                .any((p) => p.user.roles.contains('ai-agent')))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showEmergencyReport(context, chat),
                              icon: const Icon(Icons.emergency,
                                  size: 16, color: Colors.red),
                              label: Text(
                                'عرض بلاغ الطوارئ',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getUserRoleColor(List<String> roles) {
    if (roles.contains('coordinator')) return Colors.purple;
    if (roles.contains('responder')) return Colors.blue;
    if (roles.contains('ai-agent')) return Colors.orange;
    if (roles.contains('citizen')) return Colors.green;
    return Colors.grey;
  }

  Color _getStatusColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
