import 'package:flutter/material.dart';

/// A widget that displays the "About This Event" section with expandable text
/// and a clean, minimalist design.
class EventAboutSection extends StatefulWidget {
  final String description;
  final int maxLines;
  
  const EventAboutSection({
    Key? key,
    required this.description,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  State<EventAboutSection> createState() => _EventAboutSectionState();
}

class _EventAboutSectionState extends State<EventAboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with rounded icon container beside text
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
                  Icons.description_outlined,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'About This Event',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Description text with read more functionality
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.description,
                style: theme.textTheme.bodyMedium,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(
                widget.description,
                style: theme.textTheme.bodyMedium,
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            
            if (widget.description.split('\n').length > widget.maxLines || 
                widget.description.length > widget.maxLines * 50) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Read less' : 'Read more',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
