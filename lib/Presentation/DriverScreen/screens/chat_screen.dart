import 'dart:io';
import 'package:hopper/Core/Utility/app_loader.dart';
import 'package:hopper/Core/Utility/typing_animate.dart';
import 'package:hopper/Presentation/DriverScreen/controller/upload_image_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Constants/log.dart';
import 'package:hopper/Core/Utility/images.dart';
import 'package:hopper/utils/websocket/socket_io_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String message;
  final String? audioUrl;
  final bool isMe;
  final String time;
  final String avatar;
  final String? imageUrl;
  bool isSending; // ✅ new flag for loading state
  final bool isTyping; // 👈 NEW
  ChatMessage({
    required this.message,
    this.audioUrl,
    required this.isMe,
    required this.time,
    required this.avatar,
    this.imageUrl,
    this.isSending = false,
    this.isTyping = false, // 👈 default false
  });
}

class ChatScreen extends StatefulWidget {
  final String bookingId;
  const ChatScreen({super.key, required this.bookingId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  String? _audioPath;
  String? driverId;
  bool isTyping = false;
  String typingUser = "";

  final socketService = SocketService();
  String customerId = '';
  Map<String, bool> _playingStates = {};

  String? _pendingAudioPath;

  List<ChatMessage> messages = [];
  final UploadImageController controller = Get.put(UploadImageController());

  Future<void> requestMicPermission() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw Exception('Microphone permission not granted');
    }
  }

