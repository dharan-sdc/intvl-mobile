import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../app_state.dart';

/// High-energy, gamified Celebration Dialog presented when an activity finishes,
/// a closed loop claims territory, or a milestone achievement is unlocked.
/// Styled with a crisp, ultra-premium Light Theme.
class CelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final double distanceMeters;
  final int durationSeconds;
  final double? territoryArea;
  final int xpGained;
  final String? achievementUnlocked;
  final VoidCallback onDismiss;

  const CelebrationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.distanceMeters,
    required this.durationSeconds,
    this.territoryArea,
    this.xpGained = 150,
    this.achievementUnlocked,
    required this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required double distanceMeters,
    required int durationSeconds,
    double? territoryArea,
    int xpGained = 150,
    String? achievementUnlocked,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CelebrationDialog(
        title: title,
        message: message,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        territoryArea: territoryArea,
        xpGained: xpGained,
        achievementUnlocked: achievementUnlocked,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  /// Shows an engaging celebration modal for unlocked/completed achievements.
  static Future<void> showAchievement(
    BuildContext context, {
    required AchievementModel achievement,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AchievementCelebrationDialog(
        achievement: achievement,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  /// Shows an engaging celebration modal for completed daily/weekly missions.
  static Future<void> showMission(
    BuildContext context, {
    required MissionModel mission,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MissionCelebrationDialog(
        mission: mission,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _glowAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeInOut),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showSharePreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Your Victory',
              style: TextStyle(color: Color(0xFF1A202C), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'TRION • ${(widget.distanceMeters / 1000).toStringAsFixed(2)} km conquered!',
              style: const TextStyle(color: Color(0xFF0097A7), fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.share, color: Color(0xFFE040FB), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'I just conquered ${(widget.distanceMeters / 1000).toStringAsFixed(2)} km in TRION and claimed new territory! Join the fitness battle!',
                      style: const TextStyle(color: Color(0xFF2D3748), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('🎉 Victory card copied to clipboard!'),
                    backgroundColor: const Color(0xFFE040FB),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Share Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE040FB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distKm = (widget.distanceMeters / 1000).toStringAsFixed(2);
    final hasTerritory = widget.territoryArea != null && widget.territoryArea! > 0;
    final areaFormatted = hasTerritory ? widget.territoryArea!.toStringAsFixed(0) : '0';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Animated Confetti Particles Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (ctx, child) {
                return CustomPaint(
                  painter: _ConfettiPainter(progress: _particleController.value),
                );
              },
            ),
          ),

          // Main Modal Container (Light Theme)
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasTerritory ? const Color(0xFFFFB300) : const Color(0xFFE040FB),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasTerritory ? const Color(0xFFFFB300) : const Color(0xFFE040FB)).withOpacity(0.22),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Hero Trophy Icon with Glowing Gradient Ring
                  ScaleTransition(
                    scale: _glowAnimation,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: hasTerritory
                              ? [const Color(0xFFFFD700), const Color(0xFFFF8F00)]
                              : [const Color(0xFFE040FB), const Color(0xFF00E5FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (hasTerritory ? const Color(0xFFFFD700) : const Color(0xFF00E5FF)).withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          hasTerritory ? Icons.emoji_events : Icons.verified,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Header Title
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: hasTerritory ? const Color(0xFFD97706) : const Color(0xFF8E24AA),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 6),

                  // Message Description
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 18),

                  // Accomplishment Metrics Grid (Light Theme)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildStatBox('🏃 DISTANCE', '$distKm km', const Color(0xFF0097A7)),
                            const SizedBox(width: 8),
                            _buildStatBox('⏱️ DURATION', _formatDuration(widget.durationSeconds), const Color(0xFF8E24AA)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatBox('🏰 TERRITORY', hasTerritory ? '$areaFormatted m²' : 'Route', const Color(0xFFD97706)),
                            const SizedBox(width: 8),
                            _buildStatBox('⚡ REWARD', '+${widget.xpGained} XP', const Color(0xFF2E7D32)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Optional Unlocked Achievement Banner (Light Theme)
                  if (widget.achievementUnlocked != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars, color: Color(0xFFD97706), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ACHIEVEMENT UNLOCKED!',
                                  style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                Text(
                                  widget.achievementUnlocked!,
                                  style: const TextStyle(color: Color(0xFF78350F), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showSharePreview(context),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('SHARE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0288D1),
                            side: const BorderSide(color: Color(0xFF0288D1), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasTerritory ? const Color(0xFFFFB300) : const Color(0xFFE040FB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          child: const Text('CONTINUE ➡️'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Color(0xFF1A202C), fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering animated falling confetti pieces
class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<_ConfettiParticle> _particles = List.generate(45, (i) {
    final random = math.Random(i);
    return _ConfettiParticle(
      x: random.nextDouble(),
      speed: 0.6 + random.nextDouble() * 0.8,
      size: 4 + random.nextDouble() * 6,
      color: [
        const Color(0xFFFFD700), // Gold
        const Color(0xFF00E5FF), // Neon Cyan
        const Color(0xFFE040FB), // Neon Violet
        const Color(0xFF00E676), // Neon Green
        const Color(0xFFFF5252), // Coral Red
      ][i % 5],
      rotation: random.nextDouble() * 2 * math.pi,
    );
  });

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in _particles) {
      final y = ((p.x * 0.3 + progress * p.speed) % 1.0) * size.height;
      final x = p.x * size.width + math.sin(progress * 2 * math.pi + p.x * 10) * 20;

      final paint = Paint()..color = p.color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * math.pi * 2);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double rotation;

  _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

/// Celebratory engagement dialog for Unlocked Badges & Achievements
class _AchievementCelebrationDialog extends StatefulWidget {
  final AchievementModel achievement;
  final VoidCallback onDismiss;

  const _AchievementCelebrationDialog({
    required this.achievement,
    required this.onDismiss,
  });

  @override
  State<_AchievementCelebrationDialog> createState() => _AchievementCelebrationDialogState();
}

class _AchievementCelebrationDialogState extends State<_AchievementCelebrationDialog> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut);
    _glowAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeInOut),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (a.isUnlocked)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (ctx, child) => CustomPaint(
                  painter: _ConfettiPainter(progress: _particleController.value),
                ),
              ),
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: a.isUnlocked ? const Color(0xFFFFB300) : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (a.isUnlocked ? const Color(0xFFFFB300) : Colors.grey).withValues(alpha: 0.2),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _glowAnimation,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: a.isUnlocked
                              ? [const Color(0xFFFFD700), const Color(0xFFFF8F00)]
                              : [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (a.isUnlocked ? const Color(0xFFFFD700) : Colors.grey).withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          a.isUnlocked ? Icons.stars : Icons.stars_outlined,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    a.isUnlocked ? 'TROPHY UNLOCKED! 🏆' : 'BADGE OBJECTIVE 🎯',
                    style: TextStyle(
                      color: a.isUnlocked ? const Color(0xFFD97706) : Colors.grey.shade800,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.title,
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.description,
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('STATUS', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              a.isUnlocked ? 'COMPLETED ✨' : 'IN PROGRESS ⏳',
                              style: TextStyle(
                                color: a.isUnlocked ? const Color(0xFF2E7D32) : const Color(0xFF0097A7),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('REWARD', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              '+${a.xpReward} XP',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (a.isUnlocked) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 Shared "${a.title}" achievement!'),
                                  backgroundColor: const Color(0xFFE040FB),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('SHARE'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0288D1),
                              side: const BorderSide(color: Color(0xFF0288D1), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: a.isUnlocked ? const Color(0xFFFFB300) : const Color(0xFFE040FB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          child: Text(a.isUnlocked ? 'AWESOME! 🌟' : 'CLOSE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Celebratory engagement dialog for Completed Missions & Quests
class _MissionCelebrationDialog extends StatefulWidget {
  final MissionModel mission;
  final VoidCallback onDismiss;

  const _MissionCelebrationDialog({
    required this.mission,
    required this.onDismiss,
  });

  @override
  State<_MissionCelebrationDialog> createState() => _MissionCelebrationDialogState();
}

class _MissionCelebrationDialogState extends State<_MissionCelebrationDialog> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut);
    _glowAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeInOut),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission;
    final isCompleted = m.status == 'COMPLETED' || m.status == 'CLAIMED';

    String displayProgress = m.targetType == 'DISTANCE'
        ? '${(m.progress / 1000).toStringAsFixed(1)} / ${(m.targetValue / 1000).toStringAsFixed(0)} km'
        : '${m.progress.toStringAsFixed(0)} / ${m.targetValue.toStringAsFixed(0)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (isCompleted)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (ctx, child) => CustomPaint(
                  painter: _ConfettiPainter(progress: _particleController.value),
                ),
              ),
            ),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isCompleted ? const Color(0xFF00E676) : const Color(0xFFE040FB),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCompleted ? const Color(0xFF00E676) : const Color(0xFFE040FB)).withValues(alpha: 0.2),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _glowAnimation,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isCompleted
                              ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                              : [const Color(0xFFE040FB), const Color(0xFF8E24AA)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isCompleted ? const Color(0xFF00E676) : const Color(0xFFE040FB)).withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isCompleted ? Icons.military_tech : Icons.track_changes,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCompleted ? 'MISSION ACCOMPLISHED! 🎯' : 'MISSION BRIEFING 📋',
                    style: TextStyle(
                      color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFF8E24AA),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.title,
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TARGET PROGRESS', style: TextStyle(color: Colors.grey.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(displayProgress, style: const TextStyle(color: Color(0xFF1A202C), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildRewardBadge('+${m.xpReward} XP', const Color(0xFF0097A7)),
                            _buildRewardBadge('+${m.coinReward} Coins', const Color(0xFFD97706)),
                            _buildRewardBadge('+${m.contributionReward} CS', const Color(0xFF00897B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (isCompleted) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 Shared "${m.title}" mission achievement!'),
                                  backgroundColor: const Color(0xFF00E676),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('SHARE'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0288D1),
                              side: const BorderSide(color: Color(0xFF0288D1), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompleted ? const Color(0xFF00E676) : const Color(0xFFE040FB),
                            foregroundColor: isCompleted ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          child: Text(isCompleted ? 'CLAIMED! 🎁' : 'CONTINUE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
