import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EventCreationStep {
  basicInfo,
  contactDetails,
  media,
  dateTime,
  locationDetails,
}

class EventWizardState {
  final EventCreationStep currentStep;
  final bool canProceed;
  final Map<EventCreationStep, bool> stepValidation;
  final Map<String, dynamic> formData;

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
  }) : stepValidation = stepValidation ?? {
          for (var step in EventCreationStep.values) step: false,
        },
       formData = formData ?? {};

  EventWizardState copyWith({
    EventCreationStep? currentStep,
    bool? canProceed,
    Map<EventCreationStep, bool>? stepValidation,
    Map<String, dynamic>? formData,
  }) {
    return EventWizardState(
      currentStep: currentStep ?? this.currentStep,
      canProceed: canProceed ?? this.canProceed,
      stepValidation: stepValidation ?? Map.from(this.stepValidation),
      formData: formData ?? Map.from(this.formData),
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
    state = state.copyWith(stepValidation: updatedValidation);
  }

  void updateFormData(Map<String, dynamic> data) {
    if (!mounted) return;
    final updatedFormData = Map<String, dynamic>.from(state.formData)..addAll(data);
    state = state.copyWith(formData: updatedFormData);
  }

  bool canGoToStep(EventCreationStep targetStep) {
    final targetIndex = EventCreationStep.values.indexOf(targetStep);
    final currentIndex = EventCreationStep.values.indexOf(state.currentStep);
    
    // Can always go back
    if (targetIndex < currentIndex) return true;
    
    // Check if all previous steps are valid
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
}

final eventWizardProvider =
    StateNotifierProvider<EventWizardController, EventWizardState>((ref) {
  return EventWizardController();
});
