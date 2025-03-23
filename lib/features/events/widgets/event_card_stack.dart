import 'package:flutter/material.dart';
import '../models/event_model.dart';
import 'swipeable_event_card.dart';
// import 'event_card_ad.dart'; // Ad functionality temporarily disabled
import 'package:flutter/foundation.dart' show kIsWeb;

class EventCardStack extends StatefulWidget {
  final List<Event> events;
  final Function(Event, bool) onSwipe;
  final Function(Event) onTap;
  final VoidCallback onStackEmpty;

  const EventCardStack({
    Key? key,
    required this.events,
    required this.onSwipe,
    required this.onTap,
    required this.onStackEmpty,
  }) : super(key: key);

  @override
  State<EventCardStack> createState() => _EventCardStackState();
}

class _EventCardStackState extends State<EventCardStack> {
  static const int _stackCount = 3;
  late List<Event> _events;
  final List<_SwipeHistory> _swipeHistory = [];
  bool _canUndo = false;
  // bool _showAdCard = false; // Ad functionality temporarily disabled
  int _cardsSwipedCount = 0;

  @override
  void initState() {
    super.initState();
    _events = List.from(widget.events);
  }

  @override
  void didUpdateWidget(EventCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events != oldWidget.events) {
      setState(() {
        _events = List.from(widget.events);
        _swipeHistory.clear();
        _canUndo = false;
        // _showAdCard = false; // Ad functionality temporarily disabled
        _cardsSwipedCount = 0;
      });
    }
  }

  void _onSwipe(bool isRight, Event event) {
    setState(() {
      _events.remove(event);
      _swipeHistory.add(_SwipeHistory(event: event, isRight: isRight));
      _canUndo = true;
      _cardsSwipedCount++;
      
      // Show an ad after every 3 cards are swiped (only on mobile)
      // Ad functionality temporarily disabled
      /*
      if (!kIsWeb && _cardsSwipedCount % 3 == 0 && _events.isNotEmpty) {
        _showAdCard = true;
      } else {
        _showAdCard = false;
      }
      */
      
      if (_events.isEmpty) {
        widget.onStackEmpty();
      }
    });
    widget.onSwipe(event, isRight);
  }

  void _undoLastSwipe() {
    if (_swipeHistory.isEmpty || !_canUndo) return;

    final lastSwipe = _swipeHistory.removeLast();
    setState(() {
      _events.insert(0, lastSwipe.event);
      _canUndo = _swipeHistory.isNotEmpty;
      _cardsSwipedCount--;
      // _showAdCard = !kIsWeb && _cardsSwipedCount > 0 && _cardsSwipedCount % 3 == 0; // Ad functionality temporarily disabled
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No more events',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull to refresh or check back later',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                if (_canUndo) ...[
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _undoLastSwipe,
                    icon: const Icon(Icons.undo, color: Colors.red),
                    label: const Text(
                      'Undo last swipe',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return Stack(
          children: [
            SizedBox.expand(
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  // Show regular event cards
                  ..._events.take(_stackCount).map((event) {
                    final index = _events.indexOf(event);
                    
                    final scale = 1.0 - (index * 0.02);
                    final verticalOffset = index * 2.0;

                    return Positioned(
                      top: verticalOffset,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4), // Small bottom margin for cards
                        child: Transform.scale(
                          scale: scale,
                          child: SwipeableEventCard(
                            key: ValueKey(event.id),
                            event: event,
                            onSwipe: (isRight) => _onSwipe(isRight, event),
                            onTap: () => widget.onTap(event),
                          ),
                        ),
                      ),
                    );
                  }).toList().reversed.toList(),
                ],
              ),
            ),
            if (_canUndo)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  heroTag: 'undo_button',
                  mini: true,
                  onPressed: _undoLastSwipe,
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.undo),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SwipeHistory {
  final Event event;
  final bool isRight;

  _SwipeHistory({required this.event, required this.isRight});
}
