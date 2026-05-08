import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MiUpcApp());
}

class MiUpcApp extends StatelessWidget {
  const MiUpcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TIU Virtual',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB6232E),
          background: const Color(0xFFF5F3FB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F3FB),
      ),
      home: const TiuVirtualScreen(),
    );
  }
}

class Profile {
  Profile({
    required this.fullName,
    required this.major,
    required this.studentCode,
    required this.bannerId,
    required this.campus,
    this.photoBytes,
  });

  String fullName;
  String major;
  String studentCode;
  String bannerId;
  String campus;
  Uint8List? photoBytes;

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'major': major,
      'studentCode': studentCode,
      'bannerId': bannerId,
      'campus': campus,
      'photoBytes': photoBytes == null ? null : base64Encode(photoBytes!),
    };
  }

  static Profile fromJson(Map<String, dynamic> json) {
    final String? encodedPhoto = json['photoBytes'] as String?;
    return Profile(
      fullName: (json['fullName'] as String? ?? '').trim(),
      major: (json['major'] as String? ?? '').trim(),
      studentCode: (json['studentCode'] as String? ?? '').trim(),
      bannerId: (json['bannerId'] as String? ?? '').trim(),
      campus: (json['campus'] as String? ?? '').trim(),
      photoBytes: encodedPhoto == null ? null : base64Decode(encodedPhoto),
    );
  }
}

class TiuVirtualScreen extends StatefulWidget {
  const TiuVirtualScreen({super.key});

  @override
  State<TiuVirtualScreen> createState() => _TiuVirtualScreenState();
}

class _TiuVirtualScreenState extends State<TiuVirtualScreen> {
  static const String _prefsProfilesKey = 'profiles';
  static const String _prefsActiveIndexKey = 'activeProfileIndex';
  static const String _prefsCloudsKey = 'cloudsMoving';
  static const String _prefsMaskKey = 'maskLastNames';

  final List<Profile> _profiles = [
    Profile(
      fullName: 'alumno demo p*** q***',
      major: 'INGENIERIA DE SISTEMAS',
      studentCode: 'a00000000',
      bannerId: 'N00000000',
      campus: 'Campus San Miguel',
    ),
  ];
  static const List<String> _campusOptions = [
    'Campus San Miguel',
    'Campus San Isidro',
    'Campus Monterrico',
    'Campus Villa',
  ];
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final TextEditingController _studentCodeController = TextEditingController();
  final TextEditingController _bannerIdController = TextEditingController();
  final TextEditingController _campusController = TextEditingController();
  Uint8List? _editingPhotoBytes;

  int _activeProfileIndex = 0;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  int _activePointers = 0;
  Offset? _gestureStart;
  bool _drawerOpenedByGesture = false;
  bool _cloudsMoving = true;
  bool _maskLastNames = true;

  @override
  void initState() {
    super.initState();
    _loadProfile(_profiles[_activeProfileIndex]);
    _restoreState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _nameController.dispose();
    _majorController.dispose();
    _studentCodeController.dispose();
    _bannerIdController.dispose();
    _campusController.dispose();
    super.dispose();
  }

  void _loadProfile(Profile profile) {
    _nameController.text = profile.fullName;
    _majorController.text = profile.major;
    _studentCodeController.text = profile.studentCode;
    _bannerIdController.text = profile.bannerId;
    _campusController.text = profile.campus;
    _editingPhotoBytes = profile.photoBytes;
  }

  Future<void> _restoreState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? profilesRaw = prefs.getString(_prefsProfilesKey);
    final int savedIndex = prefs.getInt(_prefsActiveIndexKey) ?? 0;
    final bool clouds = prefs.getBool(_prefsCloudsKey) ?? _cloudsMoving;
    final bool mask = prefs.getBool(_prefsMaskKey) ?? _maskLastNames;

