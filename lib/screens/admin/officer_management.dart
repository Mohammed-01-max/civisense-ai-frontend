import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

// ── Supported values from backend/ai/routing.py ──────────────────────────────

const List<String> _kJurisdictions = [
  'GHMC',
  'Cyberabad Municipal Corporation',
  'Malkajgiri Municipal Corporation',
];

const List<String> _kDepartments = [
  'Electricity',
  'Encroachment & Illegal Construction',
  'Health & Sanitation',
  'Public Safety',
  'Road & Transportation',
  'Waste Management',
  'Water Leakage',
];

// ─────────────────────────────────────────────────────────────────────────────

class OfficerManagementScreen extends StatefulWidget {
  const OfficerManagementScreen({super.key});

  @override
  State<OfficerManagementScreen> createState() =>
      _OfficerManagementScreenState();
}

class _OfficerManagementScreenState extends State<OfficerManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _jurisdiction;
  String? _department;

  bool _isLoading = false;
  bool _obscurePassword = true;

  /// Stores the last successfully created officer's data for display.
  Map<String, dynamic>? _createdOfficer;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _createdOfficer = null;
    });

    try {
      final api = context.read<AuthProvider>().apiService;
      final service = AdminService(api);
      final result = await service.createOfficer(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        jurisdiction: _jurisdiction!,
        serviceDepartment: _department!,
      );
      if (!mounted) return;
      setState(() {
        _createdOfficer = result;
        _isLoading = false;
      });
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _jurisdiction = null;
      _department = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Management'),
        backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page intro ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Create Field Officer Account',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'New officers are assigned to a jurisdiction and service '
                            'department. They can log in with the provided credentials. '
                            'Listing is not yet available from the current backend.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Success banner ─────────────────────────────────────────
              if (_createdOfficer != null) ...[
                _SuccessBanner(officer: _createdOfficer!),
                const SizedBox(height: 20),
              ],

              // ── Error banner ───────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Form ───────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassCard,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel(
                          icon: Icons.person_outline_rounded,
                          label: 'Officer Details'),
                      const SizedBox(height: 16),

                      // Name
                      _ValidatedTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'e.g. Rahul Sharma',
                        prefixIcon: Icons.badge_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Full name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _ValidatedTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'officer@civicsense.gov',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRe = RegExp(
                              r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                          if (!emailRe.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Minimum 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: AppTheme.textMuted, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(
                          icon: Icons.location_city_outlined,
                          label: 'Assignment'),
                      const SizedBox(height: 16),

                      // Jurisdiction dropdown
                      DropdownButtonFormField<String>(
                        value: _jurisdiction,
                        dropdownColor: AppTheme.surface,
                        decoration: const InputDecoration(
                          labelText: 'Jurisdiction',
                          prefixIcon: Icon(Icons.account_balance_outlined,
                              color: AppTheme.textMuted, size: 20),
                        ),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        items: _kJurisdictions
                            .map((j) => DropdownMenuItem(
                                  value: j,
                                  child: Text(j),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _jurisdiction = v),
                        validator: (v) => v == null
                            ? 'Select a jurisdiction'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Service Department dropdown
                      DropdownButtonFormField<String>(
                        value: _department,
                        dropdownColor: AppTheme.surface,
                        decoration: const InputDecoration(
                          labelText: 'Service Department',
                          prefixIcon: Icon(Icons.business_center_outlined,
                              color: AppTheme.textMuted, size: 20),
                        ),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 14),
                        items: _kDepartments
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _department = v),
                        validator: (v) => v == null
                            ? 'Select a department'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      GradientButton(
                        text: 'Create Officer',
                        icon: Icons.person_add_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _ValidatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ValidatedTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
      ),
      validator: validator,
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final Map<String, dynamic> officer;
  const _SuccessBanner({required this.officer});

  @override
  Widget build(BuildContext context) {
    final name = officer['name'] as String? ?? '—';
    final jurisdiction = officer['jurisdiction'] as String? ?? '—';
    final dept = officer['service_department'] as String? ?? '—';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.resolved.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.resolved.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.resolved, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Officer Account Created',
                style: TextStyle(
                  color: AppTheme.resolved,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SuccessRow(label: 'Name', value: name),
          _SuccessRow(label: 'Jurisdiction', value: jurisdiction),
          _SuccessRow(label: 'Department', value: dept),
          const SizedBox(height: 8),
          Text(
            'The officer can now log in with their email and password.',
            style: TextStyle(
                color: AppTheme.resolved.withValues(alpha: 0.8),
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  const _SuccessRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
