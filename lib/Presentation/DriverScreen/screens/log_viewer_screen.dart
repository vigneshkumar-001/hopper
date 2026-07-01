import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopper/Core/Services/log_manager.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({Key? key}) : super(key: key);

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  LogType? selectedType;
  String searchQuery = '';

  List<LogEntry> getFilteredLogs() {
    var logs = logManager.getAllLogs();

    if (selectedType != null) {
      logs = logs.where((e) => e.type == selectedType).toList();
    }

    if (searchQuery.isNotEmpty) {
      logs = logs
          .where((e) =>
              e.event.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (e.bookingId?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false))
          .toList();
    }

    return logs.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Hopper Logs'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (context) => <PopupMenuEntry<void>>[
              PopupMenuItem(
                child: const Text('Export JSON'),
                onTap: () async {
                  final path = await logManager.exportLogsToFile('json');
                  if (path.isNotEmpty) {
                    _showSnackBar('✅ JSON exported\n$path');
                  } else {
                    _showSnackBar('❌ Export failed');
                  }
                },
              ),
              PopupMenuItem(
                child: const Text('Export CSV'),
                onTap: () async {
                  final path = await logManager.exportLogsToFile('csv');
                  if (path.isNotEmpty) {
                    _showSnackBar('✅ CSV exported\n$path');
                  } else {
                    _showSnackBar('❌ Export failed');
                  }
                },
              ),
              PopupMenuItem(
                child: const Text('Export TXT'),
                onTap: () async {
                  final path = await logManager.exportLogsToFile('txt');
                  if (path.isNotEmpty) {
                    _showSnackBar('✅ TXT exported\n$path');
                  } else {
                    _showSnackBar('❌ Export failed');
                  }
                },
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Clear Memory'),
                onTap: () {
                  logManager.clearMemoryLogs();
                  setState(() {});
                  _showSnackBar('🗑️ Memory logs cleared');
                },
              ),
              PopupMenuItem(
                child: const Text('Clear Old Files'),
                onTap: () async {
                  await logManager.clearOldLogFiles();
                  _showSnackBar('🗑️ Old log files cleared');
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(),

          // Filters
          _buildFilterBar(),

          // Log list
          Expanded(
            child: _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final stats = logManager.getLogStats();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildStatChip('Total', logManager.getAllLogs().length, Colors.blue),
            _buildStatChip('API', stats['api'] ?? 0, Colors.green),
            _buildStatChip('Socket', stats['socket'] ?? 0, Colors.orange),
            _buildStatChip('Rider', stats['rider'] ?? 0, Colors.purple),
            _buildStatChip(
              'Errors',
              logManager.getErrorCount(),
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search
          TextField(
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search logs...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 8),
          // Type filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeFilter(null, 'All'),
                for (final type in LogType.values) _buildTypeFilter(type, type.toString().split('.').last),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter(LogType? type, String label) {
    final isSelected = selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) => setState(() => selectedType = v ? type : null),
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.shade600,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLogList() {
    final logs = getFilteredLogs();

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No logs found',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, i) => _buildLogTile(logs[i]),
    );
  }

  Widget _buildLogTile(LogEntry log) {
    final color = _getColorForType(log.type);
    final icon = _getIconForType(log.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.05),
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: color, size: 20),
          title: Text(
            log.event,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          subtitle: Row(
            children: [
              Text(
                '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              if (log.bookingId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.bookingId!,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (log.data != null) ...[
                    const Text('📦 Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        log.data.toString(),
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (log.error != null) ...[
                    const Text('❌ Error:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        log.error!,
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                  if (log.error == null && log.data == null)
                    Text(
                      'No additional data',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(LogType type) {
    switch (type) {
      case LogType.api:
        return Colors.green;
      case LogType.socket:
        return Colors.orange;
      case LogType.rider:
        return Colors.purple;
      case LogType.location:
        return Colors.blue;
      case LogType.error:
        return Colors.red;
      case LogType.warning:
        return Colors.amber;
      case LogType.info:
        return Colors.teal;
    }
  }

  IconData _getIconForType(LogType type) {
    switch (type) {
      case LogType.api:
        return Icons.cloud_upload_outlined;
      case LogType.socket:
        return Icons.hub_outlined;
      case LogType.rider:
        return Icons.person_outline;
      case LogType.location:
        return Icons.location_on_outlined;
      case LogType.error:
        return Icons.error_outline;
      case LogType.warning:
        return Icons.warning_outlined;
      case LogType.info:
        return Icons.info_outlined;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
