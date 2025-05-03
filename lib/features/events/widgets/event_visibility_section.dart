import 'package:flutter/material.dart';
import '../models/event_model.dart';

class EventVisibilitySection extends StatelessWidget {
  final EventVisibility visibility;

  const EventVisibilitySection({
    Key? key,
    required this.visibility,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.visibility_outlined,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Visibility',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Visibility chip and description
          Row(
            children: [
              _buildVisibilityChip(visibility, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getVisibilityDescription(visibility),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildVisibilityChip(EventVisibility visibility, ThemeData theme) {
    Color chipColor;
    String label;
    
    switch (visibility) {
      case EventVisibility.public:
        chipColor = Colors.green;
        label = 'Public';
        break;
      case EventVisibility.private:
        chipColor = Colors.orange;
        label = 'Private';
        break;
      case EventVisibility.unlisted:
        chipColor = Colors.red;
        label = 'Unlisted';
        break;
      default:
        chipColor = Colors.grey;
        label = 'Unknown';
    }
    
    return Chip(
      backgroundColor: chipColor.withOpacity(0.2),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  String _getVisibilityDescription(EventVisibility visibility) {
    switch (visibility) {
      case EventVisibility.public:
        return 'Anyone can view and join this event';
      case EventVisibility.private:
        return 'Only invited users can join this event';
      case EventVisibility.unlisted:
        return 'This event is hidden and only accessible via direct link';
      default:
        return '';
    }
  }
}
