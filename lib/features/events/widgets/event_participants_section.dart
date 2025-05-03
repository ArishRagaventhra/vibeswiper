import 'package:flutter/material.dart';
import 'package:scompass_07/shared/widgets/avatar.dart';
import '../models/event_participant_model.dart';

class EventParticipantsSection extends StatelessWidget {
  final List<EventParticipant> participants;
  final VoidCallback onSeeAll;
  final int maxDisplayed;

  const EventParticipantsSection({
    Key? key,
    required this.participants,
    required this.onSeeAll,
    this.maxDisplayed = 3,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedParticipants = participants.take(maxDisplayed).toList();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Rounded container for icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.people_outline,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Participants',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              // See All button
              TextButton(
                onPressed: onSeeAll,
                child: Text(
                  'See All',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Participants avatars
          SizedBox(
            height: 48,
            child: Row(
              children: [
                // Display avatar images
                for (var i = 0; i < displayedParticipants.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Avatar(
                    url: displayedParticipants[i].avatarUrl,
                    size: 48,
                    name: displayedParticipants[i].fullName,
                    userId: displayedParticipants[i].userId,
                  ),
                ],
                
                // Show additional count if there are more participants
                if (participants.length > maxDisplayed) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '+${participants.length - maxDisplayed}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
