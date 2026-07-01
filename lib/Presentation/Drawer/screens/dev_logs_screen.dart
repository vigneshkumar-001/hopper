import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopper/Core/Services/logger_service.dart';
import 'package:hopper/Core/Constants/Colors.dart';
import 'package:hopper/Presentation/Authentication/widgets/textfields.dart';
import 'package:hopper/Core/Utility/images.dart';

class DevLogsScreen extends StatefulWidget {
  const DevLogsScreen({Key? key}) : super(key: key);

  @override
  State<DevLogsScreen> createState() => _DevLogsScreenState();
}

class _DevLogsScreenState extends State<DevLogsScreen> {
  final LoggerService _loggerService = LoggerService();
  late Future<String> _logsFuture;
  late Future<String> _logSizeFuture;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    _logsFuture = _loggerService.getLogsContent();
    _logSizeFuture = _loggerService.getLogSize();
  }

  Future<void> _exportLogs() async {
    try {
      final file = await _loggerService.exportLogs();
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hopper Driver - Development Logs',
      );
    } catch (e) {
      _showSnackBar('Failed to export logs: $e', isError: true);
    }
  }

  Future<void> _clearLogs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _loggerService.clearLogs();
              setState(() => _refreshLogs());
              _showSnackBar('Logs cleared successfully');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    final logs = await _logsFuture;
    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) {
      _showSnackBar('Logs copied to clipboard');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Image.asset(
              AppImages.backButton,
              height: 19,
              width: 19,
            ),
          ),
        ),
        centerTitle: true,
        title: CustomTextfield.textWithStyles700(
          'Developer Logs',
          fontSize: 18,
          color: Colors.black,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header with info and action buttons
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Log size info
                  FutureBuilder<String>(
                    future: _logSizeFuture,
                    builder: (context, snapshot) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextfield.textWithStyles600(
                                'Log File Size',
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              CustomTextfield.textWithStyles700(
                                snapshot.data ?? '0 B',
                                fontSize: 16,
                              ),
                            ],
                          ),
                          CustomTextfield.textWithStyles600(
                            'Development Only',
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Export',
                          icon: Icons.download,
                          onPressed: _exportLogs,
                          backgroundColor: const Color(0xFF00B050),
                          textColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Copy',
                          icon: Icons.copy,
                          onPressed: _copyToClipboard,
                          backgroundColor: Colors.blue,
                          textColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Clear',
                          icon: Icons.delete_outline,
                          onPressed: _clearLogs,
                          backgroundColor: Colors.red.shade300,
                          textColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Logs content
            Expanded(
              child: FutureBuilder<String>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00B050),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          CustomTextfield.textWithStyles600(
                            'Error loading logs',
                            fontSize: 14,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final logs = snapshot.data ?? 'No logs available';
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        logs,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.greenAccent,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
