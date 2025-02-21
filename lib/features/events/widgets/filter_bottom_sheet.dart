import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/event_controller.dart';
import 'package:intl/intl.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  final String? initialCategory;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final double? initialMaxPrice;
  final bool initialOnlyFreeEvents;
  final Function({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    double? maxPrice,
    bool? onlyFreeEvents,
  }) onApplyFilters;

  const FilterBottomSheet({
    Key? key,
    this.initialCategory,
    this.initialStartDate,
    this.initialEndDate,
    this.initialMaxPrice,
    this.initialOnlyFreeEvents = false,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> with SingleTickerProviderStateMixin {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _selectedCategory;
  late double? _maxPrice;
  late bool _onlyFreeEvents;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> _categories = [
    'Water activities',
    'Sports',
    'Art',
    'Food',
    'Academic',
    'Trekking',
    'Cultural',
    'Biking',
    'Social',
    'Wild life',
    'Adventure activities',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedCategory = widget.initialCategory;
    _maxPrice = widget.initialMaxPrice;
    _onlyFreeEvents = widget.initialOnlyFreeEvents;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _animation,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar with animation
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(_animation),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    // Header with animation
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.5),
                        end: Offset.zero,
                      ).animate(_animation),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Events',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date Range Section with new UI
                    _buildSectionHeader('Date Range', Icons.calendar_today),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildDateRow(
                              'Start Date',
                              _startDate,
                              () => _selectDate(true),
                              theme,
                              Icons.calendar_today_outlined,
                            ),
                            const SizedBox(height: 16),
                            _buildDateRow(
                              'End Date',
                              _endDate,
                              () => _selectDate(false),
                              theme,
                              Icons.event_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Section with improved UI
                    _buildSectionHeader('Category', Icons.category),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            showCheckmark: true,
                            checkmarkColor: theme.colorScheme.onPrimary,
                            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedCategory = selected ? category : null);
                            },
                            elevation: isSelected ? 2 : 0,
                            pressElevation: 4,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Price Section with improved UI
                    _buildSectionHeader('Price', Icons.attach_money),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: Text(
                                'Show only free events',
                                style: theme.textTheme.titleSmall,
                              ),
                              value: _onlyFreeEvents,
                              onChanged: (value) => setState(() => _onlyFreeEvents = value),
                              contentPadding: EdgeInsets.zero,
                              secondary: Icon(
                                _onlyFreeEvents ? Icons.check_circle : Icons.money_off,
                                color: _onlyFreeEvents
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!_onlyFreeEvents) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Maximum price',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '₹${_maxPrice?.toStringAsFixed(0) ?? 'Any'}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
                                  thumbColor: theme.colorScheme.primary,
                                  overlayColor: theme.colorScheme.primary.withOpacity(0.1),
                                ),
                                child: Slider(
                                  value: _maxPrice ?? 5000,
                                  min: 0,
                                  max: 5000,
                                  divisions: 50,
                                  label: '₹${_maxPrice?.toStringAsFixed(0) ?? 'Any'}',
                                  onChanged: (value) => setState(() => _maxPrice = value),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Apply Button with animation
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(_animation),
                      child: FilledButton(
                        onPressed: _applyFilters,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(
    String label,
    DateTime? date,
    VoidCallback onTap,
    ThemeData theme,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: date != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date == null ? 'Select date' : _formatDate(date),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: date == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      fontWeight: date != null ? FontWeight.w500 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedCategory = null;
      _maxPrice = null;
      _onlyFreeEvents = false;
    });
    
    // Call onApplyFilters with all null values to reset the parent's state
    widget.onApplyFilters(
      category: null,
      startDate: null,
      endDate: null,
      maxPrice: null,
      onlyFreeEvents: false,
    );
  }

  void _applyFilters() {
    widget.onApplyFilters(
      category: _selectedCategory,
      startDate: _startDate,
      endDate: _endDate,
      maxPrice: _maxPrice,
      onlyFreeEvents: _onlyFreeEvents,
    );
    Navigator.pop(context);
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = null;
          }
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}
