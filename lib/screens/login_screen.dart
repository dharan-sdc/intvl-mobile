import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../app_state.dart';

/// Screen component providing welcome onboarding, log-in authentication, and new player registration forms.
///
/// [Why] Handles all entry flows into the FitTerra application environment.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Text Controllers
  final _serverUrlController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerDobController = TextEditingController();
  final _registerAgeController = TextEditingController();
  final _registerWeightController = TextEditingController();
  final _registerHeightController = TextEditingController();
  final _registerProfilePicController = TextEditingController();

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  int _currentRegisterStep = 1;
  bool _isLogin = true;
  bool _showServerSettings = false;
  
  // Password Visibility toggles
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirmPassword = true;

  // Onboarding settings
  bool _showOnboarding = true;
  final PageController _pageController = PageController();
  int _currentSlide = 0;

  // Profile Picture state
  String _selectedAvatar = 'Runner';

  // Custom Color Selection for Registration
  String _selectedColor = '#E040FB'; // default violet
  final List<String> _colors = [
    '#E040FB', // Neon Violet
    '#FF007F', // Neon Pink
    '#00E5FF', // Neon Cyan
    '#39FF14', // Neon Green
    '#FFEB3B', // Neon Yellow
    '#FF5722', // Neon Red/Orange
  ];

  @override
  void initState() {
    super.initState();
    _registerProfilePicController.text = "preset:Runner";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverUrlController.text = Provider.of<AppState>(context, listen: false).api.baseUrl;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
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

  /// Computes chronological age from a selected birthday date relative to current time.
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

  /// Displays the calendar date picker modal and records values on select.
  ///
  /// [Why] Captures player birthday to auto-fill the age stat fields.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // default to 18 years ago
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE040FB), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Color(0xFF1E1E24), // Body text color
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
        
        // Calculate age
        int calculatedAge = _calculateAge(picked);
        _registerAgeController.text = calculatedAge.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Very light premium canvas
      body: SafeArea(
        child: Stack(
          children: [
            // Elegant background glowing elements for modern visual depth
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE040FB).withOpacity(0.04),
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
                  color: const Color(0xFF00E5FF).withOpacity(0.04),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            // Main View
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _showOnboarding
                  ? _buildOnboardingView()
                  : _buildLoginRegisterView(state),
            ),

            // Frosted premium Loading Overlay
            if (state.isLoading)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      color: Colors.white.withOpacity(0.4),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.black.withOpacity(0.04)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 44,
                                width: 44,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'CONNECTING TO TRION',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 2,
                                  color: Color(0xFF1E1E24),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Syncing profile and world GPS cells...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
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

  // --- WELCOME/ONBOARDING VIEW ---
  Widget _buildOnboardingView() {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          onPageChanged: (idx) {
            setState(() {
              _currentSlide = idx;
            });
          },
          children: [
            _buildOnboardingSlide(
              title: 'TRION',
              subtitle: 'TERRITORY RUNNING INTERACTION OWNERSHIP NETWORK',
              description: 'Lace up your shoes, step outside, and transform your real-world walks, runs, and rides into a battle for global territories.',
              icon: Icons.explore_outlined,
              color: const Color(0xFFE040FB),
            ),
            _buildOnboardingSlide(
              title: 'CLOSE LOOPS',
              subtitle: 'CONQUER NEIGHBORHOODS',
              description: 'Every activity maps your route in real time. Complete a closed-loop route to automatically capture the enclosed cells and build your territory.',
              icon: Icons.map_outlined,
              color: const Color(0xFF00E5FF),
            ),
            _buildOnboardingSlide(
              title: 'CLUBS & DEFENSE',
              subtitle: 'RISE TO DOMINANCE TOGETHER',
              description: 'Hit Level 10 to form or join a Club. Pool your XP together, gain Defense Points (DP), and guard your territories from rival attackers.',
              icon: Icons.groups_outlined,
              color: const Color(0xFFFF007F),
            ),
          ],
        ),

        // Skip Button
        Positioned(
          top: 16,
          right: 16,
          child: TextButton(
            onPressed: () {
              setState(() => _showOnboarding = false);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text(
              'SKIP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ),
        ),

        // Bottom Navigation Controllers
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

              // Giant Action Button
              SizedBox(
                width: double.infinity,
                child: _buildSubmitButton(
                  label: _currentSlide == 2 ? 'LACE UP & START' : 'CONTINUE',
                  onPressed: () {
                    if (_currentSlide < 2) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 355),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      setState(() => _showOnboarding = false);
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
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 36),
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
            const SizedBox(height: 24),
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

  // --- LOGIN/REGISTER FLOW VIEW ---
  Widget _buildLoginRegisterView(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button to return to Onboarding welcome notes
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black54),
              onPressed: () {
                setState(() => _showOnboarding = true);
              },
            ),
          ),
          const SizedBox(height: 4),

          // Glowing Premium Startup Logo & Header Design
          Center(
            child: Column(
              children: [
                // Modern Geometric Logo Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE040FB).withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE040FB), Color(0xFF00E5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Premium Kerned Typographic Logo
                const Text(
                  'T R I O N',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1E24),
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                // Crisp Tagline
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
          const SizedBox(height: 36),

          // Segment Selector Toggle (Premium iOS Sliding Pill Style)
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Animated sliding selection box
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
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Text items
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _isLogin = true),
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
                        onTap: () => setState(() => _isLogin = false),
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
          const SizedBox(height: 24),

          if (state.errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
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
                ],
              ),
            ),

          // Interactive Form Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.04)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1E24).withOpacity(0.03),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
              crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: _buildLoginForm(state),
              secondChild: _buildRegisterForm(state),
            ),
          ),
          const SizedBox(height: 24),

          // Advanced Server URL Settings
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.03)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.settings_ethernet, color: Color(0xFFE040FB)),
                  title: const Text(
                    'Advanced Server Settings',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1E24)),
                  ),
                  trailing: Icon(
                    _showServerSettings ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                  onTap: () {
                    setState(() {
                      _showServerSettings = !_showServerSettings;
                    });
                  },
                ),
                if (_showServerSettings)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _serverUrlController,
                            label: 'Server Base URL',
                            icon: Icons.link,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE040FB).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              state.api.setBaseUrl(_serverUrlController.text.trim());
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Server endpoint set to: ${state.api.baseUrl}')),
                              );
                            },
                            icon: const Icon(Icons.save, color: Color(0xFFE040FB)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AppState state) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          _buildTextField(
            controller: _loginEmailController,
            label: 'Email Address / Mobile',
            icon: Icons.email_outlined,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Email or mobile required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscureLoginPassword,
            showPasswordToggle: true,
            onTogglePassword: () {
              setState(() {
                _obscureLoginPassword = !_obscureLoginPassword;
              });
            },
            validator: (val) => val == null || val.isEmpty ? 'Password required' : null,
          ),
          const SizedBox(height: 28),
          _buildSubmitButton(
            label: 'ENTER GAME',
            onPressed: () async {
              if (_loginFormKey.currentState!.validate()) {
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
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AppState state) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          // Sleek progress bar wizard indicator (1 of 3, 2 of 3, 3 of 3)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentRegisterStep == 1
                        ? 'Step 1: Account setup'
                        : _currentRegisterStep == 2
                            ? 'Step 2: Profile identity'
                            : 'Step 3: Health & custom colors',
                    style: const TextStyle(
                      color: Color(0xFF1E1E24),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_currentRegisterStep of 3',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _currentRegisterStep / 3,
                  backgroundColor: const Color(0xFFF1F3F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE040FB)),
                  minHeight: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- STEP 1: PERSONAL & CONTACTS ---
          if (_currentRegisterStep == 1) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _registerFirstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.isEmpty ? 'First name required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _registerLastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.isEmpty ? 'Last name required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerUsernameController,
              label: 'Username / User ID',
              icon: Icons.alternate_email,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Username required';
                final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
                if (!regex.hasMatch(val)) {
                  return 'Use letters, digits, and underscores (3-20 chars)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerEmailController,
              label: 'Email Address / Mobile Number',
              icon: Icons.phone_android,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Email or mobile required';
                final mobileReg = RegExp(r'^\+?[0-9]{7,15}$');
                final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!mobileReg.hasMatch(val) && !emailReg.hasMatch(val)) {
                  return 'Enter a valid email or mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            _buildSubmitButton(
              label: 'NEXT STEP',
              onPressed: () {
                if (_registerFormKey.currentState!.validate()) {
                  setState(() {
                    _currentRegisterStep = 2;
                  });
                }
              },
            ),
          ]

          // --- STEP 2: SECURITY & PROFILE pic, dob ---
          else if (_currentRegisterStep == 2) ...[
            _buildTextField(
              controller: _registerPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscureRegisterPassword,
              showPasswordToggle: true,
              onTogglePassword: () {
                setState(() {
                  _obscureRegisterPassword = !_obscureRegisterPassword;
                });
              },
              validator: (val) => val == null || val.length < 4 ? 'Password must be at least 4 characters' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerConfirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_clock_outlined,
              obscure: _obscureRegisterConfirmPassword,
              showPasswordToggle: true,
              onTogglePassword: () {
                setState(() {
                  _obscureRegisterConfirmPassword = !_obscureRegisterConfirmPassword;
                });
              },
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please confirm password';
                if (val != _registerPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Date of Birth Input (with date picker popup trigger)
            GestureDetector(
              onTap: () => _selectDate(context),
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: _registerDobController,
                  label: 'Date of Birth',
                  icon: Icons.cake_outlined,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Date of birth is required';
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Preset avatar selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CHOOSE PROFILE AVATAR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '(OPTIONAL)',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAvatarOption('Runner', Icons.directions_run),
                _buildAvatarOption('Cyclist', Icons.directions_bike),
                _buildAvatarOption('Shield', Icons.shield),
                _buildAvatarOption('Flame', Icons.local_fire_department),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerProfilePicController,
              label: 'Or Custom Profile Pic Image URL (Optional)',
              icon: Icons.insert_link,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentRegisterStep = 1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      foregroundColor: const Color(0xFFE040FB),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildSubmitButton(
                    label: 'CONTINUE',
                    onPressed: () {
                      if (_registerFormKey.currentState!.validate()) {
                        setState(() {
                          _currentRegisterStep = 3;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ]

          // --- STEP 3: BIO STATS & COLORS ---
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    style: const TextStyle(color: Color(0xFF1E1E24), fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                      floatingLabelStyle: const TextStyle(color: Color(0xFFE040FB), fontSize: 12, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.people_outline, color: Colors.grey.shade500, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FD),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      ),
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGender = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _registerWeightController,
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerHeightController,
              label: 'Height (cm)',
              icon: Icons.height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            // Color Selector
            Text(
              'CHOOSE MAP COLOR',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _colors.map((colorHex) {
                final color = _parseColor(colorHex);
                final isSelected = _selectedColor == colorHex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = colorHex;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 2.5,
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
                                  color: color.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentRegisterStep = 2;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      foregroundColor: const Color(0xFFE040FB),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildSubmitButton(
                    label: 'CREATE',
                    onPressed: () async {
                      if (_registerFormKey.currentState!.validate()) {
                        final double weight = double.tryParse(_registerWeightController.text) ?? 70.0;
                        final double height = double.tryParse(_registerHeightController.text) ?? 170.0;
                        final int age = int.tryParse(_registerAgeController.text) ?? 25;
                        final success = await state.register(
                          emailInput: _registerEmailController.text.trim(),
                          passwordInput: _registerPasswordController.text,
                          usernameInput: _registerUsernameController.text.trim(),
                          firstName: _registerFirstNameController.text.trim(),
                          lastName: _registerLastNameController.text.trim(),
                          dob: _registerDobController.text,
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
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds selection button widgets for preset avatar cosmetics.
  Widget _buildAvatarOption(String name, IconData icon) {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withOpacity(0.12) : const Color(0xFFF8F9FD),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? themeColor : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? themeColor : Colors.grey.shade600,
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
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF1E1E24), fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(color: Color(0xFFE040FB), fontSize: 12, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
        suffixIcon: showPasswordToggle
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  /// Builds primary neon action buttons with gradient backgrounds.
  Widget _buildSubmitButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFE040FB), Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE040FB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
