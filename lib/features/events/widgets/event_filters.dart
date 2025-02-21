import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../../../config/theme.dart';

class GradientChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;

  const GradientChip({
    Key? key,
    required this.label,
    required this.selected,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryGradientStart,
                      AppTheme.primaryGradientEnd,
                    ],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            border: Border.all(
              color: selected 
                  ? Colors.transparent 
                  : Theme.of(context).colorScheme.outline.withOpacity(0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class EventFilters extends StatelessWidget {
  final EventStatus? selectedStatus;
  final String? selectedCategory;
  final EventSortOption selectedSort;
  final List<String> categories;
  final Function(EventStatus?) onStatusChanged;
  final Function(String?) onCategoryChanged;
  final Function(EventSortOption) onSortChanged;

  const EventFilters({
    Key? key,
    this.selectedStatus,
    this.selectedCategory,
    required this.selectedSort,
    required this.categories,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Events',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Status Filter
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GradientChip(
                    label: 'All',
                    selected: selectedStatus == null,
                    onSelected: (selected) {
                      if (selected) onStatusChanged(null);
                    },
                  ),
                  ...EventStatus.values
                      .where((status) => status != EventStatus.draft) // Exclude draft status from filters
                      .map(
                    (status) => GradientChip(
                      label: status.name,
                      selected: selectedStatus == status,
                      onSelected: (selected) {
                        onStatusChanged(selected ? status : null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Category Filter
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GradientChip(
                    label: 'All',
                    selected: selectedCategory == null,
                    onSelected: (selected) {
                      if (selected) onCategoryChanged(null);
                    },
                  ),
                  ...categories.map(
                    (category) => GradientChip(
                      label: category,
                      selected: selectedCategory == category,
                      onSelected: (selected) {
                        onCategoryChanged(selected ? category : null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sort Options
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EventSortOption.values.map(
                  (sort) => GradientChip(
                    label: sort.label,
                    selected: selectedSort == sort,
                    onSelected: (selected) {
                      if (selected) onSortChanged(sort);
                    },
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

enum EventSortOption {
  dateAsc('Date (Oldest First)'),
  dateDesc('Date (Newest First)'),
  titleAsc('Title (A-Z)'),
  titleDesc('Title (Z-A)');

  final String label;
  const EventSortOption(this.label);
}
