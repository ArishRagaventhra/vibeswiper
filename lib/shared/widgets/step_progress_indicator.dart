import 'package:flutter/material.dart';

class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;
  final Function(int) onStepTapped;
  final bool Function(int) canTapStep;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    required this.onStepTapped,
    required this.canTapStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Row(
              children: List.generate(totalSteps, (index) {
                final isActive = index == currentStep;
                final isCompleted = index < currentStep;
                final canTap = canTapStep(index);
                
                return Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (index < totalSteps - 1)
                        Positioned(
                          left: 50,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  isCompleted
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceVariant,
                                  index + 1 < currentStep
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceVariant,
                                ],
                              ),
                            ),
                          ),
                        ),
                      InkWell(
                        onTap: canTap ? () => onStepTapped(index) : null,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted || isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            border: Border.all(
                              color: isCompleted || isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.2),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Center(
                            child: isCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onPrimary,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: isActive
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(totalSteps, (index) {
              final isActive = index == currentStep;
              final isCompleted = index < currentStep;
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    stepTitles[index],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive || isCompleted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
