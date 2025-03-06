import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/edge_to_edge_container.dart';
import '../models/event_response_model.dart';
import '../repositories/event_response_repository.dart';
import '../repositories/event_requirements_repository.dart';
import '../providers/event_response_providers.dart';
import '../utils/response_export_util.dart';
import 'package:go_router/go_router.dart';

class EventResponsesDashboard extends ConsumerStatefulWidget {
  final String eventId;

  const EventResponsesDashboard({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventResponsesDashboard> createState() => _EventResponsesDashboardState();
}

class _EventResponsesDashboardState extends ConsumerState<EventResponsesDashboard> {
  bool _isLoading = false;
  String? _error;
  Map<String, List<EventQuestionResponse>> _userResponses = {};
  Map<String, Map<String, dynamic>> _userProfiles = {};
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load questions
      final requirementsRepo = ref.read(eventRequirementsRepositoryProvider);
      _questions = (await requirementsRepo.getEventCustomQuestions(widget.eventId))
          .map((q) => q as Map<String, dynamic>)
          .toList();

      // Load responses
      final responseRepo = ref.read(eventResponseRepositoryProvider);
      final responses = await responseRepo.getEventResponses(widget.eventId);
      
      // Group responses by user
      final Map<String, List<EventQuestionResponse>> userResponses = {};
      for (var response in responses) {
        if (!userResponses.containsKey(response.userId)) {
          userResponses[response.userId] = [];
        }
        userResponses[response.userId]!.add(response);
      }

      // Load user profiles
      final Map<String, Map<String, dynamic>> userProfiles = {};
      for (var userId in userResponses.keys) {
        final profile = await ref.read(userProfileProvider(userId).future);
        if (profile != null) {
          userProfiles[userId] = profile;
        }
      }

      setState(() {
        _userResponses = userResponses;
        _userProfiles = userProfiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportResponses() async {
    try {
      setState(() => _isLoading = true);

      // Request permission and handle denial
      if (!kIsWeb && Platform.isAndroid) {
        final hasPermission = await ResponseExportUtil.requestStoragePermission();
        if (!hasPermission) {
          if (!mounted) return;
          
          // Show settings dialog if permission is denied
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Storage permission is required to export responses. '
                'Please enable it in app settings.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('OPEN SETTINGS'),
                ),
              ],
            ),
          );

          if (openSettings ?? false) {
            await openAppSettings();
          }
          return;
        }
      }

      // Convert responses to export format
      final exportData = <Map<String, String>>[];
      final headerRow = <String, String>{
        'Name': 'Name',
        ...Map.fromEntries(_questions.map((q) => 
          MapEntry(q['question_text'].toString(), q['question_text'].toString())
        )),
      };
      exportData.add(headerRow);

      // Add data rows
      for (var userId in _userResponses.keys) {
        final responses = _userResponses[userId]!;
        final profile = _userProfiles[userId];
        
        final row = <String, String>{
          'Name': profile?['full_name']?.toString() ?? profile?['username']?.toString() ?? 'Unknown User',
        };

        for (var question in _questions) {
          final questionText = question['question_text'].toString();
          final response = responses.firstWhere(
            (r) => r.questionId == question['id'],
            orElse: () => EventQuestionResponse(
              id: 'temp_${userId}_${question['id']}',
              userId: userId,
              questionId: question['id'],
              responseText: '',
              eventId: widget.eventId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          row[questionText] = response.responseText;
        }
        exportData.add(row);
      }

      final result = await ResponseExportUtil.exportToExcel(
        headers: headerRow.values.toList(),
        rows: exportData.skip(1).map((row) => 
          headerRow.keys.map((key) => row[key] ?? '').toList()
        ).toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb 
            ? 'File downloaded successfully'
            : 'File saved to: $result'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: !kIsWeb ? SnackBarAction(
            label: 'SHOW',
            textColor: Colors.white,
            onPressed: () async {
              if (Platform.isAndroid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File location: $result'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ) : null,
        ),
      );
    } catch (e) {
      debugPrint('Error exporting responses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export responses: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildResponseCard(BuildContext context, String userId) {
    final responses = _userResponses[userId]!;
    final profile = _userProfiles[userId];
    final userName = profile?['full_name']?.toString() ?? profile?['username']?.toString() ?? 'Unknown User';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          userName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${responses.length} responses',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _questions.map((question) {
                final response = responses.firstWhere(
                  (r) => r.questionId == question['id'],
                  orElse: () => EventQuestionResponse(
                    id: 'temp_${userId}_${question['id']}',
                    userId: userId,
                    questionId: question['id'],
                    responseText: '',
                    eventId: widget.eventId,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question['question_text'].toString(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          response.responseText.isEmpty ? 'No response' : response.responseText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: response.responseText.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Participant Responses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(
                Icons.download,
                color: Theme.of(context).colorScheme.onBackground,
              ),
              onPressed: _exportResponses,
              tooltip: 'Export Responses',
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      body: EdgeToEdgeContainer(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            : _userResponses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No responses yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Responses will appear here once participants submit them',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: _userResponses.length,
                  itemBuilder: (context, index) {
                    final userId = _userResponses.keys.elementAt(index);
                    return _buildResponseCard(context, userId);
                  },
                ),
      ),
    );
  }
}