    if (profilesRaw != null && profilesRaw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(profilesRaw) as List<dynamic>;
        final List<Profile> loaded = decoded
            .map((item) => Profile.fromJson(item as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          if (!mounted) {
            return;
          }
          setState(() {
            _profiles
              ..clear()
              ..addAll(loaded);
            _activeProfileIndex = savedIndex.clamp(0, _profiles.length - 1);
            _cloudsMoving = clouds;
            _maskLastNames = mask;
          });
          _loadProfile(_profiles[_activeProfileIndex]);
          return;
        }
      } catch (_) {
        // Ignore and keep defaults if stored data is corrupted.
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _cloudsMoving = clouds;
      _maskLastNames = mask;
    });
  }

  Future<void> _saveState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String profilesRaw = jsonEncode(
      _profiles.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_prefsProfilesKey, profilesRaw);
    await prefs.setInt(_prefsActiveIndexKey, _activeProfileIndex);
    await prefs.setBool(_prefsCloudsKey, _cloudsMoving);
    await prefs.setBool(_prefsMaskKey, _maskLastNames);
  }

  String _normalizeCampus(String input) {
    final String normalized = input.trim();
    if (normalized.isEmpty) {
      return _campusOptions.first;
    }
    for (final option in _campusOptions) {
      if (option.toLowerCase() == normalized.toLowerCase()) {
        return option;
      }
    }
    return _campusOptions.first;
  }

  String _formatStudentName(String fullName, {required bool censor}) {
    final List<String> parts = fullName
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (!censor || parts.length < 2) {
      return parts.join(' ');
    }
    final int startIndex = (parts.length - 2).clamp(0, parts.length);
    for (int i = startIndex; i < parts.length; i += 1) {
      final String part = parts[i];
      if (part.isEmpty) {
        continue;
      }
      parts[i] = '${part[0]}***';
    }
    return parts.join(' ');
  }

  Future<void> _pickPhoto() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) {
      return;
    }
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar',
          toolbarColor: const Color(0xFFB6232E),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Recortar',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped == null) {
      return;
    }
    final Uint8List bytes = await XFile(cropped.path).readAsBytes();
    setState(() {
      _editingPhotoBytes = bytes;
    });
  }

  void _saveProfile({required bool asNew}) {
    final Profile updated = Profile(
      fullName: _nameController.text.trim().toLowerCase(),
      major: _majorController.text.trim().toUpperCase(),
      studentCode: _studentCodeController.text.trim().toLowerCase(),
      bannerId: _bannerIdController.text.trim().toUpperCase(),
      campus: _normalizeCampus(_campusController.text),
      photoBytes: _editingPhotoBytes,
    );
    setState(() {
      if (asNew) {
        _profiles.add(updated);
        _activeProfileIndex = _profiles.length - 1;
      } else {
        _profiles[_activeProfileIndex] = updated;
      }
    });
    _saveState();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers += 1;
    if (_activePointers == 2) {
      _gestureStart = event.position;
      _drawerOpenedByGesture = false;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_activePointers == 0) {
      _gestureStart = null;
      _drawerOpenedByGesture = false;
    }
  }

  void _handlePointerMove(PointerMoveEvent event, BuildContext context) {
    if (_activePointers < 2 ||
        _gestureStart == null ||
        _drawerOpenedByGesture) {
      return;
    }
    final double deltaX = event.position.dx - _gestureStart!.dx;
    if (deltaX < -80) {
      _drawerOpenedByGesture = true;
      Scaffold.of(context).openEndDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Profile profile = _profiles[_activeProfileIndex];
    final Size screenSize = MediaQuery.of(context).size;
    final double scale = (screenSize.height / 780).clamp(0.9, 1.1);
    final double photoRadius = 120 * scale;
    final double photoPadding = 10 * scale;
    final String displayName =
        _formatStudentName(profile.fullName, censor: _maskLastNames);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        endDrawer: _EditProfileDrawer(
          profiles: _profiles,
          activeIndex: _activeProfileIndex,
          nameController: _nameController,
          majorController: _majorController,
          studentCodeController: _studentCodeController,
          bannerIdController: _bannerIdController,
          campusController: _campusController,
          photoBytes: _editingPhotoBytes,
          cloudsMoving: _cloudsMoving,
          maskLastNames: _maskLastNames,
          onPickPhoto: _pickPhoto,
          onSaveExisting: () => _saveProfile(asNew: false),
          onSaveNew: () => _saveProfile(asNew: true),
          onToggleClouds: (value) {
            setState(() {
              _cloudsMoving = value;
            });
            _saveState();
          },
          onToggleMask: (value) {
            setState(() {
              _maskLastNames = value;
            });
            _saveState();
          },
          onSelectProfile: (index) {
            setState(() {
              _activeProfileIndex = index;
            });
            _loadProfile(_profiles[index]);
            _saveState();
          },
        ),
        body: Builder(
          builder: (context) {
            return Listener(
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerUp,
              onPointerMove: (event) => _handlePointerMove(event, context),
              child: Stack(
                children: [
                  const Positioned.fill(child: _SkyBackground()),
                  Positioned.fill(child: _CloudsLayer(enabled: _cloudsMoving)),
                  Positioned.fill(
                    child: SafeArea(
                      child: Column(
                        children: [
                          const _TopBar(),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.only(top: 6),
                            color: const Color(0xFFE5E7EB),
                          ),
                          SizedBox(height: 50 * scale),
                          _TimeCard(now: _now),
                          SizedBox(height: 8 * scale),
                          Text(
                            _formatDate(_now),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          _ProfilePhoto(
                            photoBytes: profile.photoBytes,
                            radius: photoRadius,
                            padding: photoPadding,
                          ),
                          SizedBox(height: 18 * scale),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _ProfileCard(
                                profile: profile,
                                displayName: displayName,
                                scale: scale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const List<String> weekdays = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];
  const List<String> months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final String weekday = weekdays[date.weekday - 1];
  final String month = months[date.month - 1];
  return '$weekday, ${date.day} $month ${date.year}';
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFFB6232E),
          ),
          const SizedBox(width: 12),
          Text(
            'TIU VIRTUAL',
            style: GoogleFonts.bebasNeue(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.1,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final String time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDCD8FF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.photoBytes,
    required this.radius,
    required this.padding,
  });

  final Uint8List? photoBytes;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF0F2FF),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFCBD5F5),
        backgroundImage: photoBytes == null ? null : MemoryImage(photoBytes!),
        child: photoBytes == null
            ? Icon(Icons.person, size: radius * 0.92, color: Colors.white)
            : null,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.displayName,
    required this.scale,
  });

  final Profile profile;
  final String displayName;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(18, 0, 18, 20 * scale),
      padding:
          EdgeInsets.fromLTRB(24 * scale, 28 * scale, 24 * scale, 22 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              final double nameFontSize =
                  (MediaQuery.of(context).size.width * 0.080).clamp(28.0, 51.0);
              return Text(
                displayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  fontSize: nameFontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.05,
                  letterSpacing: nameFontSize * 0.055,
                  color: const Color(0xFFE30613),
                ),
              );
            },
          ),
          SizedBox(height: 10 * scale),
          const Text(
            'Codigo de alumno:',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
          Text(
            profile.studentCode.toLowerCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8 * scale),
          const Text(
            'ID Banner:',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
          Text(
            profile.bannerId.toUpperCase(),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 12 * scale),
          Text(
            profile.major.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 8 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 16, color: Color(0xFFB6232E)),
              const SizedBox(width: 4),
              Text(
                profile.campus,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileDrawer extends StatelessWidget {
  const _EditProfileDrawer({
    required this.profiles,
    required this.activeIndex,
    required this.nameController,
    required this.majorController,
    required this.studentCodeController,
    required this.bannerIdController,
    required this.campusController,
    required this.photoBytes,
    required this.cloudsMoving,
    required this.maskLastNames,
    required this.onPickPhoto,
    required this.onSaveExisting,
    required this.onSaveNew,
    required this.onToggleClouds,
    required this.onToggleMask,
    required this.onSelectProfile,
  });

  final List<Profile> profiles;
  final int activeIndex;
  final TextEditingController nameController;
  final TextEditingController majorController;
  final TextEditingController studentCodeController;
  final TextEditingController bannerIdController;
  final TextEditingController campusController;
  final Uint8List? photoBytes;
  final bool cloudsMoving;
  final bool maskLastNames;
  final VoidCallback onPickPhoto;
  final VoidCallback onSaveExisting;
  final VoidCallback onSaveNew;
  final ValueChanged<bool> onToggleClouds;
  final ValueChanged<bool> onToggleMask;
  final ValueChanged<int> onSelectProfile;

  @override
  Widget build(BuildContext context) {
    final String selectedCampus =
        _TiuVirtualScreenState._campusOptions.contains(campusController.text)
            ? campusController.text
            : _TiuVirtualScreenState._campusOptions.first;
    return Drawer(
      width: 340,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar perfil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFCBD5F5),
                      backgroundImage:
                          photoBytes == null ? null : MemoryImage(photoBytes!),
                      child: photoBytes == null
                          ? const Icon(Icons.person,
                              size: 42, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: onPickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: cloudsMoving,
                        onChanged: onToggleClouds,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Movimiento de nubes'),
                      ),
                      SwitchListTile(
                        value: maskLastNames,
                        onChanged: onToggleMask,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Censurar apellidos'),
                      ),
                      const SizedBox(height: 6),
                      _EditField(
                          label: 'Nombre completo', controller: nameController),
                      _EditField(label: 'Carrera', controller: majorController),
                      _EditField(
                        label: 'Codigo de alumno',
                        controller: studentCodeController,
                      ),
                      _EditField(
                        label: 'ID Banner',
                        controller: bannerIdController,
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedCampus,
                        decoration: InputDecoration(
                          labelText: 'Campus',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _TiuVirtualScreenState._campusOptions
                            .map((campus) => DropdownMenuItem<String>(
                                  value: campus,
                                  child: Text(campus),
                                ))
                            .toList(),
                        onChanged: (value) {
                          campusController.text = value ??
                              _TiuVirtualScreenState._campusOptions.first;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onSaveExisting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB6232E),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Guardar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onSaveNew,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Guardar como nuevo'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Perfiles guardados',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final Profile profile = profiles[index];
                          final bool isActive = index == activeIndex;
                          return InkWell(
                            onTap: () => onSelectProfile(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFEEF2FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFFB6232E)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFCBD5F5),
                                    backgroundImage: profile.photoBytes == null
                                        ? null
                                        : MemoryImage(profile.photoBytes!),
                                    child: profile.photoBytes == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      profile.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

class _SkyBackground extends StatelessWidget {
  const _SkyBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFF5F3FB)),
        Positioned.fill(
          child: Image.asset(
            'assets/images/background_upc.png',
            fit: BoxFit.fitWidth,
            alignment: const Alignment(0.0, 0.28),
          ),
        ),
      ],
    );
  }
}

class _CloudsLayer extends StatefulWidget {
  const _CloudsLayer({required this.enabled});

  final bool enabled;

  @override
  State<_CloudsLayer> createState() => _CloudsLayerState();
}

class _CloudsLayerState extends State<_CloudsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CloudsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double t = widget.enabled ? _controller.value : 0.0;
            return Stack(
              children: [
                _cloud(
                  width: width,
                  baseX: 0.12,
                  speed: 0.35,
                  top: 120,
                  scale: 1.0,
                  t: t,
                ),
                _cloud(
                  width: width,
                  baseX: 0.55,
                  speed: 0.2,
                  top: 200,
                  scale: 0.75,
                  t: t,
                ),
                _cloud(
                  width: width,
                  baseX: 0.82,
                  speed: 0.3,
                  top: 280,
                  scale: 0.9,
                  t: t,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Positioned _cloud({
    required double width,
    required double baseX,
    required double speed,
    required double top,
    required double scale,
    required double t,
  }) {
    final double cloudWidth = 140 * scale;
    final double travel = width + cloudWidth;
    final double offset = (t * speed * travel + baseX * travel) % travel;
    final double left = offset - cloudWidth;

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: 0.9,
        child: Image.asset(
          'assets/images/cloud.png',
          width: cloudWidth,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
