import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../app_state.dart';

/// High-energy, gamified Celebration Dialog presented when an activity finishes,
/// a closed loop claims territory, cosmetic shop rewards are claimed, campaign
/// milestones are achieved, player levels up, or a milestone achievement is unlocked.
/// Styled with a crisp, ultra-premium Light Theme with glowing Neon Accents.
class CelebrationDialog extends StatefulWidget {
  final String title;
  final String message;
  final double distanceMeters;
  final int durationSeconds;
  final double? territoryArea;
  final int xpGained;
  final String? achievementUnlocked;
  final List<CampaignImpactModel>? campaignImpacts;
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
    this.campaignImpacts,
    required this.onDismiss,
  });

  /// Shows the main workout victory / territory claim celebration dialog.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required double distanceMeters,
    required int durationSeconds,
    double? territoryArea,
    int xpGained = 150,
    String? achievementUnlocked,
    List<CampaignImpactModel>? campaignImpacts,
  }) async {
    if (!context.mounted) return;
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
        campaignImpacts: campaignImpacts,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows an engaging celebration modal for unlocked/completed achievements.
  static Future<void> showAchievement(
    BuildContext context, {
    required AchievementModel achievement,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AchievementCelebrationDialog(
        achievement: achievement,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows an engaging celebration modal for completed daily/weekly missions.
  static Future<void> showMission(
    BuildContext context, {
    required MissionModel mission,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MissionCelebrationDialog(
        mission: mission,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows an engaging celebration modal when unlocking & claiming cosmetic shop rewards.
  static Future<void> showRewardClaimed(
    BuildContext context, {
    required RewardModel reward,
    required int remainingCoins,
    String? userColor,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RewardClaimedCelebrationDialog(
        reward: reward,
        remainingCoins: remainingCoins,
        userColorHex: userColor,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows an engaging celebration modal when hitting a Campaign milestone or completing a Campaign goal.
  static Future<void> showCampaignMilestone(
    BuildContext context, {
    required String campaignTitle,
    required String iconEmoji,
    required String milestoneTitle,
    required double thresholdKm,
    required int bonusPoints,
    required double currentDistanceKm,
    required double targetDistanceKm,
    required int totalPoints,
    bool isGoalCompleted = false,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CampaignMilestoneCelebrationDialog(
        campaignTitle: campaignTitle,
        iconEmoji: iconEmoji,
        milestoneTitle: milestoneTitle,
        thresholdKm: thresholdKm,
        bonusPoints: bonusPoints,
        currentDistanceKm: currentDistanceKm,
        targetDistanceKm: targetDistanceKm,
        totalPoints: totalPoints,
        isGoalCompleted: isGoalCompleted,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows a welcome celebration modal when successfully joining a Campaign challenge.
  static Future<void> showCampaignJoined(
    BuildContext context, {
    required CampaignModel campaign,
    int bonusPoints = 50,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CampaignJoinedCelebrationDialog(
        campaign: campaign,
        bonusPoints: bonusPoints,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
      ),
    );
  }

  /// Shows an engaging celebration modal when the player levels up.
  static Future<void> showLevelUp(
    BuildContext context, {
    required int newLevel,
    int bonusCoins = 50,
    String? unlockedPerk,
  }) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _LevelUpCelebrationDialog(
        newLevel: newLevel,
        bonusCoins: bonusCoins,
        unlockedPerk: unlockedPerk,
        onDismiss: () {
          if (Navigator.of(ctx, rootNavigator: true).canPop()) {
            Navigator.of(ctx, rootNavigator: true).pop();
          }
        },
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
                border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.share, color: Color(0xFFE040FB), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'I just conquered ${(widget.distanceMeters / 1000).toStringAsFixed(2)} km in TRION and claimed territory! Join the fitness battle!',
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
    final hasCampaignImpacts = widget.campaignImpacts != null && widget.campaignImpacts!.isNotEmpty;

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
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: hasTerritory ? const Color(0xFFFFB300) : const Color(0xFFE040FB),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasTerritory ? const Color(0xFFFFB300) : const Color(0xFFE040FB)).withValues(alpha: 0.22),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Hero Trophy Icon with Glowing Gradient Ring
                    ScaleTransition(
                      scale: _glowAnimation,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: hasTerritory
                                ? [const Color(0xFFFFD700), const Color(0xFFFF8F00)]
                                : [const Color(0xFFE040FB), const Color(0xFF00E5FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (hasTerritory ? const Color(0xFFFFD700) : const Color(0xFF00E5FF)).withValues(alpha: 0.35),
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
                            size: 42,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Header Title
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: hasTerritory ? const Color(0xFFD97706) : const Color(0xFF8E24AA),
                        fontSize: 20,
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

                    const SizedBox(height: 16),

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
                              _buildStatBox('🏰 TERRITORY', hasTerritory ? '$areaFormatted m²' : 'Route Logged', const Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              _buildStatBox('⚡ REWARD', '+${widget.xpGained} XP', const Color(0xFF2E7D32)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Optional Unlocked Achievement Banner
                    if (widget.achievementUnlocked != null) ...[
                      const SizedBox(height: 12),
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

                    // Multi-Campaign Points Impact Section
                    if (hasCampaignImpacts) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.track_changes, color: Color(0xFF16A34A), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'CAMPAIGN POINTS BOOST',
                                  style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...widget.campaignImpacts!.map((imp) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Text(imp.iconEmoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            imp.campaignTitle,
                                            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${imp.newDistanceKm.toStringAsFixed(1)} KM • ${imp.goalPercentage.toStringAsFixed(0)}% goal',
                                            style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+${imp.pointsEarned} PTS',
                                        style: const TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

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
          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                    a.isUnlocked ? 'STAR BADGE COMPLETED! ⭐🏆' : 'STAR BADGE OBJECTIVE 🎯',
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
                    isCompleted ? 'MISSION COMPLETED! 🎯✨' : 'MISSION BRIEFING 📋',
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

/// Celebratory popup dialog presented when user claims a Cosmetic Shop Item / Reward
class _RewardClaimedCelebrationDialog extends StatefulWidget {
  final RewardModel reward;
  final int remainingCoins;
  final String? userColorHex;
  final VoidCallback onDismiss;

  const _RewardClaimedCelebrationDialog({
    required this.reward,
    required this.remainingCoins,
    this.userColorHex,
    required this.onDismiss,
  });

  @override
  State<_RewardClaimedCelebrationDialog> createState() => _RewardClaimedCelebrationDialogState();
}

class _RewardClaimedCelebrationDialogState extends State<_RewardClaimedCelebrationDialog> with TickerProviderStateMixin {
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFE040FB);
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFE040FB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    final isTitle = r.type == 'TITLE';
    final accentColor = _parseColor(widget.userColorHex);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
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
                border: Border.all(color: accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
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
                          colors: [accentColor, const Color(0xFFFF80AB)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isTitle ? Icons.workspace_premium : Icons.palette,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'REWARD UNLOCKED! 🎁',
                    style: TextStyle(
                      color: Color(0xFFD81B60),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.title,
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.description,
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            const Text('ITEM TYPE', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              isTitle ? 'PLAYER TITLE' : 'MAP THEME',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('COIN BALANCE', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.remainingCoins} Coins',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      child: const Text('EQUIP & ENJOY ✨'),
                    ),
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

/// Celebratory popup dialog presented when a Campaign Milestone is unlocked or Campaign Goal completed
class _CampaignMilestoneCelebrationDialog extends StatefulWidget {
  final String campaignTitle;
  final String iconEmoji;
  final String milestoneTitle;
  final double thresholdKm;
  final int bonusPoints;
  final double currentDistanceKm;
  final double targetDistanceKm;
  final int totalPoints;
  final bool isGoalCompleted;
  final VoidCallback onDismiss;

  const _CampaignMilestoneCelebrationDialog({
    required this.campaignTitle,
    required this.iconEmoji,
    required this.milestoneTitle,
    required this.thresholdKm,
    required this.bonusPoints,
    required this.currentDistanceKm,
    required this.targetDistanceKm,
    required this.totalPoints,
    required this.isGoalCompleted,
    required this.onDismiss,
  });

  @override
  State<_CampaignMilestoneCelebrationDialog> createState() => _CampaignMilestoneCelebrationDialogState();
}

class _CampaignMilestoneCelebrationDialogState extends State<_CampaignMilestoneCelebrationDialog> with TickerProviderStateMixin {
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
    final pct = widget.targetDistanceKm > 0
        ? ((widget.currentDistanceKm / widget.targetDistanceKm) * 100).clamp(0.0, 100.0)
        : 100.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
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
                  color: widget.isGoalCompleted ? const Color(0xFF00E676) : const Color(0xFFFFA000),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isGoalCompleted ? const Color(0xFF00E676) : const Color(0xFFFFA000)).withValues(alpha: 0.25),
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
                          colors: widget.isGoalCompleted
                              ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
                              : [const Color(0xFFFFD700), const Color(0xFFFF8F00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isGoalCompleted ? const Color(0xFF00E676) : const Color(0xFFFFD700)).withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.iconEmoji,
                          style: const TextStyle(fontSize: 38),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isGoalCompleted ? 'CAMPAIGN GOAL COMPLETED! 🏆' : 'CAMPAIGN MILESTONE! 🎯',
                    style: TextStyle(
                      color: widget.isGoalCompleted ? const Color(0xFF15803D) : const Color(0xFFD97706),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.campaignTitle,
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlocked ${widget.milestoneTitle} (${widget.thresholdKm.toStringAsFixed(0)} KM Milestone)',
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            Text(
                              '${widget.currentDistanceKm.toStringAsFixed(1)} / ${widget.targetDistanceKm.toStringAsFixed(1)} KM',
                              style: const TextStyle(color: Color(0xFF1A202C), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '+${widget.bonusPoints} BONUS PTS',
                              style: const TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100.0,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isGoalCompleted ? const Color(0xFF00E676) : const Color(0xFFFFA000),
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Campaign Points: ${widget.totalPoints} PTS',
                          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Shared "${widget.campaignTitle}" progress!'),
                                backgroundColor: const Color(0xFFFFA000),
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
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isGoalCompleted ? const Color(0xFF00E676) : const Color(0xFFFFA000),
                            foregroundColor: widget.isGoalCompleted ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          child: const Text('AWESOME! 🌟'),
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

/// Celebratory popup dialog presented when user joins a new Campaign
class _CampaignJoinedCelebrationDialog extends StatefulWidget {
  final CampaignModel campaign;
  final int bonusPoints;
  final VoidCallback onDismiss;

  const _CampaignJoinedCelebrationDialog({
    required this.campaign,
    this.bonusPoints = 50,
    required this.onDismiss,
  });

  @override
  State<_CampaignJoinedCelebrationDialog> createState() => _CampaignJoinedCelebrationDialogState();
}

class _CampaignJoinedCelebrationDialogState extends State<_CampaignJoinedCelebrationDialog> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

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
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF00C853), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853).withValues(alpha: 0.22),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C853), Color(0xFF00E5FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C853).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      c.iconEmoji,
                      style: const TextStyle(fontSize: 38),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CAMPAIGN ENROLLED! 🚀',
                style: TextStyle(
                  color: Color(0xFF15803D),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                c.title,
                style: const TextStyle(
                  color: Color(0xFF1A202C),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Every kilometer you run or walk will automatically contribute to this mission and boost your leader score.',
                style: TextStyle(
                  color: Color(0xFF4A5568),
                  fontSize: 12.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.military_tech, color: Color(0xFF15803D), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '+${widget.bonusPoints} Starter Points Credited!',
                      style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  child: const Text('LET\'S RUN! 🏃'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celebratory popup dialog presented when player Levels Up
class _LevelUpCelebrationDialog extends StatefulWidget {
  final int newLevel;
  final int bonusCoins;
  final String? unlockedPerk;
  final VoidCallback onDismiss;

  const _LevelUpCelebrationDialog({
    required this.newLevel,
    this.bonusCoins = 50,
    this.unlockedPerk,
    required this.onDismiss,
  });

  @override
  State<_LevelUpCelebrationDialog> createState() => _LevelUpCelebrationDialogState();
}

class _LevelUpCelebrationDialogState extends State<_LevelUpCelebrationDialog> with TickerProviderStateMixin {
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
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
                border: Border.all(color: const Color(0xFFE040FB), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE040FB).withValues(alpha: 0.25),
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE040FB), Color(0xFF00E5FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE040FB).withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Lv.${widget.newLevel}',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LEVEL UP! ⚡',
                    style: TextStyle(
                      color: Color(0xFF8E24AA),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Congratulations! You reached Level ${widget.newLevel}!',
                    style: const TextStyle(
                      color: Color(0xFF1A202C),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your endurance is expanding your territory reach and status.',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '+${widget.bonusCoins} Coins Bonus',
                              style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        if (widget.unlockedPerk != null) ...[
                          Container(width: 1, height: 24, color: Colors.grey.shade300),
                          Text(
                            widget.unlockedPerk!,
                            style: const TextStyle(color: Color(0xFF0097A7), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE040FB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      child: const Text('CLAIM & CONTINUE 🚀'),
                    ),
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
