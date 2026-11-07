import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF1769E0);
  static const Color _panelBlue = Color(0xFF1769E0);
  static const Color _ink = Color(0xFF17243A);
  static const Color _muted = Color(0xFF68758A);
  static const Color _line = Color(0xFFDCE3EC);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _jurisdiction = 'GHMC';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      jurisdiction: _jurisdiction,
      fullName: _fullNameController.text.trim(),
    );

    if (!mounted) return;

    if (auth.isAuthenticated) {
      _navigateToHome(auth.role);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppTheme.error),
      );
      auth.clearError();
    }
  }

  void _navigateToHome(String role) {
    switch (role) {
      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      case 'authority':
        Navigator.pushReplacementNamed(context, '/authority');
        break;
      case 'officer':
        Navigator.pushReplacementNamed(context, '/officer');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/citizen');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final content = isDesktop
                ? Row(
                    children: [
                      Expanded(flex: 53, child: _buildInformationPanel()),
                      Expanded(flex: 47, child: _buildRegisterArea()),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCompactInformationPanel(),
                        _buildMobileRegisterArea(),
                      ],
                    ),
                  );

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(position: _slideAnimation, child: content),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInformationPanel() {
    return Container(
      color: _panelBlue,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrand(),
            const Spacer(flex: 2),
            _buildInformationCopy(),
            const SizedBox(height: 26),
            _buildFeatureItems(),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactInformationPanel() {
    return Container(
      width: double.infinity,
      color: _panelBlue,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(compact: true),
          const SizedBox(height: 34),
          _buildInformationCopy(compact: true),
          const SizedBox(height: 24),
          _buildFeatureItems(compact: true),
        ],
      ),
    );
  }

  Widget _buildBrand({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SvgPicture.asset('assets/images/civisense_logo.svg'),
        ),
        const SizedBox(width: 13),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CiviSense AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 19 : 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Citizen Portal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInformationCopy({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: compact ? 30 : 38,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? -0.5 : -0.9,
            ),
            children: const [
              TextSpan(
                text: 'Smart Civic\n',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Reporting System',
                style: TextStyle(color: Color(0xFF8BD5FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 490),
          child: Text(
            'A citizen-centric platform to capture urban issues with AI-powered analysis, geo-tagged evidence, streamline municipal workflows, and measure resolution satisfaction.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: compact ? 13 : 14,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItems({bool compact = false}) {
    const features = [
      (
        icon: Icons.campaign_outlined,
        title: 'Report Issues',
        subtitle: 'Submit civic issues with photos and location',
        color: Color(0xFF29C28A),
      ),
      (
        icon: Icons.track_changes_outlined,
        title: 'Track Progress',
        subtitle: 'Monitor the status of your reports in real-time',
        color: Color(0xFF56A8F5),
      ),
      (
        icon: Icons.location_city_outlined,
        title: 'Cleaner Communities',
        subtitle: 'Together for a safer and smarter city',
        color: Color(0xFFAB83F5),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < features.length; index++) ...[
          if (index > 0) SizedBox(height: compact ? 14 : 16),
          _FeatureItem(
            icon: features[index].icon,
            title: features[index].title,
            subtitle: features[index].subtitle,
            color: features[index].color,
          ),
        ],
      ],
    );
  }

  Widget _buildRegisterArea() {
    return Column(
      children: [
        _buildLoginPrompt(compact: false),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 4, 32, 26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _buildRegisterCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileRegisterArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          _buildLoginPrompt(compact: true),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _buildRegisterCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt({required bool compact}) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 40,
          vertical: compact ? 18 : 20,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17243A).withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create your account',
              style: TextStyle(
                color: _ink,
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Join your community on CiviSense AI',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            _buildLabel('Full Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _ink, fontSize: 13),
              decoration: _inputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: 13),
            _buildLabel('Jurisdiction'),
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.white,
                colorScheme: Theme.of(
                  context,
                ).colorScheme.copyWith(surface: Colors.white, onSurface: _ink),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _jurisdiction,
                isExpanded: true,
                style: const TextStyle(color: _ink, fontSize: 13),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
                menuMaxHeight: 240,
                decoration: _inputDecoration(
                  prefixIcon: Icons.location_city_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'GHMC',
                    child: Text('GHMC', style: TextStyle(color: _ink)),
                  ),
                  DropdownMenuItem(
                    value: 'Cyberabad Municipal Corporation',
                    child: Text(
                      'Cyberabad Municipal Corporation',
                      style: TextStyle(color: _ink),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Malkajgiri Municipal Corporation',
                    child: Text(
                      'Malkajgiri Municipal Corporation',
                      style: TextStyle(color: _ink),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _jurisdiction = value);
                },
              ),
            ),
            const SizedBox(height: 13),
            _buildLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _ink, fontSize: 13),
              decoration: _inputDecoration(
                hintText: 'Enter your email',
                prefixIcon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 13),
            _buildLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _ink, fontSize: 13),
              decoration: _inputDecoration(
                hintText: 'Create a password',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _muted,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 13),
            _buildLabel('Confirm Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              style: const TextStyle(color: _ink, fontSize: 13),
              decoration: _inputDecoration(
                hintText: 'Confirm your password',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _muted,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Consumer<AuthProvider>(
              builder: (context, auth, _) => SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _register,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.65),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    elevation: 0,
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                style: TextButton.styleFrom(
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                ),
                child: const Text(
                  'Already registered? Login',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA5B4), fontSize: 12),
      prefixIcon: Icon(prefixIcon, size: 17, color: const Color(0xFF8190A4)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
      suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.4),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
