import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/event_participant_controller.dart';
import '../models/event_participant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/app_bar.dart';
import '../../../shared/widgets/avatar.dart'; // Import Avatar widget
import '../../../shared/widgets/skeleton_loader.dart'; // Import skeleton loader

class EventParticipantsScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventParticipantsScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EventParticipantsScreen> createState() => _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends ConsumerState<EventParticipantsScreen> {
  final TextEditingController _searchController = TextEditingController();
  ParticipantRole? _selectedRole;
  List<EventParticipant> _filteredParticipants = [];
  
  // Remove the _isInitialized flag since we'll use the provider's state directly
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Trigger participant loading immediately, but don't wait for it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventParticipantControllerProvider.notifier).loadParticipants(widget.eventId);
    });
  }

  void _onSearchChanged() {
    // Filter participants whenever search text changes
    _filterParticipants();
  }

  void _filterParticipants() {
    final participantsAsync = ref.read(eventParticipantControllerProvider);
    
    if (!participantsAsync.hasValue) {
      setState(() {
        _filteredParticipants = [];
      });
      return;
    }

    var filtered = participantsAsync.value!;

    // Apply role filter
    if (_selectedRole != null) {
      filtered = filtered.where((p) => p.role == _selectedRole).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final fullName = p.fullName?.toLowerCase() ?? '';
        final username = p.username?.toLowerCase() ?? '';
        return fullName.contains(searchQuery) || username.contains(searchQuery);
      }).toList();
    }

    setState(() {
      _filteredParticipants = filtered;
    });
  }

  bool _canManageParticipant(EventParticipant participant) {
    // Rest of the method remains unchanged
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return false;

    // Get all participants
    final participantsAsync = ref.watch(eventParticipantControllerProvider);
    
    // Return false if participants are still loading or have error
    if (!participantsAsync.hasValue) return false;
    
    // Find current user's participant record
    final currentUserParticipant = participantsAsync.value!.firstWhere(
      (p) => p.userId == currentUser.id,
      orElse: () => participant,
    );

    // Can manage if:
    // 1. Current user is an organizer
    // 2. Target is not themselves
    // 3. Target is not another organizer
    return currentUserParticipant.role == ParticipantRole.organizer &&
           currentUser.id != participant.userId &&
           participant.role != ParticipantRole.organizer;
  }

  void _showParticipantOptions(EventParticipant participant) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Avatar(
                url: participant.avatarUrl,
                size: 40,
                name: participant.fullName ?? participant.username,
                userId: participant.userId,
              ),
              title: Text(
                participant.fullName ?? participant.username ?? 'Unknown',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '@${participant.username ?? ''}',
                style: TextStyle(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: isDark ? Colors.white : Colors.black87,
              ),
              title: Text(
                'Change Role',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRoleChangeDialog(participant);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Remove from Event',
                style: TextStyle(
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRemoveConfirmation(participant);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRoleChangeDialog(EventParticipant participant) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Change Role',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a new role for ${participant.fullName ?? participant.username}',
              style: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ...ParticipantRole.values.map((role) {
              if (role == participant.role) return const SizedBox.shrink();
              
              return ListTile(
                leading: Icon(
                  _getRoleIcon(role),
                  color: isDark ? Colors.white : Colors.black87,
                ),
                title: Text(
                  role.name[0].toUpperCase() + role.name.substring(1),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _changeParticipantRole(participant, role);
                },
              );
            }).where((widget) => widget is ListTile).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(EventParticipant participant) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Remove Participant',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${participant.fullName ?? participant.username} from this event?',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeParticipant(participant);
            },
            child: Text(
              'Remove',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeParticipantRole(
    EventParticipant participant,
    ParticipantRole newRole,
  ) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await ref.read(eventParticipantControllerProvider.notifier).changeRole(
            widget.eventId,
            currentUser.id,
            participant.userId,
            newRole,
          );
    }
  }

  Future<void> _removeParticipant(EventParticipant participant) async {
    await ref
        .read(eventParticipantControllerProvider.notifier)
        .leaveEvent(widget.eventId, participant.userId);
  }

  Widget _buildEmptyState(BuildContext context, {required bool hasParticipants}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasParticipants ? Icons.search_off : Icons.group_off,
            size: 64,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            hasParticipants
                ? 'No participants match your filters'
                : 'No participants yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          if (!hasParticipants) ...[
            const SizedBox(height: 8),
            Text(
              'Invite people to join this event!',
              style: TextStyle(
                fontSize: 14,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantCard(EventParticipant participant) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canManage = _canManageParticipant(participant);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: InkWell(
        onTap: canManage ? () => _showParticipantOptions(participant) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Avatar(
                url: participant.avatarUrl,
                size: 40,
                name: participant.fullName ?? participant.username,
                userId: participant.userId,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.fullName ?? participant.username ?? 'Unknown',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canManage) ...[
                          Icon(
                            Icons.chevron_right,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '@${participant.username ?? ''}',
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getRoleIcon(participant.role),
                                size: 14,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                participant.role.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.attendee:
        return Icons.person;
      case ParticipantRole.organizer:
        return Icons.admin_panel_settings;
      case ParticipantRole.speaker:
        return Icons.record_voice_over;
      case ParticipantRole.volunteer:
        return Icons.volunteer_activism;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Watch participants data
    final participantsAsync = ref.watch(eventParticipantControllerProvider);
    
    // Use this to detect changes and filter participants
    ref.listen(eventParticipantControllerProvider, (previous, next) {
      if (next.hasValue && mounted) {
        _filterParticipants();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: SCompassAppBar(
        title: 'Participants',
        centerTitle: false,
        showBackButton: true,
        backgroundColor: isDark ? Colors.black : Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Search participants...',
                hintStyle: TextStyle(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark 
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[100],
              ),
            ),
          ),
          
          // Role filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedRole == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRole = null;
                      _filterParticipants();
                    });
                  },
                  backgroundColor: isDark 
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white,
                  selectedColor: isDark 
                      ? Colors.white
                      : Colors.black,
                  checkmarkColor: isDark 
                      ? Colors.black
                      : Colors.white,
                  labelStyle: TextStyle(
                    color: _selectedRole == null
                        ? (isDark ? Colors.black : Colors.white) // Selected text color
                        : (isDark ? Colors.white : Colors.black), // Unselected text color
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...ParticipantRole.values.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(role.name[0].toUpperCase() + role.name.substring(1)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRole = selected ? role : null;
                          _filterParticipants();
                        });
                      },
                      backgroundColor: isDark 
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      selectedColor: isDark 
                          ? Colors.white
                          : Colors.black,
                      checkmarkColor: isDark 
                          ? Colors.black
                          : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white) // Selected text color
                            : (isDark ? Colors.white : Colors.black), // Unselected text color
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isDark 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Participant list with optimized loading
          Expanded(
            child: participantsAsync.when(
              data: (_) => _filteredParticipants.isEmpty
                  ? _buildEmptyState(context, hasParticipants: participantsAsync.value!.isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _filteredParticipants.length,
                      itemBuilder: (context, index) {
                        return _buildParticipantCard(_filteredParticipants[index]);
                      },
                    ),
              loading: () => _buildLoadingState(),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading participants',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(eventParticipantControllerProvider.notifier)
                          .loadParticipants(widget.eventId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method - builds skeleton loading UI
  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5, // Show 5 skeleton items
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name skeleton
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Username skeleton
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              // Role badge skeleton
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
