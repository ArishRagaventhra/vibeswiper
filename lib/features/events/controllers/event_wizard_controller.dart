import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/events/models/event_location_data.dart';

enum EventCreationStep {
  basicInfo,
  contactDetails,
  media,
  dateTime,
  requirements,
  locationDetails,
}

class EventWizardState {
  final EventCreationStep currentStep;
  final bool canProceed;
  final Map<EventCreationStep, bool> stepValidation;
  final Map<String, dynamic> formData;
  final EventLocationData? locationData;

  bool get isCurrentStepValid => stepValidation[currentStep] ?? false;

  bool get canGoToNextStep {
    final currentIndex = EventCreationStep.values.indexOf(currentStep);
    if (currentIndex >= EventCreationStep.values.length - 1) return false;
    return isCurrentStepValid;
  }

  bool get canGoToPreviousStep {
    final currentIndex = EventCreationStep.values.indexOf(currentStep);
    return currentIndex > 0;
  }

  bool get isLastStep => currentStep == EventCreationStep.values.last;

  EventWizardState({
    this.currentStep = EventCreationStep.basicInfo,
    this.canProceed = false,
    Map<EventCreationStep, bool>? stepValidation,
    Map<String, dynamic>? formData,
    this.locationData,
  }) : stepValidation = stepValidation ?? {
          for (var step in EventCreationStep.values) step: false,
        },
       formData = formData ?? {};

  EventWizardState copyWith({
    EventCreationStep? currentStep,
    bool? canProceed,
    Map<EventCreationStep, bool>? stepValidation,
    Map<String, dynamic>? formData,
    EventLocationData? locationData,
  }) {
    return EventWizardState(
      currentStep: currentStep ?? this.currentStep,
      canProceed: canProceed ?? this.canProceed,
      stepValidation: stepValidation ?? Map.from(this.stepValidation),
      formData: formData ?? Map.from(this.formData),
      locationData: locationData ?? this.locationData,
    );
  }
}

class EventWizardController extends StateNotifier<EventWizardState> {
  EventWizardController() : super(EventWizardState());

  void goToStep(EventCreationStep step) {
    if (mounted) {
      state = state.copyWith(currentStep: step);
    }
  }

  void nextStep() {
    if (!mounted) return;
    final currentIndex = EventCreationStep.values.indexOf(state.currentStep);
    if (currentIndex < EventCreationStep.values.length - 1) {
      state = state.copyWith(
        currentStep: EventCreationStep.values[currentIndex + 1],
      );
    }
  }

  void previousStep() {
    if (!mounted) return;
    final currentIndex = EventCreationStep.values.indexOf(state.currentStep);
    if (currentIndex > 0) {
      state = state.copyWith(
        currentStep: EventCreationStep.values[currentIndex - 1],
      );
    }
  }

  void setStepValidation(EventCreationStep step, bool isValid) {
    if (!mounted) return;
    final updatedValidation = Map<EventCreationStep, bool>.from(state.stepValidation);
    updatedValidation[step] = isValid;
    
    // Update state with new validation
    state = state.copyWith(
      stepValidation: updatedValidation,
      // Also update canProceed if this is the current step
      canProceed: step == state.currentStep ? isValid : state.canProceed,
    );
  }

  void updateFormData(Map<String, dynamic> data) {
    if (!mounted) return;
    final updatedFormData = Map<String, dynamic>.from(state.formData);
    
    // Deep merge the data instead of just adding all
    data.forEach((key, value) {
      updatedFormData[key] = value;
    });
    
    state = state.copyWith(formData: updatedFormData);
  }

  void updateLocationData({
    String? venue,
    String? city,
    String? country,
  }) {
    if (!mounted) return;
    
    final currentLocationData = state.locationData;
    final updatedLocationData = EventLocationData(
      venue: venue ?? currentLocationData?.venue,
      city: city ?? currentLocationData?.city,
      country: country ?? currentLocationData?.country,
    );
    
    state = state.copyWith(
      locationData: updatedLocationData,
    );

    // Update step validation based on location data completeness
    setStepValidation(EventCreationStep.locationDetails, updatedLocationData.isComplete);
  }

  bool canGoToStep(EventCreationStep targetStep) {
    final targetIndex = EventCreationStep.values.indexOf(targetStep);
    final currentIndex = EventCreationStep.values.indexOf(state.currentStep);
    
    // Can always go back
    if (targetIndex < currentIndex) return true;
    
    // Can go to next step if current step is valid
    if (targetIndex == currentIndex + 1) return state.isCurrentStepValid;
    
    // For skipping steps, check if all previous steps are valid
    for (var i = 0; i < targetIndex; i++) {
      if (!(state.stepValidation[EventCreationStep.values[i]] ?? false)) {
        return false;
      }
    }
    return true;
  }

  bool isStepValid(EventCreationStep step) {
    return state.stepValidation[step] ?? false;
  }
  
  // Get form data for a specific key
  dynamic getFormData(String key) {
    return state.formData[key];
  }
}

final eventWizardProvider =
    StateNotifierProvider<EventWizardController, EventWizardState>((ref) {
  return EventWizardController();
});
