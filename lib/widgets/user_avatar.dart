import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable circular avatar widget with fallback icon
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.showBorder = false,
    this.borderColor = const Color(0xFF1877F2),
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(imageUrl!)
          : null,
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Icon(Icons.person, color: Colors.white, size: radius)
          : null,
    );

    if (showBorder) {
      return Container(
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
