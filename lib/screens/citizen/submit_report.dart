import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/issue_chip.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/ai_assessment_card.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});
  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isLoading = false;
  Report? _result;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = picked.name;
          _result = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _getLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lonController.text = position.longitude.toStringAsFixed(6);
          _result = null;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated from device GPS'),
            backgroundColor: AppTheme.resolved,
          ),
        );
      } else {
        setState(() => _error = 'Location services unavailable or permission denied');
      }
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    }
  }

  Future<void> _submit() async {
    if (_imageBytes == null) {
      setState(() => _error = 'Please select an image');
      return;
    }
    if (_latController.text.isEmpty || _lonController.text.isEmpty) {
      setState(() => _error = 'Please set GPS coordinates');
      return;
    }
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      setState(() => _error = 'Invalid coordinates');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      final api = context.read<AuthProvider>().apiService;
      final reportService = ReportService(api);
      final report = await reportService.submitReport(
        fileBytes: _imageBytes!,
        fileName: _imageName ?? 'photo.jpg',
        latitude: lat,
        longitude: lon,
        description: _descController.text.trim(),
      );
      setState(() { _result = report; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Issue'), backgroundColor: AppTheme.surface.withValues(alpha: 0.8)),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _result != null ? _buildResult() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image picker
        GestureDetector(
          onTap: () => _showImageSourceDialog(),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _imageBytes != null ? AppTheme.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08), width: 2),
            ),
            child: _imageBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_imageBytes!, fit: BoxFit.cover))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_rounded, color: AppTheme.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('Tap to add photo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Camera or Gallery', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ]),
          ),
        ),
        const SizedBox(height: 24),

        // GPS
        const Text('GPS Coordinates', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: CustomTextField(controller: _latController, label: 'Latitude', prefixIcon: Icons.north_rounded, keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: CustomTextField(controller: _lonController, label: 'Longitude', prefixIcon: Icons.east_rounded, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.my_location_rounded),
            label: const Text('Get Current Location'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accent, side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _getLocation,
          ),
        ),
        const SizedBox(height: 24),

        // Description
        CustomTextField(controller: _descController, label: 'Description (Optional)', hint: 'Describe the issue...', prefixIcon: Icons.description_outlined, maxLines: 3),
        const SizedBox(height: 24),

        if (_error != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withValues(alpha: 0.3))),
            child: Row(children: [const Icon(Icons.error_outline, color: AppTheme.error, size: 20), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 14)))]),
          ),

        GradientButton(text: 'Submit Report', icon: Icons.send_rounded, isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }

  Widget _buildResult() {
    final r = _result!;
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.resolved.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.check_circle_rounded, color: AppTheme.resolved, size: 64)),
      const SizedBox(height: 24),
      const Text('Report Submitted!', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Issue Number: ${r.issueNumber}', style: const TextStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(20), decoration: AppTheme.glassCard,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r.issueNumber, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)), StatusBadge(status: r.status)]),
          const SizedBox(height: 12),
          if (r.areaZone != null) Row(children: [const Icon(Icons.location_on, color: AppTheme.accent, size: 16), const SizedBox(width: 6), Text(r.areaZone!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))]),
          const SizedBox(height: 12),
          const Text('Detected Issues:', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (r.detections.isEmpty) const Text('No issues detected by AI', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Wrap(spacing: 8, runSpacing: 8, children: r.detections.map((d) => IssueChip(issueType: d.issueType)).toList()),
        ]),
      ),
      const SizedBox(height: 24),
      AiAssessmentCard(report: r),
      const SizedBox(height: 24),
      GradientButton(text: 'Submit Another', icon: Icons.add_rounded, onPressed: () => setState(() { _result = null; _imageBytes = null; _imageName = null; _descController.clear(); })),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home', style: TextStyle(color: AppTheme.textSecondary))),
    ]);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary), title: const Text('Camera', style: TextStyle(color: AppTheme.textPrimary)), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accent), title: const Text('Gallery', style: TextStyle(color: AppTheme.textPrimary)), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }
}
