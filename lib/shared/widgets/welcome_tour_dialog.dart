import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

/// Interactive 3-card onboarding tour dialog designed for first-time players.
///
/// [Why] Follows the progressive disclosure principle: introduces core features 
/// (Tracking, Territory Loop Conquest, Campaigns & Badges) visually in 30 seconds.
class WelcomeTourDialog extends StatefulWidget {
  final VoidCallback? onCompleted;

  const WelcomeTourDialog({super.key, this.onCompleted});

  /// Static helper to trigger the welcome tour if the user hasn't seen it yet.
  static Future<void> showIfFirstTime(BuildContext context) async {
    final state = Provider.of<AppState>(context, listen: false);
    if (!state.hasSeenWelcomeOnboarding) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const WelcomeTourDialog(),
      );
    }
  }

  /// Static helper to force show the tour (e.g. from Profile help menu).
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const WelcomeTourDialog(),
    );
  }

  @override
  State<WelcomeTourDialog> createState() => _WelcomeTourDialogState();
}

class _WelcomeTourDialogState extends State<WelcomeTourDialog> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Track Your Movement',
      'subtitle': 'Lace up your shoes! Track live walking, running, or cycling sessions with real-time GNSS precision and split pacing.',
      'icon': Icons.directions_run,
      'color': const Color(0xFFE040FB),
      'badge': 'STEP 1 OF 3',
    },
    {
      'title': 'Conquer Hex Territories',
      'subtitle': 'Complete a closed GPS loop around any area to capture the H3 hexagon on the global map and fortify your defense points.',
      'icon': Icons.radar,
      'color': const Color(0xFF00E5FF),
      'badge': 'STEP 2 OF 3',
    },
    {
      'title': 'Campaigns, Clubs & Badges',
      'subtitle': 'Join community awareness runs, squad up with your club, and unlock glowing Star Trophy badges as you level up.',
      'icon': Icons.military_tech_outlined,
      'color': const Color(0xFF39FF14),
      'badge': 'STEP 3 OF 3',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishTour() {
    final state = Provider.of<AppState>(context, listen: false);
    state.markWelcomeOnboardingSeen(seen: true);
    Navigator.of(context, rootNavigator: true).pop();
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar with Skip Button
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 16, left: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _steps[_currentIndex]['color'].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _steps[_currentIndex]['badge'],
                        style: TextStyle(
                          color: _steps[_currentIndex]['color'],
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finishTour,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text(
                        'SKIP',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                  ],
                ),
              ),

              // Carousel Body
              SizedBox(
                height: 320,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemCount: _steps.length,
                  itemBuilder: (ctx, idx) {
                    final step = _steps[idx];
                    final Color accentColor = step['color'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Glowing Icon Container
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.2),
                                  accentColor.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              step['icon'],
                              size: 48,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            step['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E1E24),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle Description
                          Text(
                            step['subtitle'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Section: Dots & Action CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    // Indicator Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (i) {
                        final active = _currentIndex == i;
                        final Color dotColor = _steps[_currentIndex]['color'];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? dotColor : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Primary Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentIndex < _steps.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _finishTour();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _steps[_currentIndex]['color'],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentIndex == _steps.length - 1 ? 'LET\'S CONQUER' : 'NEXT',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
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
}
