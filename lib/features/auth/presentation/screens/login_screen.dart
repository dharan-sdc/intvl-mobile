import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui';
import 'package:mobile/app_state.dart';

/// Screen component providing welcome onboarding, log-in authentication, and new player registration forms.
///
/// [Why] Handles all entry flows into the Trion application environment with a modern, 
/// frictionless user registration and login experience.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register Controllers
  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerDobController = TextEditingController();
  final _registerAgeController = TextEditingController();
  final _registerWeightController = TextEditingController(text: '70.0');
  final _registerHeightController = TextEditingController(text: '175.0');
  final _registerProfilePicController = TextEditingController(text: 'preset:Runner');

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Non-Binary', 'Prefer not to say'];
  
  // Registration Section (1: Account Credentials, 2: Athlete Persona & Stats)
  int _currentRegisterSection = 1;
  bool _isLogin = true;
  
  // Password Visibility toggles
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;

  // Onboarding settings
  bool _dismissedOnboardingInSession = false;
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  // Profile Avatar state
  String _selectedAvatar = 'Runner';
  final List<Map<String, dynamic>> _avatarPresets = [
    {'name': 'Runner', 'icon': Icons.directions_run, 'label': 'Runner'},
    {'name': 'Cyclist', 'icon': Icons.directions_bike, 'label': 'Cyclist'},
    {'name': 'Shield', 'icon': Icons.shield_outlined, 'label': 'Guardian'},
    {'name': 'Flame', 'icon': Icons.local_fire_department, 'label': 'Blaze'},
    {'name': 'Bolt', 'icon': Icons.bolt, 'label': 'Speed'},
    {'name': 'Crown', 'icon': Icons.emoji_events_outlined, 'label': 'Champion'},
  ];

  // Custom Color Selection for Registration
  String _selectedColor = '#E040FB'; // default neon violet
  final List<String> _colors = [
    '#E040FB', // Neon Violet
    '#FF007F', // Neon Pink
    '#00E5FF', // Neon Cyan
    '#39FF14', // Neon Green
    '#FFD600', // Neon Gold
    '#FF5722', // Neon Sunset Orange
  ];

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    _registerEmailController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerDobController.dispose();
    _registerAgeController.dispose();
    _registerWeightController.dispose();
    _registerHeightController.dispose();
    _registerProfilePicController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Parses hex color strings into Color classes.
  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  /// Computes chronological age from a selected birthday date.
  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    int month1 = today.month;
    int month2 = birthDate.month;
    if (month2 > month1) {
      age--;
    } else if (month1 == month2) {
      int day1 = today.day;
      int day2 = birthDate.day;
      if (day2 > day1) {
        age--;
      }
    }
    return age;
  }

  /// Displays the calendar date picker modal and records values.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 22)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE040FB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1E24),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        final formattedDate = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _registerDobController.text = formattedDate;
        final calculatedAge = _calculateAge(picked);
        _registerAgeController.text = calculatedAge.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient glowing background halos
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE040FB).withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // Main View
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: (!state.hasSeenWelcomeOnboarding && !_dismissedOnboardingInSession)
                  ? _buildOnboardingView()
                  : _buildLoginRegisterView(state),
            ),

            // Premium Frosted Loading Overlay
            if (state.isLoading)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.5),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 44,
                                width: 44,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'CONNECTING TO TRION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 2,
                                  color: Color(0xFF1E1E24),
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Syncing athlete profile & live map...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- WELCOME/ONBOARDING CAROUSEL VIEW ---
  Widget _buildOnboardingView() {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (idx) => setState(() => _currentSlide = idx),
          children: [
            _buildOnboardingSlide(
              title: 'TRION',
              subtitle: 'GLOBAL GPS TERRITORY CONQUEST',
              description: 'Lace up your shoes, step outside, and transform your real-world walks, runs, and rides into a tactical territory battle.',
              imageAsset: 'assets/logo.png',
              color: const Color(0xFF00E5FF),
            ),
            _buildOnboardingSlide(
              title: 'CLOSE LOOPS',
              subtitle: 'CLAIM H3 HEXAGON CELLS',
              description: 'Every activity maps your route in real time. Enclose an area in a loop to conquer hexagonal territory for your profile.',
              icon: Icons.radar,
              color: const Color(0xFFE040FB),
            ),
            _buildOnboardingSlide(
              title: 'CAMPAIGNS & CLUBS',
              subtitle: 'RISE TOGETHER ON LEADERBOARDS',
              description: 'Join community awareness runs, squad up with your club, and unlock glowing Star Trophy badges as you level up.',
              icon: Icons.military_tech_outlined,
              color: const Color(0xFF39FF14),
            ),
          ],
        ),

        // Skip Button
        Positioned(
          top: 16,
          right: 16,
          child: TextButton(
            onPressed: () {
              final state = Provider.of<AppState>(context, listen: false);
              state.markWelcomeOnboardingSeen(seen: true);
              setState(() => _dismissedOnboardingInSession = true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text('SKIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              // Indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (idx) {
                  final active = _currentSlide == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFE040FB) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: _buildSubmitButton(
                  label: _currentSlide == 2 ? 'LACE UP & START' : 'CONTINUE',
                  onPressed: () {
                    if (_currentSlide < 2) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      final state = Provider.of<AppState>(context, listen: false);
                      state.markWelcomeOnboardingSeen(seen: true);
                      setState(() => _dismissedOnboardingInSession = true);
                    }
                  },
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildOnboardingSlide({
    required String title,
    required String subtitle,
    required String description,
    IconData? icon,
    String? imageAsset,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null) ...[
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(imageAsset, fit: BoxFit.contain),
              ),
            ] else if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E1E24),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIN & REGISTRATION ROOT VIEW ---
  Widget _buildLoginRegisterView(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Logo & Branding
          Center(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                const Text(
                  'T R I O N',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1E24),
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lace up. Explore. Conquer.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Segment Selector Toggle (Sleek iOS Sliding Pill)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECEEF5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: _isLogin ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          state.clearErrorMessage();
                          setState(() => _isLogin = true);
                        },
                        child: Center(
                          child: Text(
                            'LOGIN',
                            style: TextStyle(
                              color: _isLogin ? const Color(0xFFE040FB) : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          state.clearErrorMessage();
                          setState(() => _isLogin = false);
                        },
                        child: Center(
                          child: Text(
                            'REGISTER',
                            style: TextStyle(
                              color: !_isLogin ? const Color(0xFFE040FB) : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Error message banner
          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => state.clearErrorMessage(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ],
              ),
            ),

          // Interactive Form Card Container
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: _buildLoginForm(state),
              secondChild: _buildRegisterForm(state),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- LOGIN FORM ---
  Widget _buildLoginForm(AppState state) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _buildTextField(
            controller: _loginEmailController,
            label: 'Email or Username',
            icon: Icons.alternate_email,
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Email or username is required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscureLoginPassword,
            showPasswordToggle: true,
            onTogglePassword: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            validator: (val) => (val == null || val.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 26),
          _buildSubmitButton(
            label: 'ENTER GAME',
            onPressed: () async {
              if (_loginFormKey.currentState!.validate()) {
                final isGpsOn = await Geolocator.isLocationServiceEnabled();
                if (!isGpsOn && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Location is turned off. Enable GPS for live territory tracking.'),
                      action: SnackBarAction(
                        label: 'SETTINGS',
                        textColor: const Color(0xFF00E5FF),
                        onPressed: () => Geolocator.openLocationSettings(),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }

                final success = await state.login(
                  _loginEmailController.text.trim(),
                  _loginPasswordController.text,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Welcome back, ${state.username}!')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // --- REDESIGNED STREAMLINED REGISTRATION FORM ---
  Widget _buildRegisterForm(AppState state) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step Header Chips (1. Account Details  |  2. Persona & Stats)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentRegisterSection = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentRegisterSection == 1 
                          ? const Color(0xFFE040FB).withValues(alpha: 0.12)
                          : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentRegisterSection == 1 
                            ? const Color(0xFFE040FB)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: _currentRegisterSection == 1 ? const Color(0xFFE040FB) : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '1. Credentials',
                          style: TextStyle(
                            color: _currentRegisterSection == 1 ? const Color(0xFFE040FB) : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_validateSection1()) {
                      setState(() => _currentRegisterSection = 2);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _currentRegisterSection == 2 
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
                          : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentRegisterSection == 2 
                            ? const Color(0xFF00E5FF)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 16,
                          color: _currentRegisterSection == 2 ? const Color(0xFF00E5FF) : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '2. Persona',
                          style: TextStyle(
                            color: _currentRegisterSection == 2 ? const Color(0xFF00E5FF) : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // SECTION 1: ACCOUNT CREDENTIALS
          if (_currentRegisterSection == 1) ...[
            // First & Last Name
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _registerFirstNameController,
                    label: 'First Name',
                    icon: Icons.badge_outlined,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _registerLastNameController,
                    label: 'Last Name',
                    icon: Icons.badge_outlined,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Username
            _buildTextField(
              controller: _registerUsernameController,
              label: 'Username (@handle)',
              icon: Icons.alternate_email,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Username is required';
                final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
                if (!regex.hasMatch(val.trim())) {
                  return 'Use letters, digits, and underscores (3-20 chars)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email
            _buildTextField(
              controller: _registerEmailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Email is required';
                final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailReg.hasMatch(val.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password
            _buildTextField(
              controller: _registerPasswordController,
              label: 'Password (min 4 chars)',
              icon: Icons.lock_outline,
              obscure: _obscureRegisterPassword,
              showPasswordToggle: true,
              onTogglePassword: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
              validator: (val) => (val == null || val.length < 4) ? 'Must be at least 4 characters' : null,
            ),
            const SizedBox(height: 14),

            // Confirm Password
            _buildTextField(
              controller: _registerConfirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_clock_outlined,
              obscure: _obscureRegisterConfirmPassword,
              showPasswordToggle: true,
              onTogglePassword: () => setState(() => _obscureRegisterConfirmPassword = !_obscureRegisterConfirmPassword),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please confirm password';
                if (val != _registerPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Next / Continue to Persona
            _buildSubmitButton(
              label: 'NEXT: ATHLETE PERSONA',
              onPressed: () {
                state.clearErrorMessage();
                if (_validateSection1()) {
                  setState(() => _currentRegisterSection = 2);
                }
              },
            ),
          ]

          // SECTION 2: ATHLETE PERSONA & MAP CUSTOMIZATION
          else ...[
            // Avatar Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CHOOSE AVATAR',
                  style: TextStyle(
                    color: Color(0xFF1E1E24),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _selectedAvatar.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE040FB),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _avatarPresets.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildAvatarOption(preset['name'], preset['icon'], preset['label']),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Territory Map Color Swatch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TERRITORY MAP COLOR',
                  style: TextStyle(
                    color: Color(0xFF1E1E24),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _parseColor(_selectedColor),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((colorHex) {
                  final color = _parseColor(colorHex);
                  final isSelected = _selectedColor == colorHex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? color : Colors.grey.shade300,
                            width: isSelected ? 3 : 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Gender & Date of Birth
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    style: const TextStyle(color: Color(0xFF1E1E24), fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFE040FB), fontSize: 12, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.people_outline, color: Colors.grey.shade500, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FD),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedGender = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _registerDobController,
                        label: 'Birth Date (DOB)',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Height & Weight
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _registerWeightController,
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _registerHeightController,
                    label: 'Height (cm)',
                    icon: Icons.height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons (Back + Complete)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      state.clearErrorMessage();
                      setState(() => _currentRegisterSection = 1);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      foregroundColor: const Color(0xFFE040FB),
                    ),
                    child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildSubmitButton(
                    label: 'CREATE ACCOUNT',
                    onPressed: _handleCompleteRegistration,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _validateSection1() {
    return _registerFirstNameController.text.trim().isNotEmpty &&
        _registerLastNameController.text.trim().isNotEmpty &&
        _registerUsernameController.text.trim().length >= 3 &&
        _registerEmailController.text.trim().contains('@') &&
        _registerPasswordController.text.length >= 4 &&
        _registerConfirmPasswordController.text == _registerPasswordController.text;
  }

  Future<void> _handleCompleteRegistration() async {
    final state = Provider.of<AppState>(context, listen: false);
    state.clearErrorMessage();

    if (!_validateSection1()) {
      setState(() => _currentRegisterSection = 1);
      _registerFormKey.currentState?.validate();
      return;
    }

    final isGpsOn = await Geolocator.isLocationServiceEnabled();
    if (!isGpsOn && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GPS is turned off. Turn on location services for real-time tracking.'),
          action: SnackBarAction(
            label: 'SETTINGS',
            textColor: const Color(0xFF00E5FF),
            onPressed: () => Geolocator.openLocationSettings(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final double weight = double.tryParse(_registerWeightController.text) ?? 70.0;
    final double height = double.tryParse(_registerHeightController.text) ?? 175.0;
    final int age = int.tryParse(_registerAgeController.text) ?? 24;

    final success = await state.register(
      emailInput: _registerEmailController.text.trim(),
      passwordInput: _registerPasswordController.text,
      usernameInput: _registerUsernameController.text.trim(),
      firstName: _registerFirstNameController.text.trim(),
      lastName: _registerLastNameController.text.trim(),
      dob: _registerDobController.text.isNotEmpty ? _registerDobController.text : '2000-01-01',
      profilePic: _registerProfilePicController.text,
      colorHex: _selectedColor,
      weightInput: weight,
      heightInput: height,
      ageInput: age,
      genderInput: _selectedGender,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully! Welcome to TRION.')),
      );
    }
  }

  /// Builds selection button widgets for preset avatar cosmetics.
  Widget _buildAvatarOption(String name, IconData icon, String label) {
    final isSelected = _selectedAvatar == name;
    final themeColor = _parseColor(_selectedColor);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatar = name;
          _registerProfilePicController.text = "preset:$name";
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.12) : const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? themeColor : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? themeColor : Colors.grey.shade700,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds standardized text form fields with inline error label support.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool showPasswordToggle = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF1E1E24),
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFFE040FB),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 18),
        suffixIcon: showPasswordToggle
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 18,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  /// Builds a high-contrast gradient call-to-action submit button.
  Widget _buildSubmitButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE040FB), // Neon Violet
            Color(0xFF00E5FF), // Neon Cyan
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE040FB).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
