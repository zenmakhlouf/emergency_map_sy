import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import 'chat_conversation_screen.dart';
import '../../../widgets/report_card.dart';
import '../../../widgets/user_profile_modal.dart';
import '../../../services/map_navigation_service.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
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

  /// Navigate back to dashboard and view report on map
  void _viewReportOnMap(ConversationSummary chat) {
    // Use the chat topic ID as the report ID
    final reportId = chat.topic.id;
    
    // Set the report ID to be shown on map using the navigation service
    MapNavigationService().setPendingReportId(reportId);
    
    // Navigate back to dashboard 
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Show confirmation message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing report #$reportId on map'),
        duration: const Duration(seconds: 2),
      ),
    );
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
                                            chatTitle: chat.getChatTitle(currentUserId),
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
                                backgroundColor: _getUserRoleColor(otherParticipant?.user.roles ?? []),
                                backgroundImage: otherParticipant?.user.profileImage?.publicPath != null
                                    ? NetworkImage(otherParticipant!.user.profileImage!.publicPath)
                                    : null,
                                child: otherParticipant?.user.profileImage == null
                                    ? Text(
                                        otherParticipant?.user.initials ?? '?',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              // Online indicator or role badge
                              if (otherParticipant?.user.roles.contains('ai-agent') == true)
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
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Status indicator
                            if (chat.topic.latestStatus != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(chat.topic.latestStatus!.statusColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  chat.topic.latestStatus!.status.toUpperCase(),
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
                            Text(
                              chat.lastMessageText ?? 'Tap to view conversation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (chat.topic.createdAt != null)
                              Text(
                                chat.topic.createdAt!,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          ],
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
                                  currentUserId: currentUserId,
                                  participants: chat.participants,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Report Card Button (if there's a report)
                      if (chat.topic.report != null && chat.topic.report!.hasEmergencyData)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showReportCard(
                                context,
                                report: chat.topic.report!,
                                status: chat.topic.latestStatus,
                                onViewOnMap: () {
                                  Navigator.of(context).pop();
                                  _viewReportOnMap(chat);
                                },
                              );
                            },
                            icon: const Icon(Icons.emergency, size: 16, color: Colors.red),
                            label: Text(
                              'View Emergency Report',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
