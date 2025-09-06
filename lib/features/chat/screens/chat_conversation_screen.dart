import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

// استيرادات محلية من هيكل مشروعك
import '../cubit/chat_cubit.dart';
import '../models/chat_models.dart';
import '../../../widgets/user_profile_modal.dart';
import '../../../services/report_details_service.dart';

// مولد معرفات فريد للرسائل المعلقة
const uuid = Uuid();

/// يمثل حالة إرسال الرسالة.
enum MessageStatus { pending, sent, failed }

/// نموذج رسالة محلي يتضمن حالة الإرسال لواجهة مستخدم متفائلة.
class PendingMessage {
  final ChatMessageEntity message;
  final MessageStatus status;

  PendingMessage({required this.message, this.status = MessageStatus.pending});

  PendingMessage copyWith({MessageStatus? status}) {
    return PendingMessage(
      message: message,
      status: status ?? this.status,
    );
  }
}

/// شاشة محادثة فورية على مستوى احترافي لاتصالات الطوارئ الحرجة.
/// تتميز بتجديد كامل لواجهة المستخدم وتجربة المستخدم، وتصميم مخصص للمشاركين حسب أدوارهم،
/// وإرسال متفائل للرسائل، وآليات موثوقية محسنة.
class ChatConversationScreen extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final int currentUserId;
  final List<ChatParticipant> participants;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.currentUserId,
    this.participants = const [],
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // --- الحالة والمتحكمات ---
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _sendButtonAnimationController;

  // --- الشبكة والاستقصاء ---
  Timer? _messagePoller;
  List<ChatMessageEntity> _confirmedMessages = [];
  Map<int, PendingMessage> _pendingMessages = {};
  List<ChatParticipant> _filteredParticipants = [];

  // --- حالة واجهة المستخدم وتجربة المستخدم ---
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _hasText = false;
  String? _networkError;

  // --- حالة تحويل الكلام إلى نص (STT) ---
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _pathToAudioFile;

  // --- الإعدادات ---
  static const Duration _pollInterval = Duration(seconds: 5);
  static const Duration _networkTimeout = Duration(seconds: 15);
  static const Duration _locationTimeout = Duration(seconds: 7);
  static const String _sttApiUrl =
      "https://help-map.saadalabyad.com/api/v1/ai/test-speech-to-text";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // تصفية المشاركين "الوهميين" من الواجهة الخلفية فورًا.
    _filteredParticipants = widget.participants
        .where((p) => p.user.name.isNotEmpty && p.user.name != 'Unknown User')
        .toList();

    _initializeAnimations();
    _setupTextFieldListener();
    _initializeChat();
    _initializeRecorder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _loadMessages(showError: false);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  // ============================================================================
  // التهيئة والإعداد
  // ============================================================================

  void _initializeAnimations() {
    _sendButtonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  void _setupTextFieldListener() {
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() => _hasText = hasText);
        if (hasText) {
          _sendButtonAnimationController.forward();
        } else {
          _sendButtonAnimationController.reverse();
        }
      }
    });
  }

  Future<void> _initializeChat() async {
    await _loadMessages(showError: false);
    if (mounted) setState(() => _isInitializing = false);
    _startPolling();
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();

      final tempDir = await getTemporaryDirectory();

      // استخدام حاوية يدعمها iOS بالفعل
      const ext = 'wav';
      _pathToAudioFile = p.join(tempDir.path, 'emergency_record.$ext');

      await _recorder
          .setSubscriptionDuration(const Duration(milliseconds: 500));
      setState(() => _isRecorderReady = true);
    } catch (e, st) {
      debugPrint("فشل تهيئة المسجل: $e\n$st");
      _showErrorMessage("الوصول إلى الميكروفون مطلوب للرسائل الصوتية.");
    }
  }

  // ============================================================================
  // معالجة بيانات الرسائل (الاستقصاء والحالة)
  // ============================================================================

  Future<void> _loadMessages({bool showError = true}) async {
    if (!mounted) return;
    try {
      await context
          .read<ChatCubit>()
          .loadMessages(chatId: widget.chatId)
          .timeout(_networkTimeout);
      if (mounted) {
        setState(() {
          _networkError = null;
        });
      }
    } catch (e) {
      debugPrint("فشل تحميل الرسائل: $e");
      if (mounted && showError) {
        setState(() => _networkError = "الاتصال غير مستقر");
      }
    }
  }

  void _handleChatStateChange(BuildContext context, ChatState state) {
    if (!mounted) return;

    if (state is ChatMessagesLoaded && state.chatId == widget.chatId) {
      final newMessages = state.messages;
      final updatedPendingMessages =
          Map<int, PendingMessage>.from(_pendingMessages);

      updatedPendingMessages.removeWhere((tempId, pending) {
        final pendingText = pending.message.text.trim();
        final pendingTime = DateTime.tryParse(pending.message.createdAt ?? '');

        final isConfirmed = newMessages.any((confirmed) {
          // يجب أن تكون من المستخدم الحالي
          if (confirmed.sender?.user.id != widget.currentUserId) return false;

          final confirmedText = confirmed.text.trim();
          final confirmedTime = DateTime.tryParse(confirmed.createdAt ?? '');

          // المطابقة الأساسية: تطابق النص الدقيق
          if (confirmedText == pendingText) {
            // إذا كانت لدينا طوابع زمنية صالحة، تأكد من أنها قريبة بشكل معقول (دقيقتان)
            if (pendingTime != null && confirmedTime != null) {
              final timeDiff = confirmedTime.difference(pendingTime).abs();
              return timeDiff.inMinutes < 2;
            }
            // إذا لم تكن هناك طوابع زمنية صالحة، اعتمد على تطابق النص وحده
            return true;
          }

          // المطابقة الثانوية: التعامل مع الحالات التي قد يعدل فيها الخادم النص قليلاً
          // هذا أكثر تحفظًا - يطابق فقط إذا كان تشابه النص مرتفعًا
          if (confirmedText.contains(pendingText) && pendingText.length > 10) {
            if (pendingTime != null && confirmedTime != null) {
              final timeDiff = confirmedTime.difference(pendingTime).abs();
              return timeDiff.inSeconds <
                  30; // نافذة زمنية أضيق للمطابقات التقريبية
            }
          }

          return false;
        });

        if (isConfirmed) {
          debugPrint(
              '[ChatConversation] إزالة رسالة معلقة مؤكدة: "${pendingText.substring(0, pendingText.length > 50 ? 50 : pendingText.length)}"');
        }
        return isConfirmed;
      });

      setState(() {
        _confirmedMessages = newMessages;
        _pendingMessages = updatedPendingMessages;
        _networkError = null;
      });
      _scrollToBottom(isNewMessage: true);
    } else if (state is ChatError) {
      setState(() => _networkError = state.message);
    }
  }

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _loadMessages();
      _showSuccessMessage("تم تحديث المحادثة");
    } catch (e) {
      _showErrorMessage("فشل تحديث المحادثة");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _startPolling() {
    _stopPolling();
    _messagePoller =
        Timer.periodic(_pollInterval, (_) => _loadMessages(showError: false));
  }

  void _stopPolling() => _messagePoller?.cancel();

  // ============================================================================
  // إرسال الرسائل وتحويل الكلام إلى نص
  // ============================================================================

  Future<void> _sendMessage({String? textOverride}) async {
    final text = textOverride ?? _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    // --- واجهة المستخدم المتفائلة ---
    // 1. إنشاء رسالة مؤقتة بمعرف سالب فريد لتجنب التعارض.
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now();
    final pending = PendingMessage(
      message: ChatMessageEntity(
        id: tempId,
        text: text,
        createdAt: now.toIso8601String(),
        sender: _getSelfParticipant(),
        conversationId: widget.chatId,
      ),
    );

    // 2. إضافتها إلى الحالة المحلية لعرضها فورًا.
    setState(() {
      _pendingMessages[tempId] = pending;
    });
    _scrollToBottom(isNewMessage: true);

    // 3. محاولة إرسال الرسالة إلى الخادم.
    try {
      Position? position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      );
      if (mounted) {
        await context
            .read<ChatCubit>()
            .sendMessageToConversation(
              chatId: widget.chatId,
              text: text,
              lat: position.latitude,
              lon: position.longitude,
              address: "الموقع",
            )
            .timeout(_networkTimeout);
      }
      // عند النجاح، سيلتقطها الاستقصاء التالي ويسوي الحالة.
    } catch (e) {
      // 4. إذا فشل الإرسال، قم بتحديث حالة الرسالة إلى 'فشلت'.
      debugPrint("خطأ في إرسال الرسالة: $e");
      setState(() {
        _pendingMessages[tempId] =
            pending.copyWith(status: MessageStatus.failed);
      });
    }
  }

  // ============================================================================
  // التسجيل والنسخ الصوتي
  // ============================================================================

  Future<void> _toggleRecording() async {
    if (!_isRecorderReady) {
      _showErrorMessage("المسجل غير جاهز.");
      return;
    }
    if (_isRecording) {
      await _stopRecordingAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      const codec = Codec.pcm16WAV;
      await _recorder.startRecorder(
        toFile: _pathToAudioFile,
        codec: codec,
      );
      setState(() => _isRecording = true);
    } catch (e, st) {
      debugPrint("فشل بدء المسجل (الترميز الأساسي): $e\n$st");

      // 🔁 الرجوع إلى AAC لفرض مسار إذن نظيف والتأكد من أنها ليست مشكلة ترميز
      try {
        final dir = await getTemporaryDirectory();
        _pathToAudioFile = p.join(dir.path, 'emergency_record.aac');
        await _recorder.startRecorder(
          toFile: _pathToAudioFile,
          codec: Codec.aacADTS,
        );
        setState(() => _isRecording = true);
        _showSuccessMessage(
            "استخدام AAC كبديل (حاوية Opus غير مدعومة على هذه المنصة).");
      } catch (e2, st2) {
        debugPrint("فشل بدء المسجل بترميز AAC البديل: $e2\n$st2");
        if (Platform.isIOS) {
          _showErrorMessage(
              "لا يمكن الوصول إلى الميكروفون. إذا رفضت الإذن سابقًا، قم بتمكينه في الإعدادات ← الخصوصية ← الميكروفون ← (تطبيقك)، أو أعد تثبيت التطبيق.");
        } else {
          _showErrorMessage("لا يمكن بدء التسجيل.");
        }
      }
    }
  }

  Future<void> _stopRecordingAndTranscribe() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      await _transcribeAudio();
    } catch (e) {
      debugPrint("خطأ في إيقاف المسجل: $e");
      _showErrorMessage("فشل في معالجة الصوت.");
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _transcribeAudio() async {
    if (_pathToAudioFile == null || !File(_pathToAudioFile!).existsSync()) {
      _showErrorMessage("ملف الصوت غير موجود.");
      return;
    }
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_sttApiUrl))
        ..files.add(
            await http.MultipartFile.fromPath('audio_file', _pathToAudioFile!));
      final response =
          await request.send().timeout(const Duration(seconds: 20));

      debugPrint("رمز الحالة: ${response.statusCode}");
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = json.decode(body);
        if (data['success'] == true && data['data']?['transcription'] != null) {
          final transcription = data['data']['transcription'] as String;
          _messageController.text = transcription;
        } else {
          throw Exception("واجهة برمجة التطبيقات أعادت بيانات غير صالحة.");
        }
      } else {
        throw Exception("خطأ في الخادم: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("فشل النسخ الصوتي: $e");
      _showErrorMessage("فشل تحويل الكلام إلى نص.");
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  // ============================================================================
  // طرق البناء: الواجهة الرئيسية وشريط التطبيق
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Expanded(child: _buildMessagesSection()),
          _buildMessageInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.chatTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      centerTitle: true,
      actions: [
        // إظهار زر التقرير إذا كانت هذه المحادثة تحتوي على تقرير طوارئ
        BlocBuilder<ChatCubit, ChatState>(
          buildWhen: (previous, current) {
            return current is ChatListLoaded;
          },
          builder: (context, state) {
            ConversationSummary? conversation;

            if (state is ChatListLoaded) {
              conversation = state.chats
                  .where((chat) => chat.id == widget.chatId)
                  .firstOrNull;
            } else {
              final chatCubit = context.read<ChatCubit>();
              if (chatCubit.state is ChatListLoaded) {
                final cachedState = chatCubit.state as ChatListLoaded;
                conversation = cachedState.chats
                    .where((chat) => chat.id == widget.chatId)
                    .firstOrNull;
              }
            }

            // إظهار زر الطوارئ إذا كان هناك أي بيانات للتقرير أو حالة أو مشارك ذكاء اصطناعي
            if (conversation?.topic.report != null ||
                conversation?.topic.latestStatus != null ||
                conversation?.participants
                        .any((p) => p.user.roles.contains('ai-agent')) ==
                    true) {
              return IconButton(
                icon: const Icon(Icons.emergency, color: Colors.red),
                tooltip: 'عرض تقرير الطوارئ',
                onPressed: () => _showEmergencyReport(
                    conversation?.topic.report ??
                        const EmergencyReport(
                            name: 'تقرير طوارئ', description: '', text: '')),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // قائمة المشاركين
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'participants':
                _showParticipants();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'participants',
              child: Row(
                children: [
                  Icon(Icons.people),
                  SizedBox(width: 8),
                  Text('عرض المشاركين'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEmergencyReport(EmergencyReport report) {
    final reportId = widget.chatId;

    final success = ReportDetailsService.showReport(reportId);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحميل تفاصيل التقرير. يرجى المحاولة مرة أخرى.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// الانتقال إلى الخريطة بموقع محدد من الرسالة
  void _viewLocationOnMap(LocationData location) {
    _navigateToMapWithLocation(location);
  }

  /// التعامل مع عرض الموقع من الرسائل الفردية
  void _navigateToMapWithLocation(LocationData location) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الموقع: ${location.address}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'نسخ الإحداثيات',
          onPressed: () {
            Clipboard.setData(ClipboardData(
              text: '${location.lat}, ${location.lon}',
            ));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم نسخ الإحداثيات إلى الحافظة')),
            );
          },
        ),
      ),
    );
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المشاركون (${widget.participants.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.participants.map((participant) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorForType(
                        participant.type?.toLowerCase() ?? 'user'),
                    backgroundImage:
                        participant.user.profileImage?.publicPath != null
                            ? NetworkImage(
                                participant.user.profileImage!.publicPath)
                            : null,
                    child: participant.user.profileImage == null
                        ? Text(
                            participant.user.name.isNotEmpty
                                ? participant.user.name[0].toUpperCase()
                                : '؟',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(participant.user.name),
                  subtitle: Text(_translateParticipantType(participant.type)),
                  onTap: () {
                    Navigator.of(context).pop();
                    showUserProfile(
                      context,
                      user: participant.user,
                      onMessage: () {
                        Navigator.of(context).pop();
                        _messageController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _messageController.text.length),
                        );
                      },
                    );
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // طرق البناء: عرض الرسائل
  // ============================================================================

  Widget _buildMessagesSection() {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: _handleChatStateChange,
      builder: (context, state) {
        if (_isInitializing && _confirmedMessages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMessages = <ChatMessageEntity>[];
        allMessages.addAll(_confirmedMessages);

        for (final pendingMessage
            in _pendingMessages.values.map((p) => p.message)) {
          final pendingText = pendingMessage.text.trim();

          final isDuplicate = _confirmedMessages.any((confirmed) =>
              confirmed.sender?.user.id == widget.currentUserId &&
              confirmed.text.trim() == pendingText);

          if (!isDuplicate) {
            allMessages.add(pendingMessage);
          } else {
            debugPrint(
                '[ChatConversation] تخطي رسالة معلقة مكررة في العرض: "${pendingText.substring(0, pendingText.length > 30 ? 30 : pendingText.length)}"');
          }
        }

        allMessages.sort((a, b) {
          final aTime = DateTime.tryParse(a.createdAt ?? '');
          final bTime = DateTime.tryParse(b.createdAt ?? '');

          if (aTime == null && bTime == null) return a.id.compareTo(b.id);
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return aTime.compareTo(bTime);
        });

        if (allMessages.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: _handleManualRefresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: allMessages.length,
            itemBuilder: (context, index) {
              final message = allMessages[index];
              final participant = _findParticipant(message.sender?.user.id);
              final status = _pendingMessages[message.id]?.status;

              final previousMessage = index > 0 ? allMessages[index - 1] : null;
              final showHeader = _shouldShowHeader(message, previousMessage);
              final isCurrentUser =
                  message.sender?.user.id == widget.currentUserId;

              return _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                participant: participant,
                isCurrentUser: isCurrentUser,
                showHeader: showHeader,
                status: status,
                onViewLocation: _viewLocationOnMap,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text("ابدأ المحادثة.", style: TextStyle(color: Colors.grey)),
    );
  }

  // ============================================================================
  // طرق البناء: شريط إدخال الرسائل
  // ============================================================================

  Widget _buildMessageInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border:
            Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: _buildTextInputField()),
                  const SizedBox(width: 8),
                  _buildSendOrRecordButton(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("محادثة الطوارئ مراقبة 24/7",
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 8,
                            color: _networkError == null
                                ? Colors.green
                                : Colors.orange),
                        const SizedBox(width: 4),
                        Text("متصل",
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputField() {
    return TextField(
      controller: _messageController,
      focusNode: _focusNode,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _sendMessage(),
      decoration: InputDecoration(
        hintText: _isRecording ? 'جارٍ تسجيل الصوت...' : 'اكتب رسالتك...',
        fillColor: const Color(0xFFF8F9FA),
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildSendOrRecordButton() {
    final showSendButton = _hasText && !_isRecording;
    return GestureDetector(
      onTap: showSendButton ? _sendMessage : _toggleRecording,
      child: CircleAvatar(
        radius: 24,
        backgroundColor:
            showSendButton ? Colors.red.shade600 : Colors.grey.shade200,
        child: _isTranscribing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                showSendButton ? Icons.send : Icons.mic,
                color: showSendButton
                    ? Colors.white
                    : (_isRecording ? Colors.red.shade600 : Colors.black54),
                size: 24,
              ),
      ),
    );
  }

  // ============================================================================
  // الطرق المساعدة
  // ============================================================================

  ChatParticipant _findParticipant(int? userId) {
    if (userId == null) {
      return const ChatParticipant(
          id: -1, user: ChatUser(id: -1, name: 'غير معروف'));
    }
    return _filteredParticipants.firstWhere(
      (p) => p.user.id == userId,
      orElse: () {
        // حل بديل للحالات التي قد تكون فيها قائمة المشاركين قديمة
        final confirmedSender = _confirmedMessages
            .firstWhere((m) => m.sender?.user.id == userId,
                orElse: () => const ChatMessageEntity(id: -1))
            .sender;
        return confirmedSender ??
            const ChatParticipant(
                id: -1, user: ChatUser(id: -1, name: 'غير معروف'));
      },
    );
  }

  ChatParticipant _getSelfParticipant() {
    return widget.participants.firstWhere(
      (p) => p.user.id == widget.currentUserId,
      orElse: () => ChatParticipant(
          id: -1, user: ChatUser(id: widget.currentUserId, name: 'أنت')),
    );
  }

  bool _shouldShowHeader(
      ChatMessageEntity current, ChatMessageEntity? previous) {
    if (previous == null) return true;
    if (current.sender?.user.id != previous.sender?.user.id) return true;
    final currentTime = DateTime.tryParse(current.createdAt ?? '');
    final prevTime = DateTime.tryParse(previous.createdAt ?? '');
    if (currentTime == null || prevTime == null) return true;
    return currentTime.difference(prevTime).inMinutes >= 3;
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // التمرير التلقائي فقط إذا كان المستخدم قريبًا من الأسفل، إلا إذا كانت رسالته الجديدة
      if (position.maxScrollExtent - position.pixels < 100 || isNewMessage) {
        _scrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorMessage(String message) {
    if (!mounted || !ScaffoldMessenger.of(context).mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ));
  }

  void _showSuccessMessage(String message) {
    if (!mounted || !ScaffoldMessenger.of(context).mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
      ));
  }

  String _translateParticipantType(String? type) {
    switch (type?.toLowerCase()) {
      case 'police':
        return 'الشرطة';
      case 'fire_department':
      case 'fire':
        return 'الإطفاء';
      case 'medical':
        return 'خدمات طبية';
      case 'traffic':
        return 'المرور';
      case 'civil_defense':
        return 'الدفاع المدني';
      default:
        return 'مستخدم';
    }
  }

  void _cleanup() {
    _stopPolling();
    _recorder.closeRecorder();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonAnimationController.dispose();
  }
}

// ============================================================================
// الويدجت: فقاعة الرسالة والصورة الرمزية
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final ChatParticipant participant;
  final bool isCurrentUser;
  final bool showHeader;
  final MessageStatus? status;
  final Function(LocationData)? onViewLocation;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.participant,
    required this.isCurrentUser,
    required this.showHeader,
    this.status,
    this.onViewLocation,
  });

  @override
  Widget build(BuildContext context) {
    final participantType = participant.type?.toLowerCase() ?? 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            GestureDetector(
              onTap: () {
                showUserProfile(
                  context,
                  user: participant.user,
                  onMessage: () {
                    Navigator.of(context).pop();
                  },
                );
              },
              child: _UserAvatar(participant: participant),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showHeader && !isCurrentUser)
                  _buildSenderHeader(participantType),
                _buildMessageContent(context),
                _buildMessageFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderHeader(String type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
      child: Text(
        participant.user.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getColorForType(type).shade900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final bubbleColor = isCurrentUser ? Colors.red.shade600 : Colors.white;
    final textColor = isCurrentUser ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _showMessageOptions(context),
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border:
                isCurrentUser ? null : Border.all(color: Colors.grey.shade300)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text,
                style: TextStyle(color: textColor, fontSize: 16, height: 1.4)),

            // إظهار الموقع إذا كان متاحًا
            if (message.location != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.red.shade500
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: isCurrentUser ? Colors.white : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.location!.address,
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // إظهار مؤشر التسجيل الصوتي إذا كان متاحًا
            if (message.voiceRecord != null ||
                message.voiceRecordText != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.red.shade500
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: isCurrentUser ? Colors.white : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'رسالة صوتية',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    final options = <Widget>[];

    // خيار نسخ الرسالة
    options.add(
      ListTile(
        leading: const Icon(Icons.copy),
        title: const Text('نسخ الرسالة'),
        onTap: () {
          Navigator.of(context).pop();
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ الرسالة إلى الحافظة')),
          );
        },
      ),
    );

    // خيار عرض الموقع
    if (message.location != null) {
      options.add(
        ListTile(
          leading: const Icon(Icons.location_on),
          title: const Text('عرض الموقع'),
          onTap: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('الموقع: ${message.location!.address}'),
                action: SnackBarAction(
                  label: 'فتح الخريطة',
                  onPressed: () {
                    if (onViewLocation != null) {
                      onViewLocation!(message.location!);
                    }
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    // خيار عرض الملف الشخصي للمرسل (للمستخدمين الآخرين)
    if (!isCurrentUser) {
      options.add(
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('عرض الملف الشخصي'),
          onTap: () {
            Navigator.of(context).pop();
            // showUserProfile(context, user: participant.user);
          },
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options,
      ),
    );
  }

  Widget _buildMessageFooter() {
    final createdAt = DateTime.tryParse(message.createdAt ?? '')?.toLocal();
    if (createdAt == null) return const SizedBox.shrink();

    String hour =
        (createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12).toString();
    String minute = createdAt.minute.toString().padLeft(2, '0');
    final timeString = '$hour:$minute';

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeString,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          if (isCurrentUser && status != null) ...[
            const SizedBox(width: 4),
            Icon(
              status == MessageStatus.pending
                  ? Icons.access_time_rounded
                  : Icons.error_outline,
              size: 12,
              color: status == MessageStatus.pending
                  ? Colors.grey.shade500
                  : Colors.red.shade400,
            ),
          ],
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final ChatParticipant participant;
  const _UserAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final name = participant.user.name.toLowerCase();
    final type = participant.type?.toLowerCase() ?? 'user';

    IconData iconData = Icons.person;
    Color color = _getColorForType(type);

    if (name.contains('ai') || name.contains('assistant')) {
      iconData = Icons.smart_toy_outlined;
      color = Colors.blueGrey;
    } else if (type.contains('police')) {
      iconData = Icons.local_police;
    } else if (type.contains('fire')) {
      iconData = Icons.local_fire_department;
    } else if (type.contains('medical')) {
      iconData = Icons.medical_services;
    } else if (type.contains('traffic')) {
      iconData = Icons.traffic;
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Icon(iconData, color: Colors.white, size: 22),
    );
  }
}

// دالة مساعدة لتعيين ألوان متسقة لأنواع المستجيبين
MaterialColor _getColorForType(String type) {
  switch (type) {
    case 'police':
      return Colors.blue;
    case 'fire_department':
    case 'fire':
      return Colors.orange;
    case 'medical':
      return Colors.green;
    case 'traffic':
      return Colors.purple;
    case 'civil_defense':
      return Colors.cyan;
    default:
      return Colors.grey;
  }
}
