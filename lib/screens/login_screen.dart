import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _blue = Color(0xFF1769E0);
  static const Color _ink = Color(0xFF17243A);
  static const Color _muted = Color(0xFF68758A);
  static const Color _line = Color(0xFFDCE3EC);
  static const ImageProvider<Object>? _civicBackgroundImage = null;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.error!),
            backgroundColor: AppTheme.error,
          ),
        );
        auth.clearError();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (auth.isAuthenticated) {
      _navigateToHome(auth.role);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppTheme.error,
        ),
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
      case 'citizen':
        Navigator.pushReplacementNamed(context, '/citizen');
        break;
      default:
        final auth = context.read<AuthProvider>();
        auth.logout();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unsupported role. Access denied.'),
            backgroundColor: AppTheme.error,
          ),
        );
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
                      Expanded(flex: 47, child: _buildDesktopLoginArea()),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCompactInformationPanel(),
                        _buildMobileLoginArea(),
                      ],
                    ),
                  );

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInformationPanel() {
    return _buildCivicBackground(
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
    return _buildCivicBackground(
      child: Padding(
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
      ),
    );
  }

  Widget _buildCivicBackground({required Widget child}) {
    final backgroundImage = _civicBackgroundImage;
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF102F58)),
        ),
        if (backgroundImage != null)
          Positioned.fill(
            child: Image(
              image: backgroundImage,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xD90A2F5B), Color(0xE60B3976)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        child,
      ],
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

  Widget _buildDesktopLoginArea() {
    return Column(
      children: [
        _buildRegisterPrompt(alignment: Alignment.centerRight),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLoginArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          _buildRegisterPrompt(alignment: Alignment.centerRight, compact: true),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildLoginCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterPrompt({
    required Alignment alignment,
    bool compact = false,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 40,
          vertical: compact ? 18 : 20,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              "Don't have an account? ",
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Register',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
              'Sign in to CiviSense AI',
              textAlign: TextAlign.left,
              style: TextStyle(
                color: _ink,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Access your citizen dashboard',
              textAlign: TextAlign.left,
              style: TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildInputLabel('Username / Email'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _ink, fontSize: 14),
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
            const SizedBox(height: 14),
            _buildInputLabel('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(color: _ink, fontSize: 14),
              decoration: _inputDecoration(
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _muted,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Password is required';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Password Reset'),
                      content: const Text(
                        'Self-service password reset is not currently implemented. '
                        'Please contact your system administrator through your organization\'s official support channel to request a password reset.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Consumer<AuthProvider>(
              builder: (context, auth, _) => SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _login,
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
                          'Login',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider(color: _line, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: _muted.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: _line, height: 1)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Register as a Citizen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _ink,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA5B4), fontSize: 13),
      prefixIcon: Icon(prefixIcon, size: 19, color: const Color(0xFF8190A4)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFFCFDFE),
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
