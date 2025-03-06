import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../../payments/providers/payment_provider.dart';

final eventSearchQueryProvider = StateProvider<String>((ref) => '');

// Create a provider to handle payment status check
final eventPaymentStatusProvider = Provider.family<bool, String>((ref, eventId) {
  final paymentsAsync = ref.watch(paymentProvider);
  return paymentsAsync.when(
    data: (payments) => payments.any((payment) => 
      payment.eventId == eventId && payment.status == 'success'
    ),
    loading: () => false,
    error: (_, __) => false,
  );
});

final filteredEventsProvider = Provider.family<List<Event>, List<Event>>((ref, events) {
  final query = ref.watch(eventSearchQueryProvider).toLowerCase();
  
  if (query.isEmpty) return events;
  
  return events.where((event) {
    final title = event.title.toLowerCase();
    final description = event.description?.toLowerCase() ?? '';
    final location = event.location?.toLowerCase() ?? '';
    final category = event.category?.toLowerCase() ?? '';
    final tags = event.tags.map((tag) => tag.toLowerCase()).join(' ');
    
    return title.contains(query) || 
           description.contains(query) || 
           location.contains(query) ||
           category.contains(query) ||
           tags.contains(query);
  }).toList();
});
