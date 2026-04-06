import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Presentation/CustomerSupport/controller/customer_support_controller.dart';
import 'package:hopper/Presentation/CustomerSupport/models/customer_support_models.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CustomerSupportChatScreen extends StatefulWidget {
  final String ticketId;
  const CustomerSupportChatScreen({super.key, required this.ticketId});

  @override
  State<CustomerSupportChatScreen> createState() =>
      _CustomerSupportChatScreenState();
}

class _CustomerSupportChatScreenState extends State<CustomerSupportChatScreen> {
  late final CustomerSupportController c;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _attachments = <File>[];
  bool _sending = false;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    c =
        Get.isRegistered<CustomerSupportController>()
            ? Get.find<CustomerSupportController>()
            : Get.put(CustomerSupportController());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _loadingDetail = true);
      await c.loadTicketDetail(widget.ticketId);
      if (mounted) setState(() => _loadingDetail = false);
      _jumpBottom();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _send() => unawaited(_sendAsync());

  Future<void> _pickImages() async {
    try {
      final picks = await _picker.pickMultiImage(imageQuality: 80);
      if (picks.isEmpty) return;
      setState(() {
        for (final x in picks) {
          final f = File(x.path);
          if (_attachments.any((e) => e.path == f.path)) continue;
          _attachments.add(f);
        }
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _sendAsync() async {
    if (_sending) return;

    final msg = _text.text.trim();
    if (msg.isEmpty && _attachments.isEmpty) return;

    setState(() => _sending = true);

    final files = List<File>.from(_attachments);

    // Clear UI immediately (controller shows optimistic message + loader)
    _text.clear();
    setState(() => _attachments.clear());
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpBottom());

    final ok = await c.sendTicketMessage(
      ticketId: widget.ticketId,
      message: msg,
      files: files,
    );

    if (!ok && mounted) {
      Get.snackbar(
        'Failed',
        'Message not sent. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('hh.mma');
    final dateFmt = DateFormat('dd.MM.yy');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Support Chat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Obx(() {
              final t = c.ticketById(widget.ticketId);
              if (t == null) return const SizedBox(height: 12);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.status.label,
                            style: TextStyle(
                              color: t.status.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Created on ${dateFmt.format(t.createdAt)}',
                            style: const TextStyle(
                              color: Color(0xFF98A2B3),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      width: 86,
                      child: ElevatedButton(
                        onPressed: () {
                          c.closeTicketLocal(widget.ticketId);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.commonBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Close\nTicket',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Expanded(
              child: Obx(() {
                final t = c.ticketById(widget.ticketId);
                final messages = t?.messages ?? const [];

                if (t == null && c.isLoading.value) {
                  return const Center(
                    child: HopprCircularLoader(color: Colors.black),
                  );
                }

                if (_loadingDetail || c.isTicketDetailLoading.value) {
                  return const Center(
                    child: HopprCircularLoader(color: Colors.black),
                  );
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.fromCustomer; // mapped using current userId
                    final bubbleColor =
                        isMe
                            ? const Color(0xFF101828)
                            : const Color(0xFFF2F4F7);
                    final textColor = isMe ? Colors.white : Colors.black;
                    final timeColor =
                        isMe
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF98A2B3);

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.localFilePaths.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: m.localFilePaths
                                    .take(3)
                                    .map((p) {
                                      final f = File(p);
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Image.file(
                                              f,
                                              width: 150,
                                              height: 110,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (m.pending)
                                            Positioned.fill(
                                              child: Container(
                                                color: Colors.black.withOpacity(
                                                  0.08,
                                                ),
                                                alignment: Alignment.center,
                                                child: HopprCircularLoader(
                                                  radius: 8,
                                                  size: 16,
                                                  color:
                                                      isMe
                                                          ? Colors.white
                                                          : Colors.black,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (m.attachments.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: m.attachments
                                    .take(3)
                                    .map((url) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          width: 150,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              (_, __) => HopprCircularLoader(
                                                radius: 10,
                                                size: 20,
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : Colors.black,
                                              ),
                                          errorWidget:
                                              (_, __, ___) => Container(
                                                width: 150,
                                                height: 110,
                                                color: Colors.black.withOpacity(
                                                  0.08,
                                                ),
                                                child: const Icon(
                                                  Icons.broken_image,
                                                ),
                                              ),
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (m.text.trim().isNotEmpty) ...[
                              Text(
                                m.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (m.pending)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: HopprCircularLoader(
                                      radius: 6,
                                      size: 12,
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                if (m.failed)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.error_outline_rounded,
                                      size: 14,
                                      color:
                                          isMe
                                              ? Colors.white.withOpacity(0.9)
                                              : Colors.red,
                                    ),
                                  ),
                                Text(
                                  timeFmt.format(m.createdAt).toLowerCase(),
                                  style: TextStyle(
                                    color: timeColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attachments.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        height: 74,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachments.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final f = _attachments[i];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    f,
                                    width: 74,
                                    height: 74,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => _attachments.removeAt(i));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _sending ? null : _pickImages,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(Icons.attach_file_rounded),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _text,
                              enabled: !_sending,
                              decoration: const InputDecoration(
                                hintText: 'Type your message...',
                                border: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _sending ? null : _send,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.commonBlack,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child:
                                  _sending
                                      ? const HopprCircularLoader(
                                        radius: 10,
                                        size: 20,
                                        color: Colors.white,
                                      )
                                      : const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
