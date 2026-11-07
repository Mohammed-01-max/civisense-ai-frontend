import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../providers/auth_provider.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

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
  String? _error;
  Report? _result;

  // Map state
  final MapController _mapController = MapController();
  double? _locationAccuracy;
  String? _humanAddress;
  bool _isGeocoding = false;
  bool _isMapReady = false;
  Timer? _debounceTimer;
  bool _updatingFromMap = false;
  double _currentZoom = 15.0;

  LatLng _mapCenter = const LatLng(
    LocationService.defaultLat,
    LocationService.defaultLon,
  );

  @override
  void initState() {
    super.initState();
    _latController.addListener(_onManualCoordinateChange);
    _lonController.addListener(_onManualCoordinateChange);
  }

  @override
  void dispose() {
    _descController.dispose();
    _latController.removeListener(_onManualCoordinateChange);
    _lonController.removeListener(_onManualCoordinateChange);
    _latController.dispose();
    _lonController.dispose();
    _mapController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onManualCoordinateChange() {
    if (_updatingFromMap) return;
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat != null &&
        lon != null &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180) {
      setState(() {
        _locationAccuracy = null; // Clear accuracy on manual edit
        _mapCenter = LatLng(lat, lon);
      });
      if (_isMapReady) {
        _mapController.move(_mapCenter, _currentZoom);
      }
      _triggerGeocoding(lat, lon);
    }
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _updatingFromMap = true;
      final lat = camera.center.latitude;
      final lon = camera.center.longitude;
      _currentZoom = camera.zoom;

      _latController.text = lat.toStringAsFixed(6);
      _lonController.text = lon.toStringAsFixed(6);

      setState(() {
        _locationAccuracy =
            null; // Clear GPS accuracy when user manually adjusts map
      });
      _triggerGeocoding(lat, lon);
      _updatingFromMap = false;
    }
  }

  double? _lastGeocodedLat;
  double? _lastGeocodedLon;

  void _triggerGeocoding(double lat, double lon) {
    if (_lastGeocodedLat == lat && _lastGeocodedLon == lon) return;

    _debounceTimer?.cancel();
    setState(() {
      _isGeocoding = true;
      _humanAddress = null;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final address = await _reverseGeocode(lat, lon);
      if (!mounted) return;
      setState(() {
        _lastGeocodedLat = lat;
        _lastGeocodedLon = lon;
        _humanAddress = address;
        _isGeocoding = false;
      });
    });
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageName = picked.name;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image');
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _error = null;
    });
    try {
      final position = await LocationService.getCurrentLocation();
      if (!mounted) return;
      if (position != null) {
        _updatingFromMap = true;
        _latController.text = position.latitude.toStringAsFixed(6);
        _lonController.text = position.longitude.toStringAsFixed(6);
        _updatingFromMap = false;

        setState(() {
          // Actual position accuracy from device
          _locationAccuracy = position.accuracy;
          _mapCenter = LatLng(position.latitude, position.longitude);
        });

        if (_isMapReady) {
          _mapController.move(_mapCenter, 16.0);
        }
        _triggerGeocoding(position.latitude, position.longitude);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated from device GPS'),
            backgroundColor: AppTheme.resolved,
          ),
        );
      } else {
        setState(
          () => _error = 'Location services unavailable or permission denied',
        );
      }
    } catch (e) {
      if (!mounted) return;
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
    if (lat == null ||
        lon == null ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      setState(() => _error = 'Invalid coordinates');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
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
      if (!mounted) return;
      setState(() {
        _result = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;
    final user = context.watch<AuthProvider>().user;
    final userName = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!.trim()
        : 'Citizen';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(userName)),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  SizedBox(width: 227, child: _buildSidebar(userName)),
                  Expanded(child: _buildMainArea(userName, desktop: true)),
                ],
              )
            : _buildMainArea(userName, desktop: false),
      ),
    );
  }

  Widget _buildSidebar(String userName) {
    final successView = _result != null;
    return Container(
      color: const Color(0xFF0D1B2A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: SvgPicture.asset('assets/images/civisense_logo.svg'),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CiviSense AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Citizen Portal',
                        style: TextStyle(
                          color: Color(0xFFAAB7C9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sidebarItem(
            Icons.grid_view_rounded,
            'Dashboard',
            selected: false,
            onTap: () => _navigate('/citizen'),
          ),
          _sidebarItem(
            Icons.add_circle_outline_rounded,
            'Report an Issue',
            selected: !successView,
            onTap: () => _closeDrawer(),
          ),
          _sidebarItem(
            Icons.description_outlined,
            'My Reports',
            onTap: () => _navigate('/citizen/reports'),
          ),
          _sidebarItem(
            Icons.notifications_none_rounded,
            'Notifications',
            onTap: () => _navigate('/notifications'),
          ),
          _sidebarItem(
            Icons.person_outline_rounded,
            'Profile',
            onTap: () => _showProfile(userName),
          ),
          const Spacer(),
          _sidebarItem(Icons.logout_rounded, 'Logout', onTap: _logout),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final foreground = selected ? Colors.white : const Color(0xFFB6C1D0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected ? const Color(0xFF1769E0) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: SizedBox(
            height: 43,
            child: Row(
              children: [
                const SizedBox(width: 13),
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 13),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeDrawer() {
    if (MediaQuery.sizeOf(context).width < 1000) {
      Scaffold.of(context).closeDrawer();
    }
  }

  Future<void> _navigate(String route) async {
    _closeDrawer();
    await Navigator.pushNamed(context, route);
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _showProfile(String userName) {
    final user = context.read<AuthProvider>().user;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: Color(0xFF1A2940),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Color(0xFF758196), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea(String userName, {required bool desktop}) {
    final successView = _result != null;
    return Column(
      children: [
        _buildHeader(userName, desktop: desktop),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              desktop ? (successView ? 22 : 34) : 14,
              desktop ? (successView ? 18 : 28) : 14,
              desktop ? (successView ? 22 : 34) : 14,
              successView ? 20 : 36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: successView ? 1600 : 1220,
                ),
                child: _result != null ? _buildResult() : _buildForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String userName, {required bool desktop}) {
    final successView = _result != null;
    return Container(
      height: successView ? 60 : 74,
      padding: EdgeInsets.symmetric(
        horizontal: successView ? (desktop ? 24 : 10) : (desktop ? 28 : 12),
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF1))),
      ),
      child: Row(
        children: [
          if (!desktop)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            )
          else
            const Icon(Icons.menu_rounded, color: Color(0xFF1A2940)),
          const SizedBox(width: 14),
          if (successView)
            Expanded(
              child: Container(
                height: 38,
                constraints: const BoxConstraints(maxWidth: 490),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8693A6),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search reports, locations, or issues...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF8792A3),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Color(0xFF1A2940),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Citizen Portal',
                    style: TextStyle(color: Color(0xFF758196), fontSize: 11),
                  ),
                ],
              ),
            ),
          if (successView && desktop) const SizedBox(width: 28),
          if (successView)
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF536176),
                  size: 22,
                ),
                Positioned(
                  right: -2,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            )
          else
            const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF758196),
              size: 22,
            ),
          SizedBox(width: successView ? 16 : 16),
          CircleAvatar(
            radius: 18,
            backgroundColor: successView
                ? const Color(0xFF1769E0)
                : const Color(0xFFE5EEFA),
            child: Text(
              userName.isEmpty ? 'C' : userName[0].toUpperCase(),
              style: TextStyle(
                color: successView ? Colors.white : const Color(0xFF326BB4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (successView && desktop) ...[
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Color(0xFF1A2940),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Citizen',
                  style: TextStyle(color: Color(0xFF758196), fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF536176),
              size: 19,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E7EF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _currentZoom,
                onMapReady: () {
                  _isMapReady = true;
                },
                onPositionChanged: _onMapPositionChanged,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.civisense.app',
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.0),
                child: Icon(
                  Icons.location_pin,
                  color: Color(0xFFE24D59),
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submit a civic issue',
          style: TextStyle(
            color: Color(0xFF1A2940),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Share the details and location so your local authorities can take action.',
          style: TextStyle(color: Color(0xFF758196), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 850) {
              return Column(
                children: [
                  _buildIssueDetailsCard(),
                  const SizedBox(height: 18),
                  _buildUploadCard(),
                  const SizedBox(height: 18),
                  _buildLocationCard(),
                  const SizedBox(height: 18),
                  _buildAiPlaceholder(),
                  const SizedBox(height: 20),
                  _buildActions(),
                ],
              );
            }
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildIssueDetailsCard(),
                          const SizedBox(height: 18),
                          _buildUploadCard(),
                          const SizedBox(height: 18),
                          _buildAiPlaceholder(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(flex: 6, child: _buildLocationCard()),
                  ],
                ),
                const SizedBox(height: 20),
                _buildActions(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildIssueDetailsCard() {
    return _formCard(
      title: 'Issue Details',
      subtitle: 'Describe the civic issue you want to report.',
      icon: Icons.edit_note_rounded,
      child: TextField(
        controller: _descController,
        maxLines: 5,
        minLines: 4,
        style: const TextStyle(color: Color(0xFF1A2940), fontSize: 13),
        decoration: _inputDecoration(
          hintText: 'Describe the issue and any details that may help...',
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return _formCard(
      title: 'Upload Evidence',
      subtitle: 'Add a clear photo of the issue (required).',
      icon: Icons.photo_camera_outlined,
      child: InkWell(
        onTap: _showImageSourceDialog,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _imageBytes == null
                  ? const Color(0xFFCBD5E2)
                  : const Color(0xFF1769E0),
              width: _imageBytes == null ? 1 : 1.5,
              style: _imageBytes == null
                  ? BorderStyle.solid
                  : BorderStyle.solid,
            ),
          ),
          child: _imageBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Change photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF1769E0),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Click to upload or use camera',
                      style: TextStyle(
                        color: Color(0xFF26364E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Select a photo from your device',
                      style: TextStyle(color: Color(0xFF8995A7), fontSize: 11),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return _formCard(
      title: 'Location Details',
      subtitle: 'Pan the map or enter coordinates to set the issue location.',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMap(),
          const SizedBox(height: 11),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE7EBF1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: Color(0xFF1769E0),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isGeocoding
                      ? const Text(
                          'Looking up address...',
                          style: TextStyle(
                            color: Color(0xFF758196),
                            fontSize: 11,
                          ),
                        )
                      : Text(
                          _humanAddress ?? 'Address unavailable',
                          style: TextStyle(
                            color: _humanAddress != null
                                ? const Color(0xFF34445B)
                                : const Color(0xFF8995A7),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (_locationAccuracy != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.gps_fixed_rounded,
                  size: 14,
                  color: Color(0xFF1CA777),
                ),
                const SizedBox(width: 5),
                Text(
                  'GPS accuracy ±${_locationAccuracy!.toStringAsFixed(0)} m',
                  style: const TextStyle(
                    color: Color(0xFF68758A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _coordinateField(
                  label: 'Latitude',
                  controller: _latController,
                  icon: Icons.north_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _coordinateField(
                  label: 'Longitude',
                  controller: _lonController,
                  icon: Icons.east_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.my_location_rounded, size: 17),
              label: const Text('Use Current Location'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1769E0),
                side: const BorderSide(color: Color(0xFFB9D1F4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _getLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordinateField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF34445B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          style: const TextStyle(color: Color(0xFF1A2940), fontSize: 12),
          decoration: _inputDecoration(
            prefixIcon: icon,
            hintText: 'Enter $label',
          ),
        ),
      ],
    );
  }

  Widget _buildAiPlaceholder() {
    return _formCard(
      title: 'AI Assessment',
      subtitle: 'AI findings are shown after the report is submitted.',
      icon: Icons.auto_awesome_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE7EBF1)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF758196),
              size: 17,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Issue classification and related report information will appear here when provided by the analysis service.',
                style: TextStyle(
                  color: Color(0xFF68758A),
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7EBF1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1769E0), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A2940),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF758196),
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    IconData? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9AA5B4), fontSize: 12),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: const Color(0xFF8190A4), size: 16),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFFFCFDFE),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(7),
        borderSide: const BorderSide(color: Color(0xFF1769E0), width: 1.3),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFF0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF3C8CB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE05B61),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB43F47),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/citizen');
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF536176),
                side: const BorderSide(color: Color(0xFFD5DCE6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_isLoading ? 'Submitting...' : 'Submit Report'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769E0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final locationParts = <String>[
      if (r.areaZone?.trim().isNotEmpty == true) r.areaZone!.trim(),
      if (r.jurisdiction?.trim().isNotEmpty == true) r.jurisdiction!.trim(),
    ];
    final submittedAt = r.createdAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final submittedDate =
        '${localizations.formatMediumDate(submittedAt)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(submittedAt))}';
    final description = r.description?.trim() ?? '';
    final reportTitle = description.isNotEmpty
        ? description.split(RegExp(r'(?<=[.!?])\s+')).first
        : r.detections.isNotEmpty
        ? _formatReportLabel(r.detections.first.issueType)
        : 'Submitted issue';
    final category = r.detections.isNotEmpty
        ? r.detections.first.issueType
        : r.triageCategory;
    final location = locationParts.isEmpty
        ? 'Not provided'
        : locationParts.join(', ');
    final status = _formatReportLabel(r.status);
    final statusColor = switch (r.status.toLowerCase()) {
      'resolved' || 'closed' => const Color(0xFF168B58),
      'pending' => const Color(0xFFB97808),
      _ => const Color(0xFF1769E0),
    };

    Widget cardHeader(IconData icon, String title) {
      return Row(
        children: [
          Icon(icon, color: const Color(0xFF1769E0), size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF17243A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    Widget badge(String text, Color color, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget detailRow(
      IconData icon,
      String label,
      String value, {
      Widget? trailing,
    }) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = constraints.maxWidth >= 520 ? 170.0 : 118.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF314560), size: 17),
                const SizedBox(width: 14),
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF314560),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child:
                      trailing ??
                      Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF34445B),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget assessmentStep({
      required int index,
      required IconData icon,
      required String title,
      required String value,
      required String status,
      required Color statusColor,
      required bool isLast,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? const Color(0xFF1769E0)
                        : const Color(0xFFD2D9E3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 11, color: Colors.white),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 24,
                    color: const Color(0xFFE0E5EC),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF273951),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      badge(status, statusColor),
                    ],
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF758196),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget nextStep(IconData icon, Color color, String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF34445B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final detectionSummary = r.detections.isEmpty
        ? 'No detected issues were returned.'
        : r.detections.map((d) => _formatReportLabel(d.issueType)).join(', ');
    final classification = r.triageCategory == null
        ? 'No classification was returned.'
        : _formatReportLabel(r.triageCategory!);
    final routing = r.serviceDepartment?.trim().isNotEmpty == true
        ? r.serviceDepartment!.trim()
        : 'No department was returned.';
    final assessmentDetails = <Widget>[];

    void addAssessmentDetail(String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      assessmentDetails.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF758196),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF34445B),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (r.triageCategory != null) {
      addAssessmentDetail(
        'Classification',
        _formatReportLabel(r.triageCategory!),
      );
    }
    if (r.triageConfidence != null) {
      addAssessmentDetail(
        'Category confidence',
        '${(r.triageConfidence! * 100).toStringAsFixed(0)}%',
      );
    }
    if (r.triageSource != null) {
      addAssessmentDetail('Classification model', r.triageSource);
    }
    if (r.severity != null) {
      addAssessmentDetail('Severity', _formatReportLabel(r.severity!));
    }
    if (r.severityConfidence != null) {
      addAssessmentDetail(
        'Severity confidence',
        '${(r.severityConfidence! * 100).toStringAsFixed(0)}%',
      );
    }
    if (r.severitySource != null) {
      addAssessmentDetail('Severity model', r.severitySource);
    }
    if (r.priorityAdvisory != null) {
      final advisory = r.priorityAdvisory!;
      addAssessmentDetail('Priority', _formatReportLabel(advisory.level));
      addAssessmentDetail(
        'Priority reason',
        _formatReportLabel(advisory.reasonCode),
      );
      addAssessmentDetail(
        'Contributing factors',
        '${_formatReportLabel(advisory.factors.severity)} · '
            '${_formatReportLabel(advisory.factors.yoloEvidenceState)} · '
            '${_formatReportLabel(advisory.factors.possibleRecurrence)}',
      );
    }
    if (r.assignmentStatus.isNotEmpty) {
      addAssessmentDetail('Assignment', _formatReportLabel(r.assignmentStatus));
    }
    if (r.assignedOfficer?.name != null) {
      addAssessmentDetail('Assigned officer', r.assignedOfficer!.name);
    }
    if (r.similarReports.isNotEmpty) {
      addAssessmentDetail(
        'Similarity note',
        'Semantically related only; not confirmed duplicates.',
      );
      addAssessmentDetail(
        'Possible related reports',
        r.similarReports
            .map(
              (candidate) =>
                  '${candidate.issueNumber} · '
                  '${(candidate.similarityScore * 100).toStringAsFixed(0)}% similar',
            )
            .join('\n'),
      );
    }

    final reportDetailsCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7EBF1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardHeader(Icons.description_rounded, 'Report Details'),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 146,
                  height: 90,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : r.imageUrl?.isNotEmpty == true
                      ? Image.network(
                          r.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: Color(0xFFF1F4F8),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Color(0xFF8792A3),
                                ),
                              ),
                        )
                      : const ColoredBox(
                          color: Color(0xFFF1F4F8),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF8792A3),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reportTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17243A),
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        badge('#${r.issueNumber}', const Color(0xFF9B4354)),
                        if (category != null)
                          badge(
                            _formatReportLabel(category),
                            const Color(0xFF1769E0),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(
            Icons.home_work_outlined,
            'Status',
            status,
            trailing: badge(
              status,
              statusColor,
              icon: r.status.toLowerCase() == 'resolved'
                  ? Icons.check_circle_outline_rounded
                  : Icons.schedule_rounded,
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(
            Icons.calendar_today_outlined,
            'Submitted On',
            submittedDate,
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(Icons.location_on_outlined, 'Location', location),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(
            Icons.my_location_outlined,
            'Coordinates',
            '${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}',
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(
            Icons.business_outlined,
            'Department',
            r.serviceDepartment?.trim().isNotEmpty == true
                ? r.serviceDepartment!.trim()
                : 'Not provided',
          ),
          const Divider(height: 1, color: Color(0xFFE8ECF1)),
          detailRow(
            Icons.description_outlined,
            'Description',
            description.isNotEmpty ? description : 'Not provided',
          ),
        ],
      ),
    );

    final aiProcessingCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7EBF1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardHeader(Icons.psychology_outlined, 'AI Processing'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE1EEFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF1769E0),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI assessment received',
                        style: TextStyle(
                          color: Color(0xFF17243A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Returned image analysis, classification, and routing details are shown below.',
                        style: TextStyle(
                          color: Color(0xFF536176),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          assessmentStep(
            index: 0,
            icon: Icons.image_search_outlined,
            title: 'Image analysis',
            value: detectionSummary,
            status: r.detections.isEmpty ? 'No results' : 'Returned',
            statusColor: r.detections.isEmpty
                ? const Color(0xFF758196)
                : const Color(0xFF1769E0),
            isLast: false,
          ),
          assessmentStep(
            index: 1,
            icon: Icons.category_outlined,
            title: 'Issue classification',
            value: classification,
            status: r.triageCategory == null ? 'Not returned' : 'Returned',
            statusColor: r.triageCategory == null
                ? const Color(0xFF758196)
                : const Color(0xFF168B58),
            isLast: false,
          ),
          assessmentStep(
            index: 2,
            icon: Icons.account_tree_outlined,
            title: 'Department routing',
            value: routing,
            status: r.serviceDepartment?.trim().isNotEmpty == true
                ? 'Returned'
                : 'Not returned',
            statusColor: r.serviceDepartment?.trim().isNotEmpty == true
                ? const Color(0xFF168B58)
                : const Color(0xFF758196),
            isLast: true,
          ),
          if (assessmentDetails.isNotEmpty) ...[
            const Divider(height: 8, color: Color(0xFFE8ECF1)),
            ...assessmentDetails,
          ],
        ],
      ),
    );

    final whatsNextCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7EBF1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardHeader(Icons.format_list_bulleted_rounded, "What's Next?"),
          const SizedBox(height: 12),
          nextStep(
            Icons.notifications_active_rounded,
            const Color(0xFF1769E0),
            'You will be notified once the department takes action.',
          ),
          nextStep(
            Icons.description_rounded,
            const Color(0xFF168B58),
            'Track the status in My Reports.',
          ),
          nextStep(
            Icons.groups_rounded,
            const Color(0xFF7047C6),
            'Our team will work on resolving this issue as soon as possible.',
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2940).withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final successIcon = Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDF7EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF13945A),
                  size: 45,
                ),
              );
              final message = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Submitted Successfully!',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Your civic issue has been submitted and is now being processed by our AI system.',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFF536176),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'You can track the status in your reports section.',
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      color: Color(0xFF536176),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: compact
                    ? Column(
                        children: [
                          successIcon,
                          const SizedBox(height: 14),
                          message,
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          successIcon,
                          const SizedBox(width: 18),
                          Flexible(child: message),
                        ],
                      ),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    reportDetailsCard,
                    const SizedBox(height: 16),
                    aiProcessingCard,
                    const SizedBox(height: 16),
                    whatsNextCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 56, child: reportDetailsCard),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 44,
                    child: Column(
                      children: [
                        aiProcessingCard,
                        const SizedBox(height: 16),
                        whatsNextCard,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              SizedBox(
                width: 258,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => _navigate('/citizen/reports'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF536176),
                    backgroundColor: const Color(0xFFF0F3F7),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('View My Reports'),
                ),
              ),
              SizedBox(
                width: 288,
                height: 46,
                child: FilledButton.icon(
                  onPressed: () => setState(() {
                    _result = null;
                    _imageBytes = null;
                    _imageName = null;
                    _descController.clear();
                  }),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Submit Another Report'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1769E0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReportLabel(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DCE6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add evidence photo',
              style: TextStyle(
                color: Color(0xFF1A2940),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF1769E0),
              ),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF1769E0),
              ),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
