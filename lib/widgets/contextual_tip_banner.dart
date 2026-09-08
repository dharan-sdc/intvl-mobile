import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dismissable, non-intrusive contextual discovery banner for in-game features.
///
/// [Why] Follows the Just-In-Time guidance pattern: displays helpful tips at the 
/// exact moment the user is interacting with a feature without blocking the screen.
class ContextualTipBanner extends StatefulWidget {
  final String tipId;
  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onAction;
  final String? actionLabel;

  const ContextualTipBanner({
    super.key,
    required this.tipId,
    required this.title,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    this.accentColor = const Color(0xFFE040FB),
    this.onAction,
    this.actionLabel,
  });

  @override
  State<ContextualTipBanner> createState() => _ContextualTipBannerState();
}

class _ContextualTipBannerState extends State<ContextualTipBanner> with SingleTickerProviderStateMixin {
  bool _isDismissed = true;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _checkDismissedState();
  }

  Future<void> _checkDismissedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool('tip_dismissed_${widget.tipId}') ?? false;
      if (!dismissed && mounted) {
        setState(() => _isDismissed = false);
        _animController.forward();
      }
    } catch (_) {}
  }

  Future<void> _dismissTip() async {
    await _animController.reverse();
    if (mounted) {
      setState(() => _isDismissed = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tip_dismissed_${widget.tipId}', true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Color(0xFF1E1E24),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  if (widget.onAction != null && widget.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: widget.onAction,
                      child: Text(
                        widget.actionLabel!,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Dismiss Button
            InkWell(
              onTap: _dismissTip,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
