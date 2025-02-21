import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const Avatar({
    super.key,
    this.url,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: url != null
          ? ClipOval(
              child: Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person,
                  size: size * 0.6,
                  color: Colors.grey[400],
                ),
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: Colors.grey[400],
            ),
    );
  }
}
