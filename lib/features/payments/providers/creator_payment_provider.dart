import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/creator_payment_repository.dart';
import '../models/creator_payment_settings.dart';

// Provider for the repository
final creatorPaymentRepositoryProvider = Provider<CreatorPaymentRepository>((ref) {
  return CreatorPaymentRepository();
});

// Provider for creator payment settings
final creatorPaymentSettingsProvider = FutureProvider.family<CreatorPaymentSettings?, String>((ref, userId) async {
  final repository = ref.read(creatorPaymentRepositoryProvider);
  return await repository.getCreatorPaymentSettings(userId);
});

// Provider to check if the creator has valid payment settings
final hasValidPaymentSettingsProvider = FutureProvider.family<bool, String>((ref, userId) async {
  final settings = await ref.watch(creatorPaymentSettingsProvider(userId).future);
  return settings != null && settings.isValid;
});

// Notifier to handle saving/updating payment settings
class CreatorPaymentSettingsNotifier extends StateNotifier<AsyncValue<CreatorPaymentSettings?>> {
  final CreatorPaymentRepository _repository;
  final String _userId;

  CreatorPaymentSettingsNotifier(this._repository, this._userId)
      : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repository.getCreatorPaymentSettings(_userId);
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<bool> saveUpiDetails(String upiId) async {
    state = const AsyncValue.loading();
    try {
      final existingSettings = await _repository.getCreatorPaymentSettings(_userId);
      final settings = await _repository.saveCreatorPaymentSettings(
        userId: _userId,
        existingId: existingSettings?.id,
        upiId: upiId,
      );

      if (settings != null) {
        state = AsyncValue.data(settings);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> deleteSettings() async {
    try {
      final existingSettings = state.valueOrNull;
      if (existingSettings != null) {
        final success = await _repository.deleteCreatorPaymentSettings(existingSettings.id);
        if (success) {
          state = const AsyncValue.data(null);
          return true;
        }
      }
      return false;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
}

// Provider for the notifier
final creatorPaymentSettingsNotifierProvider = StateNotifierProvider.family<
    CreatorPaymentSettingsNotifier, AsyncValue<CreatorPaymentSettings?>, String>((ref, userId) {
  final repository = ref.read(creatorPaymentRepositoryProvider);
  return CreatorPaymentSettingsNotifier(repository, userId);
});
