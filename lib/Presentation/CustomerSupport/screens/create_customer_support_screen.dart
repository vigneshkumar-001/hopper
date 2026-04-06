import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Core/Utility/snackbar.dart';
import 'package:hopper/Presentation/CustomerSupport/controller/customer_support_controller.dart';
import 'package:hopper/utils/widgets/hoppr_circular_loader.dart';
import 'package:image_picker/image_picker.dart';

class CreateCustomerSupportScreen extends StatefulWidget {
  final String? prefillBookingId;
  const CreateCustomerSupportScreen({super.key, this.prefillBookingId});

  @override
  State<CreateCustomerSupportScreen> createState() =>
      _CreateCustomerSupportScreenState();
}

class _CreateCustomerSupportScreenState
    extends State<CreateCustomerSupportScreen> {
  late final CustomerSupportController c;
  final _subject = TextEditingController();
  final _desc = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<File> _attachments = <File>[];

  bool _submitting = false;

  String _categoryId = '';
  String _subcategoryId = '';
  String _priority = '';

  @override
  void initState() {
    super.initState();
    c =
        Get.isRegistered<CustomerSupportController>()
            ? Get.find<CustomerSupportController>()
            : Get.put(CustomerSupportController());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.loadCommonDetails());
  }

  @override
  void dispose() {
    _subject.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _attachments.add(File(picked.path)));
    } catch (_) {}
  }

  Future<void> _showPickSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickAttachment(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickAttachment(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF2F4F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _create() async {
    if (_submitting) return;

    final navigator = Navigator.of(context);

    final subject = _subject.text.trim();
    final desc = _desc.text.trim();

    if (c.commonDetails.value == null) {
      CustomSnackBar.showInfo(
        c.commonError.value.isNotEmpty
            ? c.commonError.value
            : 'Loading support details...',
        title: 'Support',
      );
      return;
    }

    if (subject.isEmpty || desc.isEmpty) {
      CustomSnackBar.showError(
        'Please enter subject and description',
        title: 'Missing info',
      );
      return;
    }

    final details = c.commonDetails.value;
    if (details == null) {
      CustomSnackBar.showInfo('Loading support details...', title: 'Support');
      return;
    }

    final categories = details.categories;
    final priorities = details.priorities;
    if (categories.isEmpty || priorities.isEmpty) {
      CustomSnackBar.showError('Support details are empty', title: 'Support');
      return;
    }

    final resolvedCategoryId =
        categories.any((x) => x.id == _categoryId)
            ? _categoryId
            : categories.first.id;
    final selectedCategory = categories.firstWhere(
      (x) => x.id == resolvedCategoryId,
    );
    final subcats = selectedCategory.subcategories;
    final resolvedSubcategoryId =
        subcats.any((x) => x.id == _subcategoryId)
            ? _subcategoryId
            : (subcats.isNotEmpty ? subcats.first.id : '');
    final resolvedPriorityId =
        priorities.any((x) => x.id == _priority)
            ? _priority
            : priorities.first.id;

    if (resolvedCategoryId.isEmpty ||
        resolvedSubcategoryId.isEmpty ||
        resolvedPriorityId.isEmpty) {
      CustomSnackBar.showError(
        'Please select category, subcategory and priority',
        title: 'Support',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final List<String> urls = <String>[];
      for (final f in _attachments) {
        final u = await c.uploadAttachment(f);
        if (u != null && u.trim().isNotEmpty) urls.add(u.trim());
      }

      final created = await c.createTicket(
        subject: subject,
        description: desc,
        categoryId: resolvedCategoryId,
        subcategoryId: resolvedSubcategoryId,
        priority: resolvedPriorityId,
        bookingId: widget.prefillBookingId,
        attachments: urls,
      );

      if (created == null) {
        final msg = c.error.value.trim();
        if (msg.isNotEmpty) {
          CustomSnackBar.showError(msg, title: 'Support');
        }
        return;
      }

      final msg = c.lastCreateMessage.value.trim();
      if (msg.isNotEmpty) {
        CustomSnackBar.showSuccess(msg, title: 'Support');
      }

      if (!mounted) return;
      navigator.pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Create Support',
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
        child: Obx(() {
          final details = c.commonDetails.value;
          final loading = c.isCommonLoading.value;

          if (details == null && loading) {
            return const Center(
              child: HopprCircularLoader(color: Colors.black),
            );
          }

          if (details == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.commonError.value.isEmpty
                          ? 'Failed to load support details'
                          : c.commonError.value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: c.loadCommonDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.commonBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = details.categories;
          final priorities = details.priorities;

          if (categories.isEmpty || priorities.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Support details are empty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF667085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final resolvedCategoryId =
              categories.any((x) => x.id == _categoryId)
                  ? _categoryId
                  : categories.first.id;
          final resolvedPriorityId =
              priorities.any((x) => x.id == _priority)
                  ? _priority
                  : priorities.first.id;

          final selectedCategory = categories.firstWhere(
            (x) => x.id == resolvedCategoryId,
          );
          final subcats = selectedCategory.subcategories;
          final resolvedSubcategoryId =
              subcats.any((x) => x.id == _subcategoryId)
                  ? _subcategoryId
                  : (subcats.isNotEmpty ? subcats.first.id : '');

          if (resolvedCategoryId != _categoryId ||
              resolvedSubcategoryId != _subcategoryId ||
              resolvedPriorityId != _priority) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _categoryId = resolvedCategoryId;
                _subcategoryId = resolvedSubcategoryId;
                _priority = resolvedPriorityId;
              });
            });
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subject',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _subject,
                      decoration: _fieldDecoration(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _desc,
                      minLines: 6,
                      maxLines: 10,
                      decoration: _fieldDecoration(),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _categoryId.isEmpty
                                  ? (categories.isNotEmpty
                                      ? categories.first.id
                                      : null)
                                  : _categoryId,
                          isExpanded: true,
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(
                                    cat.label.isEmpty ? cat.id : cat.label,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v == null) return;
                            final cat = categories.firstWhere((x) => x.id == v);
                            setState(() {
                              _categoryId = v;
                              _subcategoryId =
                                  cat.subcategories.isNotEmpty
                                      ? cat.subcategories.first.id
                                      : '';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Subcategory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _subcategoryId.isEmpty
                                  ? (subcats.isNotEmpty
                                      ? subcats.first.id
                                      : null)
                                  : _subcategoryId,
                          isExpanded: true,
                          items: subcats
                              .map(
                                (sc) => DropdownMenuItem(
                                  value: sc.id,
                                  child: Text(
                                    sc.label.isEmpty ? sc.id : sc.label,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _subcategoryId = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _priority.isEmpty
                                  ? (priorities.isNotEmpty
                                      ? priorities.first.id
                                      : null)
                                  : _priority,
                          isExpanded: true,
                          items: priorities
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.label.isEmpty ? p.id : p.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _priority = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _showPickSheet,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Color(0xFF98A2B3),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Upload Image',
                              style: TextStyle(
                                color: Color(0xFF98A2B3),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(_attachments.length, (i) {
                          final f = _attachments[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  f,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: InkWell(
                                  onTap:
                                      () => setState(
                                        () => _attachments.removeAt(i),
                                      ),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _create,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.commonBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _submitting
                              ? const HopprCircularLoader(
                                radius: 11,
                                size: 22,
                                color: Colors.white,
                              )
                              : const Text(
                                'Create Ticket',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