  /*  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    driverId = await SharedPrefHelper.getDriverId();
    final locationData = {
      'bookingId': widget.bookingId,
      'senderId': driverId,
      'senderType': "driver",
      "contents": [
        {"type": "text", "value": message},
          {"type": "image", "value": 'uploadedImageUrl'},
        // {"type": "voice", "value": uploadedVoiceUrl},
      ],
    };

    socketService.emitWithAck("booking-message", locationData, (ack) {
      print(
        "📩 Ack received from server: $ack",
      ); // 👈 this will show what server sends back

      if (ack != null && ack['success'] == true) {
        setState(() {
          messages.add(
            ChatMessage(
              message: message,
              isMe: true,
              time: DateTime.now().toString(),
              avatar: AppImages.dummy1,
            ),
          );
        });
        _textController.clear();
        _scrollToBottom();
      } else {
        CommonLogger.log.e("Message send failed: $ack");
      }
    });
  }*/

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        messages.add(
          ChatMessage(
            isMe: true,
            imageUrl: image.path,
            message: '',
            time: 'Now',
            avatar: AppImages.dummy1,
            isSending: true,
          ),
        );
      });
      _scrollToBottom();

      await controller.uploadImage(context, File(image.path));
      final uploadedUrl = controller.frontImageUrl.value;

      int index = messages.lastIndexWhere((m) => m.isSending);
      if (uploadedUrl.isNotEmpty && index != -1) {
        // Send via WebSocket
        _sendMessage('', imageUrl: uploadedUrl);
      } else {
        // Upload failed: remove placeholder message
        setState(() {
          messages.removeAt(index);
        });
      }
    }
  }

  Future<void> _sendMessage(String message, {String? imageUrl}) async {
    if ((message.trim().isEmpty) && imageUrl == null) return;

    // Only add placeholder for text messages
    if (message.trim().isNotEmpty) {
      setState(() {
        messages.add(
          ChatMessage(
            message: message,
            imageUrl: imageUrl,
            isMe: true,
            time: 'Now',
            avatar: AppImages.dummy1,
            isSending: true,
          ),
        );
      });
      _scrollToBottom();
    }

    driverId = await SharedPrefHelper.getDriverId();

    final contents = <Map<String, String>>[];
    if (message.trim().isNotEmpty)
      contents.add({"type": "text", "value": message});
    if (imageUrl != null) contents.add({"type": "image", "value": imageUrl});

    final locationData = {
      'bookingId': widget.bookingId,
      'senderId': driverId,
      'senderType': "driver",
      'contents': contents,
    };

    socketService.emitWithAck("booking-message", locationData, (ack) {
      int index = messages.lastIndexWhere((m) => m.isSending);
      if (ack != null && ack['success'] == true && index != -1) {
        setState(() {
          messages[index] = ChatMessage(
            message: message,
            imageUrl: imageUrl,
            isMe: true,
            time: DateTime.now().toString(),
            avatar: AppImages.dummy1,
            isSending: false, // remove loading
          );
        });
        _textController.clear();
        _scrollToBottom();
      } else {
        CommonLogger.log.e("Message send failed: $ack");
        // Optionally, show error UI or retry
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeSocketAndData();
    _initRecorder();
    _player.openPlayer();
  }

  Future<void> loadCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('customer_Id') ?? '';

    if (customerId.isEmpty) {
      CommonLogger.log.w('⚠️ No customer ID found in shared preferences.');
    } else {
      CommonLogger.log.i('✅ Loaded customerId = $customerId');
    }
  }

  Future<void> _initializeSocketAndData() async {
    await loadCustomerId();
    final userId = customerId;

    socketService.initSocket(
      'https://hoppr-face-two-dbe557472d7f.herokuapp.com',
    );

    socketService.onConnect(() {
      socketService.registerUser(userId);

      socketService.onReconnect(() {
        CommonLogger.log.i("🔄 Reconnected");
        socketService.registerUser(customerId); // re-register after reconnect
      });
    });

    socketService.on('registered', (data) {
      CommonLogger.log.i("✅ Registered → $data");
    });
    socketService.on("typing", (data) {
      if (!mounted) return;

      final senderId = data["senderId"];
      final senderType = data["senderType"];
      if (senderType == 'driver') return;

      setState(() {
        // remove old typing indicator for this user if exists
        messages.removeWhere(
          (m) => m.isTyping && m.message.isEmpty && m.isMe == false,
        );

        messages.add(
          ChatMessage(
            message: "",
            isMe: false,
            avatar: AppImages.dummy,
            time: "",
            isTyping: true,
          ),
        );
      });

      // auto-remove after 3 seconds if no stop event
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            messages.removeWhere((m) => m.isTyping);
          });
        }
      });
    });

    /*_bookingMessageHandler = (data) {
      final senderId = data['senderId'] ?? '';
      if (senderId == driverId) return;

      final List<dynamic> contents = data['contents'] ?? [];
      final textContent = contents.firstWhere(
        (c) => c['type'] == 'text',
        orElse: () => null,
      );

      if (textContent == null) return;
      final ImageContent = contents.firstWhere(
        (c) => c['type'] == 'image',
        orElse: () => null,
      );
      if (!mounted) return;

      setState(() {
        messages.add(
          ChatMessage(
            imageUrl: textContent['value'],
            message: textContent['value'],
            isMe: false,
            time: DateTime.now().toString().substring(11, 16),
            avatar: AppImages.dummy,
          ),
        );
      });

      _scrollToBottom();
    };*/
    _bookingMessageHandler = (data) {
      final senderId = data['senderId'] ?? '';
      if (senderId == driverId) return;

      final List<dynamic> contents = data['contents'] ?? [];
      if (contents.isEmpty) return;
      if (!mounted) return;

      for (var c in contents) {
        if (c['type'] == 'text' &&
            c['value'] != null &&
            c['value'].toString().isNotEmpty) {
          setState(() {
            messages.add(
              ChatMessage(
                message: c['value'], // ✅ keep text here
                imageUrl: '', // no image
                isMe: false,
                time: DateTime.now().toString().substring(11, 16),
                avatar: AppImages.dummy,
              ),
            );
          });
        } else if (c['type'] == 'image' &&
            c['value'] != null &&
            c['value'].toString().isNotEmpty) {
          setState(() {
            messages.add(
              ChatMessage(
                message: '', // no text
                imageUrl: c['value'], // ✅ keep image here
                isMe: false,
                time: DateTime.now().toString().substring(11, 16),
                avatar: AppImages.dummy,
              ),
            );
          });
        }
      }

      _scrollToBottom();
    };

    socketService.on('booking-message', _bookingMessageHandler);
  }

  late final Function(dynamic) _bookingMessageHandler;
  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 75,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.commonWhite,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(AppImages.backButton, height: 25, width: 25),
            SizedBox(width: 15),
            Stack(
              children: [
                ClipPath(
                  clipper: CutOutCircleClipper(cutRadius: 5),
                  child: Image.asset(
                    AppImages.dummy,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                  ),
                ),

                Positioned(
                  top: 2,
                  right: 2,
                  child: Image.asset(
                    AppImages.dart,
                    height: 8,
                    color: Color(0xff52C41A),
                  ),
                ),
              ],
            ),

            SizedBox(width: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextfield.textWithStylesSmall(
                  'Oluwaseun Michael',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  colors: AppColors.commonBlack,
                ),
                CustomTextfield.textWithStylesSmall(
                  '2.1 km away',
                  fontSize: 12,
                  colors: AppColors.commonBlack.withOpacity(0.6),
                ),
              ],
            ),
            Spacer(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: AppColors.chatCallContainerColor,
              ),

              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () async {
                    const phoneNumber = 'tel:8248191110';
                    CommonLogger.log.i(phoneNumber);
                    final Uri url = Uri.parse(phoneNumber);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      print('Could not launch dialer');
                    }
                  },
                  child: Image.asset(AppImages.call, height: 20, width: 20),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.lowLightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Image.asset(
                        AppImages.box,
                        height: 35,
                        width: 35,
                      ),

                      title: CustomTextfield.textWithStyles600(
                        'Order PKG-2025-7841',
                      ),
                      subtitle: CustomTextfield.textWithStylesSmall(
                        fontSize: 12,
                        'Pickup: 123 Main Street • Weight: 2.5 kg',
                        colors: AppColors.changeButtonColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.adminChatContainerColor,
                        ),
                      ),
                      child: ListView.builder(
                        reverse: false,
                        controller: _scrollController,
                        itemCount: messages.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final current = messages[index];
                          final previous =
                              index > 0 ? messages[index - 1] : null;
                          final next =
                              index < messages.length - 1
                                  ? messages[index + 1]
                                  : null;

                          final showAvatar =
                              previous == null || previous.isMe != current.isMe;
                          final showTime =
                              next == null || next.isMe != current.isMe;

                          return buildMessage(current, showAvatar, showTime);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        splashColor: Colors.black.withOpacity(
                          0.05,
                        ), // subtle splash
                        highlightColor: Colors.transparent,
                        onTap: () {
                          _sendMessage("I'm waiting downstairs");
                        },
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.containerColor1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CustomTextfield.textWithStylesSmall(
                            fontSize: 14,
                            colors: AppColors.commonBlack,
                            'I’m waiting downstairs',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        splashColor: Colors.black.withOpacity(
                          0.05,
                        ), // subtle splash
                        highlightColor: Colors.transparent,
                        onTap: () {
                          _sendMessage("Please call when you arrive");
                        },
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.containerColor1,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: CustomTextfield.textWithStylesSmall(
                            fontSize: 14,
                            colors: AppColors.commonBlack,
                            'Please call when you arrive',
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            if (_pendingAudioPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lowLightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("Voice message ready to send"),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _pendingAudioPath = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Row(
                children: [
                  GestureDetector(
                    // onTap: () async {
                    //   final ImagePicker picker = ImagePicker();
                    //   final XFile? image = await picker.pickImage(
                    //     source: ImageSource.camera,
                    //   );
                    //
                    //   if (image != null) {
                    //     setState(() {
                    //       messages.add(
                    //         ChatMessage(
                    //           isMe: true,
                    //           imageUrl: image.path,
                    //           message: '',
                    //           time: 'Now',
                    //           avatar: AppImages.dummy1,
                    //         ),
                    //       );
                    //     });
                    //     _scrollToBottom();
                    //   }
                    // },
                    onTap: _pickAndSendImage,
                    child: Image.asset(AppImages.camera, height: 26, width: 26),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: AppColors.containerColor1,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Row(
                        children: [
                          // Text Field
                          Expanded(
                            child: TextField(
                              onChanged: (val) async {
                                driverId = await SharedPrefHelper.getDriverId();
                                final data = {
                                  'bookingId': widget.bookingId,
                                  'senderId': driverId,
                                  'senderType': 'driver',
                                };
                                socketService.emit('typing', data);
                              },
                              controller: _textController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          // Mic button
                          GestureDetector(
                            onTap: () async {
                              if (!_isRecording) {
                                Directory tempDir =
                                    await getTemporaryDirectory();
                                _audioPath =
                                    '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
                                await _recorder.startRecorder(
                                  toFile: _audioPath,
                                  codec: Codec.aacADTS,
                                );
                              } else {
                                await _recorder.stopRecorder();
                                setState(() {
                                  _pendingAudioPath = _audioPath;
                                });
                              }

                              setState(() {
                                _isRecording = !_isRecording;
                              });
                            },
                            child:
                                _isRecording
                                    ? Icon(Icons.pause)
                                    : Image.asset(
                                      AppImages.mic,
                                      height: 26,
                                      width: 26,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: 5),

                  InkWell(
                    borderRadius: BorderRadius.circular(15),
                    splashColor: Colors.blue.withOpacity(0.2),
                    highlightColor: Colors.blue.withOpacity(0.1),
                    onTap: () {
                      final message = _textController.text.trim();

                      if (_pendingAudioPath != null) {
                        // Sending voice message
                        final audioMsg = ChatMessage(
                          isMe: true,
                          audioUrl: _pendingAudioPath!,
                          message: '',
                          time: 'Now',
                          avatar: AppImages.dummy1,
                        );

                        setState(() {
                          messages.add(audioMsg);
                          _pendingAudioPath = null;
                        });
                        CommonLogger.log.i('my Audio $_pendingAudioPath');
                        _scrollToBottom();
                      } else if (message.isNotEmpty) {
                        CommonLogger.log.i('my Audio $_pendingAudioPath');
                        // Sending normal text message
                        _sendMessage(message);
                      }
                    },

                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Image.asset(
                        AppImages.sendButton,
                        height: 40,
                        width: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessage(ChatMessage msg, bool showAvatar, bool showTime) {
    return Row(
      mainAxisAlignment:
          msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 👤 Show avatar for other users
        if (!msg.isMe && showAvatar) buildAvatar(msg.avatar),
        if (!msg.isMe && !showAvatar) const SizedBox(width: 46),

        const SizedBox(width: 6),

        Column(
          crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 💬 Typing Indicator Bubble
            if (msg.isTyping)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const SmoothTypingIndicator(), // 👈 animated dots
              ),

            // ✅ Text message
            if (msg.message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.adminChatContainerColor),
                  color:
                      msg.isMe
                          ? AppColors.userChatContainerColor
                          : AppColors.commonWhite,
                  borderRadius: BorderRadius.circular(15),
                ),
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  msg.message,
                  style: TextStyle(
                    color: msg.isMe ? Colors.white : const Color(0xff262626),
                  ),
                ),
              ),

            // ✅ Audio message
            if (msg.audioUrl != null && msg.audioUrl!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.adminChatContainerColor),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _playingStates[msg.audioUrl] == true
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.blue,
                      ),
                      onPressed: () async {
                        bool isCurrentlyPlaying =
                            _playingStates[msg.audioUrl] == true;
                        if (isCurrentlyPlaying) {
                          await _player.stopPlayer();
                          setState(() {
                            _playingStates[msg.audioUrl!] = false;
                          });
                        } else {
                          await _player.stopPlayer();
                          setState(() {
                            _playingStates.updateAll((key, value) => false);
                            _playingStates[msg.audioUrl!] = true;
                          });
                          await _player.startPlayer(
                            fromURI: msg.audioUrl,
                            codec: Codec.aacADTS,
                            whenFinished: () {
                              setState(() {
                                _playingStates[msg.audioUrl!] = false;
                              });
                            },
                          );
                        }
                      },
                    ),
                    const Text("Voice message"),
                  ],
                ),
              ),

            // ✅ Image message
            if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.adminChatContainerColor,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: buildChatImage(msg.imageUrl!),
                  ),
                  if (msg.isSending)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(child: AppLoader.circularLoader()),
                      ),
                    ),
                ],
              ),

            // ✅ Time
            if (showTime && !msg.isTyping)
              Text(
                msg.time,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),

        const SizedBox(width: 6),

        // 👤 Show avatar for current user
        if (msg.isMe && showAvatar) buildAvatar(msg.avatar),
        if (msg.isMe && !showAvatar) const SizedBox(width: 46),
      ],
    );
  }

  Widget buildChatImage(String imagePath) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
      );
    } else {
      final cleanPath = imagePath.replaceFirst('file://', '');
      if (File(cleanPath).existsSync()) {
        return Image.file(
          File(cleanPath),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        );
      } else {
        return const Icon(Icons.broken_image, size: 50);
      }
    }
  }

  /// ✅ Avatar always safe
  Widget buildAvatar(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.lowLightBlue,
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    Widget avatar;
    if (imagePath.startsWith('http')) {
      avatar = Image.network(
        imagePath,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.person),
      );
    } else if (imagePath.startsWith('/data') ||
        imagePath.startsWith('file:/')) {
      final cleanPath = imagePath.replaceFirst('file://', '');
      avatar =
          File(cleanPath).existsSync()
              ? Image.file(
                File(cleanPath),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              )
              : const Icon(Icons.person);
    } else {
      avatar = Image.asset(imagePath, width: 40, height: 40, fit: BoxFit.cover);
    }

    return Stack(
      children: [
        ClipOval(child: avatar),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /*  Widget buildMessage(ChatMessage msg, bool showAvatar, bool showTime) {
    return Row(
      mainAxisAlignment:
          msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isMe && showAvatar) buildAvatar(msg.avatar),
        if (!msg.isMe && !showAvatar)
          const SizedBox(width: 46), // to align with avatar size
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment:
              msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.adminChatContainerColor),
                  color:
                      msg.isMe
                          ? AppColors.userChatContainerColor
                          : AppColors.commonWhite,
                  borderRadius: BorderRadius.circular(15),
                ),
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  msg.message,
                  style: TextStyle(
                    color: msg.isMe ? Colors.white : Color(0xff262626),
                  ),
                ),
              ),
            if (msg.audioUrl != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.adminChatContainerColor),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _playingStates[msg.audioUrl] == true
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.blue,
                      ),
                      onPressed: () async {
                        bool isCurrentlyPlaying =
                            _playingStates[msg.audioUrl] == true;

                        if (isCurrentlyPlaying) {
                          await _player.stopPlayer();
                          setState(() {
                            _playingStates[msg.audioUrl!] = false;
                          });
                        } else {
                          // Stop any previous playing audio
                          await _player.stopPlayer();

                          setState(() {
                            _playingStates.updateAll((key, value) => false);
                            // Set current to true
                            _playingStates[msg.audioUrl!] = true;
                          });

                          await _player.startPlayer(
                            fromURI: msg.audioUrl,
                            codec: Codec.aacADTS,
                            whenFinished: () {
                              setState(() {
                                _playingStates[msg.audioUrl!] = false;
                              });
                            },
                          );
                        }
                      },
                    ),

                    const Text("Voice message"),
                  ],
                ),
              ),
            if (msg.imageUrl != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.adminChatContainerColor),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Image.file(
                  File(msg.imageUrl ?? ''),
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                ),
              ),

            if (showTime)
              Text(
                msg.time,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(width: 6),
        if (msg.isMe && showAvatar) buildAvatar(msg.avatar),
        if (msg.isMe && !showAvatar) const SizedBox(width: 46),
      ],
    );
  }*/

  /*  Widget buildAvatar(String imagePath) {
    return Stack(
      children: [
        ClipPath(
          clipper: CutOutCircleClipper(cutRadius: 2),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.lowLightBlue,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Image.asset(
                imagePath,
                width: 40,
                height: 40,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }*/
}

class CutOutCircleClipper extends CustomClipper<Path> {
  final double? cutRadius;

  CutOutCircleClipper({this.cutRadius = 8});

  @override
  Path getClip(Size size) {
    double mainRadius = size.width / 2;

    // Use the class property directly
    double radius = cutRadius ?? 5;
    Offset cutCenter = Offset(size.width - 6, 6);

    // Main circular image
    final fullCircle =
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(mainRadius, mainRadius),
            radius: mainRadius,
          ),
        );

    // Small cut-out circle path
    final cutCircle =
        Path()..addOval(Rect.fromCircle(center: cutCenter, radius: radius));

    // Combine with a difference operation to create the notch
    return Path.combine(PathOperation.difference, fullCircle, cutCircle);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
