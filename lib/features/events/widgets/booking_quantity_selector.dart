import 'package:flutter/material.dart';

class BookingQuantitySelector extends StatelessWidget {
  final int quantity;
  final Function(int) onChanged;
  final int minQuantity;
  final int maxQuantity;

  const BookingQuantitySelector({
    Key? key,
    required this.quantity,
    required this.onChanged,
    this.minQuantity = 1,
    this.maxQuantity = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Minus button
        _QuantityButton(
          icon: Icons.remove,
          onPressed: quantity > minQuantity 
              ? () => onChanged(quantity - 1)
              : null,
          isDark: isDark,
        ),
        
        // Quantity display
        Container(
          width: 80,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.grey[800]!.withOpacity(0.5)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$quantity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        
        // Plus button
        _QuantityButton(
          icon: Icons.add,
          onPressed: quantity < maxQuantity 
              ? () => onChanged(quantity + 1)
              : null,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;

  const _QuantityButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: onPressed == null
                ? (isDark ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[200]!.withOpacity(0.5))
                : (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: onPressed == null
                ? (isDark ? Colors.grey[600] : Colors.grey[400])
                : (isDark ? Colors.white70 : Colors.black87),
            size: 20,
          ),
        ),
      ),
    );
  }
}
