import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

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

  final _registerEmailController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerAgeController = TextEditingController();
  final _registerWeightController = TextEditingController();
  final _registerHeightController = TextEditingController();

  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  int _currentRegisterStep = 1;
  bool _isLogin = true;
  bool _showServerSettings = false;
  
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
    // Set initial server url from state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverUrlController.text = Provider.of<AppState>(context, listen: false).api.baseUrl;
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerUsernameController.dispose();
    _registerPasswordController.dispose();
    _registerAgeController.dispose();
    _registerWeightController.dispose();
    _registerHeightController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // FitTerra Logo Banner
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE040FB), Color(0xFF00E5FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE040FB).withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Text(
                    'PLAYRA',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Record activity. Close loops. Conquer territories.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Segment Selector Toggle (iOS Pill Style)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = true;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLogin ? const Color(0xFFE040FB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'LOGIN',
                              style: TextStyle(
                                color: _isLogin ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = false;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isLogin ? const Color(0xFFE040FB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'REGISTER',
                              style: TextStyle(
                                color: !_isLogin ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (state.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),

              // Interactive Dynamic Height Card with CrossFade Animation
              Card(
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: _buildLoginForm(state),
                    secondChild: _buildRegisterForm(state),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Advanced Server URL Editor Toggle
              Card(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.04),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.settings_ethernet, color: Color(0xFF00E5FF)),
                      title: const Text(
                        'Advanced Server Settings',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      trailing: Icon(
                        _showServerSettings ? Icons.expand_less : Icons.expand_more,
                        color: Colors.black54,
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
                            IconButton(
                              onPressed: () {
                                state.api.setBaseUrl(_serverUrlController.text.trim());
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Server endpoint set to: ${state.api.baseUrl}')),
                                );
                              },
                              icon: const Icon(Icons.save_outlined, color: Color(0xFFE040FB)),
                            ),
                          ],
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

  Widget _buildLoginForm(AppState state) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          _buildTextField(
            controller: _loginEmailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            validator: (val) => val == null || val.isEmpty ? 'Email required' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: true,
            validator: (val) => val == null || val.isEmpty ? 'Password required' : null,
          ),
          const SizedBox(height: 32),
          _buildSubmitButton(
            label: 'ENTER GAME',
            loading: state.isLoading,
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepDot(1, 'Account'),
              Container(
                width: 50,
                height: 2,
                color: _currentRegisterStep >= 2 ? const Color(0xFFE040FB) : Colors.grey.shade300,
              ),
              _buildStepDot(2, 'Bio Details'),
            ],
          ),
          const SizedBox(height: 24),
          if (_currentRegisterStep == 1) ...[
            _buildTextField(
              controller: _registerEmailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              validator: (val) => val == null || val.isEmpty ? 'Email required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerUsernameController,
              label: 'Username',
              icon: Icons.person_outline,
              validator: (val) => val == null || val.isEmpty ? 'Username required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _registerPasswordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: true,
              validator: (val) => val == null || val.isEmpty ? 'Password required' : null,
            ),
            const SizedBox(height: 20),
            // Color Selector
            const Text(
              'CHOOSE MAP COLOR',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
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
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.grey.shade800, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            _buildSubmitButton(
              label: 'NEXT STEP',
              loading: false,
              onPressed: () {
                if (_registerFormKey.currentState!.validate()) {
                  setState(() {
                    _currentRegisterStep = 2;
                  });
                }
              },
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _registerAgeController,
                    label: 'Age',
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.people_outline, color: Color(0xFFE040FB)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
                      ),
                    ),
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
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _registerHeightController,
                    label: 'Height (cm)',
                    icon: Icons.height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
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
            const SizedBox(height: 30),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildSubmitButton(
                    label: 'CREATE ACCOUNT',
                    loading: state.isLoading,
                    onPressed: () async {
                      if (_registerFormKey.currentState!.validate()) {
                        final double weight = double.tryParse(_registerWeightController.text) ?? 70.0;
                        final double height = double.tryParse(_registerHeightController.text) ?? 170.0;
                        final int age = int.tryParse(_registerAgeController.text) ?? 25;
                        final success = await state.register(
                          _registerEmailController.text.trim(),
                          _registerPasswordController.text,
                          _registerUsernameController.text.trim(),
                          _selectedColor,
                          weight,
                          height,
                          age,
                          _selectedGender,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account created successfully! Welcome to PlayRa.')),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFE040FB), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE040FB), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE040FB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        shadowColor: const Color(0xFFE040FB).withOpacity(0.4),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final active = _currentRegisterStep == step;
    final done = _currentRegisterStep > step;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE040FB)
                : (done ? const Color(0xFFE040FB).withOpacity(0.2) : Colors.grey.shade200),
            shape: BoxShape.circle,
            border: active ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Color(0xFFE040FB))
                : Text(
                    '$step',
                    style: TextStyle(
                      color: active ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFE040FB) : Colors.black54,
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
