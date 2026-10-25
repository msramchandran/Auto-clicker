import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'services/location_nearby_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Location Profile Model
// ─────────────────────────────────────────────────────────────────────────────

class LocationProfile {
  String id;
  String name;
  String locations;
  bool isActive;

  LocationProfile({
    required this.id,
    required this.name,
    required this.locations,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locations': locations,
        'isActive': isActive,
      };

  factory LocationProfile.fromJson(Map<String, dynamic> json) =>
      LocationProfile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        locations: json['locations'] ?? '',
        isActive: json['isActive'] ?? false,
      );

  LocationProfile copy() => LocationProfile(
        id: id,
        name: name,
        locations: locations,
        isActive: isActive,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Profiles Management Page
// ─────────────────────────────────────────────────────────────────────────────

class LocationProfilesPage extends StatefulWidget {
  final List<LocationProfile> profiles;
  final bool isTamil;
  final bool isDarkMode;

  const LocationProfilesPage({
    super.key,
    required this.profiles,
    this.isTamil = false,
    this.isDarkMode = true,
  });

  @override
  State<LocationProfilesPage> createState() => _LocationProfilesPageState();
}

class _LocationProfilesPageState extends State<LocationProfilesPage> {
  static const _channel = MethodChannel('com.example.autoclicker/accessibility');
  late List<LocationProfile> _profiles;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool get isDark => widget.isDarkMode;

  @override
  void initState() {
    super.initState();
    _profiles = widget.profiles.map((p) => p.copy()).toList();
  }

  String _t(String en, String ta) => widget.isTamil ? ta : en;

  Future<void> _saveAndApply() async {
    setState(() => _isSaving = true);

    final jsonStr = jsonEncode(_profiles.map((p) => p.toJson()).toList());

    // Clean and collect active locations
    final activeLocsList = <String>[];
    for (final p in _profiles) {
      if (p.isActive) {
        final split = p.locations
            .split(RegExp(r'[,;\n]'))
            .map((s) => s.trim())
            .filter((s) => s.isNotEmpty);
        activeLocsList.addAll(split);
      }
    }
    final activeLocations = activeLocsList.join(',');

    try {
      await _channel.invokeMethod('setLocationProfiles', {
        'profilesJson': jsonStr,
        'activeLocations': activeLocations,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locationProfiles', jsonStr);
      await prefs.setString('global_active_locations', activeLocations);
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _hasUnsavedChanges = false;
      _isSaving = false;
    });

    final activeNames = _profiles.where((p) => p.isActive).map((p) => p.name).toList();
    final msg = activeNames.isEmpty
        ? _t('All profiles turned OFF. Location mode paused.', 'அனைத்து ப்ரொஃபைல்களும் ஆஃப் செய்யப்பட்டன.')
        : _t('Saved! Active: ${activeNames.join(", ")}', 'சேமிக்கப்பட்டது! செயலில் உள்ளவை: ${activeNames.join(", ")}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, _profiles);
  }

  void _addOrEditProfile([LocationProfile? profile]) {
    final isEditing = profile != null;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final inputCtrl = TextEditingController();

    // Parse existing locations into a list for chip boxes
    final List<String> locationsList = profile != null && profile.locations.isNotEmpty
        ? profile.locations
            .split(RegExp(r'[,;\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : [];

    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListening = false;

    // Nearby suggestions state
    List<NearbyLocation> nearbySuggestions = [];
    bool isSearchingNearby = false;
    String lastSearchedArea = '';
    Timer? debounceTimer;
    bool initialLoaded = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void fetchNearby(String rawArea) async {
              final clean = rawArea.trim().replaceAll(RegExp(r'[,;\n]'), '');
              if (clean.length < 3) return;

              setDialogState(() {
                isSearchingNearby = true;
                lastSearchedArea = clean;
              });

              try {
                final results = await LocationNearbyService.getNearby(clean, limit: 15);
                setDialogState(() {
                  nearbySuggestions = results;
                  isSearchingNearby = false;
                });
              } catch (_) {
                setDialogState(() {
                  isSearchingNearby = false;
                });
              }
            }

            // Auto-load nearby for the last existing location on dialog open
            if (!initialLoaded) {
              initialLoaded = true;
              if (locationsList.isNotEmpty) {
                Future.microtask(() => fetchNearby(locationsList.last));
              }
            }

            void addArea(String rawText, {bool autoFetchNearby = true}) {
              if (rawText.trim().isEmpty) return;
              final parts = rawText.split(RegExp(r'[,;\n]'));
              bool added = false;
              String? lastAdded;
              for (final part in parts) {
                final trimmed = part.trim();
                if (trimmed.isNotEmpty &&
                    !locationsList.any((l) => l.toLowerCase() == trimmed.toLowerCase())) {
                  locationsList.add(trimmed);
                  added = true;
                  lastAdded = trimmed;
                }
              }
              if (added) {
                inputCtrl.clear();
                setDialogState(() {});
                if (autoFetchNearby && lastAdded != null) {
                  fetchNearby(lastAdded);
                }
              }
            }

            void addAllNearby() {
              bool added = false;
              for (final item in nearbySuggestions) {
                if (!locationsList.any((l) => l.toLowerCase() == item.name.toLowerCase())) {
                  locationsList.add(item.name);
                  added = true;
                }
              }
              if (added) {
                setDialogState(() {});
              }
            }

            void listen() async {
              if (!isListening) {
                bool available = await speech.initialize(
                  onStatus: (val) {
                    if (val == 'done' || val == 'notListening') {
                      setDialogState(() => isListening = false);
                    }
                  },
                  onError: (val) {
                    setDialogState(() => isListening = false);
                  },
                );
                if (available) {
                  setDialogState(() => isListening = true);
                  speech.listen(
                    onResult: (val) {
                      if (val.recognizedWords.isNotEmpty) {
                        addArea(val.recognizedWords);
                      }
                    },
                    localeId: widget.isTamil ? 'ta_IN' : 'en_IN',
                  );
                }
              } else {
                setDialogState(() => isListening = false);
                speech.stop();
              }
            }

            final unaddedCount = nearbySuggestions
                .where((item) => !locationsList.any((l) => l.toLowerCase() == item.name.toLowerCase()))
                .length;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEditing
                    ? _t('Edit Location Profile', 'ப்ரொஃபைலைத் திருத்து')
                    : _t('Add Location Profile', 'புதிய ப்ரொஃபைல் சேர்'),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                        decoration: InputDecoration(
                          labelText: _t('Profile Name (e.g. HOME, WORK)', 'பெயர் (எ.கா: HOME, WORK)'),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          hintText: 'e.g., HOME, PEAK HOURS',
                          hintStyle: const TextStyle(color: Colors.white30),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFCC00))),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Area Input with Comma Trigger, (+) Add Button & Mic & Nearby Radar
                      TextField(
                        controller: inputCtrl,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
                        onChanged: (val) {
                          if (val.contains(',')) {
                            addArea(val);
                          } else {
                            debounceTimer?.cancel();
                            if (val.trim().length >= 3) {
                              debounceTimer = Timer(const Duration(milliseconds: 400), () {
                                fetchNearby(val);
                              });
                            }
                          }
                        },
                        onSubmitted: (val) {
                          addArea(val);
                        },
                        decoration: InputDecoration(
                          labelText: _t('Add Drop Location (type & put comma)', 'இடத்தை டைப் செய்து கமா (,) போடவும்'),
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          hintText: 'e.g. Vadapalani, Tambaram, Avadi',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFCC00))),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.radar, color: Color(0xFFFFCC00)),
                                tooltip: _t('Find Nearby Areas', 'அருகிலுள்ள இடங்களைத் தேடு'),
                                onPressed: () {
                                  if (inputCtrl.text.trim().isNotEmpty) {
                                    fetchNearby(inputCtrl.text);
                                  } else if (locationsList.isNotEmpty) {
                                    fetchNearby(locationsList.last);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Color(0xFFFFCC00)),
                                tooltip: _t('Add Location', 'சேர்'),
                                onPressed: () {
                                  addArea(inputCtrl.text);
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  isListening ? Icons.mic : Icons.mic_none,
                                  color: isListening ? Colors.redAccent : const Color(0xFFFFCC00),
                                ),
                                tooltip: _t('Voice Input', 'பேசி சேர்க்க'),
                                onPressed: listen,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isListening)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _t('Listening... Speak area name', 'கேட்கிறது... ஏரியா பெயரைப் பேசவும்'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),

                      // ── NEARBY SURROUNDING AREAS SECTION ──────────────────────
                      if (isSearchingNearby) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E4E8)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFCC00)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _t('Searching areas near "$lastSearchedArea"...',
                                      '"$lastSearchedArea" அருகிலுள்ள இடங்களைத் தேடுகிறது...'),
                                  style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (nearbySuggestions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14191F) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.near_me, size: 15, color: Color(0xFFFFCC00)),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            _t('Near "$lastSearchedArea" (${nearbySuggestions.length}):',
                                                '"$lastSearchedArea" அருகில் (${nearbySuggestions.length}):'),
                                            style: const TextStyle(
                                              color: Color(0xFFFFCC00),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (unaddedCount > 0)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFCC00),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        minimumSize: const Size(0, 26),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.playlist_add_check, size: 14),
                                      label: Text(
                                        _t('Add All ($unaddedCount)', 'அனைத்தும் சேர் ($unaddedCount)'),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: addAllNearby,
                                    )
                                  else
                                    Text(
                                      _t('✓ All added', '✓ அனைத்தும் சேர்க்கப்பட்டது'),
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 130),
                                child: SingleChildScrollView(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: nearbySuggestions.map((item) {
                                      final isAlreadyAdded = locationsList.any(
                                        (l) => l.toLowerCase() == item.name.toLowerCase(),
                                      );
                                      final distStr = item.distanceKm != null
                                          ? '${item.distanceKm!.toStringAsFixed(1)} km'
                                          : '';
                                      return InkWell(
                                        onTap: isAlreadyAdded
                                            ? null
                                            : () {
                                                addArea(item.name, autoFetchNearby: false);
                                              },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isAlreadyAdded
                                                ? (isDark ? const Color(0xFF1B2E1E) : const Color(0xFFE8F5E9))
                                                : (isDark ? const Color(0xFF222222) : Colors.white),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isAlreadyAdded
                                                  ? Colors.green.withOpacity(0.5)
                                                  : const Color(0xFFFFCC00).withOpacity(0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isAlreadyAdded ? Icons.check_circle : Icons.add_circle_outline,
                                                size: 13,
                                                color: isAlreadyAdded ? Colors.greenAccent : const Color(0xFFFFCC00),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.name,
                                                style: TextStyle(
                                                  color: isAlreadyAdded ? (isDark ? Colors.white60 : const Color(0xFF2E7D32)) : (isDark ? Colors.white : const Color(0xFF111827)),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (distStr.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  distStr,
                                                  style: TextStyle(
                                                    color: isAlreadyAdded
                                                        ? Colors.white38
                                                        : const Color(0xFFFFCC00).withOpacity(0.8),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Chip Boxes with Cancel (X) Button
                      if (locationsList.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _t('Added Locations (${locationsList.length}):', 'சேர்க்கப்பட்ட இடங்கள் (${locationsList.length}):'),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  locationsList.clear();
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 20),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _t('Clear All', 'அனைத்தும் நீக்கு'),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141414) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E4E8)),
                          ),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: locationsList.asMap().entries.map((entry) {
                                final index = entry.key;
                                final loc = entry.value;
                                return InkWell(
                                  onTap: () => fetchNearby(loc),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF262626) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.place, size: 14, color: Color(0xFFFFCC00)),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 150),
                                          child: Text(
                                            loc,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            setDialogState(() {
                                              locationsList.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 13,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.white38),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _t('Type area name & add comma (,) to make it a box tag with (X) remove. Tap any tag to see nearby areas.',
                                      'ஏரியா பெயரை டைப் செய்து கமா (,) போட்டால் (X) நீக்கும் பாக்ஸாக மாறும். எந்த டேக்கையும் தொட்டால் அதன் அருகிலுள்ள இடங்களைக் காணலாம்.'),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    debounceTimer?.cancel();
                    speech.stop();
                    Navigator.pop(context);
                  },
                  child: Text(_t('CANCEL', 'ரத்து செய்'), style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    debounceTimer?.cancel();
                    // Include any un-submitted text in the input box
                    if (inputCtrl.text.trim().isNotEmpty) {
                      addArea(inputCtrl.text.trim(), autoFetchNearby: false);
                    }

                    final name = nameCtrl.text.trim();
                    if (name.isEmpty || locationsList.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _t('Please enter profile name and add at least one location.',
                                'பெயர் மற்றும் குறைந்தது ஒரு இடமாவது சேர்க்கவும்.'),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final locs = locationsList.join(', ');
                    speech.stop();
                    setState(() {
                      if (isEditing) {
                        profile.name = name;
                        profile.locations = locs;
                      } else {
                        _profiles.add(LocationProfile(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          locations: locs,
                          isActive: false, // Default newly created profile to inactive until toggled & saved
                        ));
                      }
                      _hasUnsavedChanges = true;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(_t('DONE', 'சரி'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteProfile(LocationProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Delete Profile?', 'ப்ரொஃபைலை நீக்கவா?'), style: const TextStyle(color: Colors.white)),
        content: Text(
          _t('Are you sure you want to delete "${profile.name}"?', '"${profile.name}" ப்ரொஃபைலை நிச்சயம் நீக்க வேண்டுமா?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('CANCEL', 'ரத்து'), style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _profiles.remove(profile);
                _hasUnsavedChanges = true;
              });
            },
            child: Text(_t('DELETE', 'நீக்கு')),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Unsaved Changes', 'சேமிக்கப்படாத மாற்றங்கள்'), style: const TextStyle(color: Colors.white)),
        content: Text(
          _t('You have unsaved changes in your Location Profiles. Do you want to save before leaving?',
              'ப்ரொஃபைல்களில் மாற்றங்கள் செய்யப்பட்டுள்ளன. வெளியேறுவதற்கு முன் சேமிக்க வேண்டுமா?'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // Discard
            child: Text(_t('DISCARD', 'கைவிடு'), style: const TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx, false);
              _saveAndApply();
            },
            child: Text(_t('SAVE & EXIT', 'சேமித்து வெளியேறு'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _profiles.where((p) => p.isActive).length;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6F7F9),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
          elevation: isDark ? 0 : 0.5,
          title: Text(
            _t('Location Profiles', 'இட விவரங்கள் (Profiles)'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_hasUnsavedChanges)
              TextButton.icon(
                onPressed: _isSaving ? null : _saveAndApply,
                icon: const Icon(Icons.check_circle, color: Color(0xFFFFCC00), size: 18),
                label: Text(
                  _t('SAVE', 'சேமி'),
                  style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Status and Guidance Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: activeCount > 0 ? (isDark ? const Color(0xFF152A15) : const Color(0xFFE8F5E9)) : (isDark ? const Color(0xFF2A2000) : const Color(0xFFFFFBEB)),
                border: Border(
                  bottom: BorderSide(
                    color: activeCount > 0 ? const Color(0xFF00C853).withOpacity(0.4) : const Color(0xFFFFCC00).withOpacity(0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    activeCount > 0 ? Icons.check_circle : Icons.info_outline,
                    color: activeCount > 0 ? const Color(0xFF00C853) : const Color(0xFFFFCC00),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeCount > 0
                              ? _t('$activeCount Profile(s) Active', '$activeCount ப்ரொஃபைல்கள் செயலில் உள்ளன')
                              : _t('No Profile Active', 'எந்த ப்ரொஃபைலும் செயலில் இல்லை'),
                          style: TextStyle(
                            color: activeCount > 0 ? const Color(0xFF00C853) : const Color(0xFFFFCC00),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('Toggle profiles and press "SAVE ACTIVE PROFILES" below.',
                              'ப்ரொஃபைல்களை ஆன் செய்து கீழே உள்ள "SAVE" பட்டனை அழுத்தவும்.'),
                          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF4B5563), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_hasUnsavedChanges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade900.withOpacity(0.4),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFCC00), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t('You have unsaved changes. Tap "SAVE ACTIVE PROFILES" below to apply.',
                            'சேமிக்கப்படாத மாற்றங்கள் உள்ளன. கீழே உள்ள SAVE பட்டனைத் தட்டவும்.'),
                        style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Profile List
            Expanded(
              child: _profiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.place_outlined, size: 64, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text(
                            _t('No location profiles added yet.', 'இன்னும் ப்ரொஃபைல் சேர்க்கப்படவில்லை.'),
                            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t('Tap "+ Add Profile" to create one (e.g. HOME, WORK).',
                                'புதிய ப்ரொஃபைல் உருவாக்க கீழே உள்ள பட்டனைத் தொடவும்.'),
                            style: TextStyle(color: isDark ? Colors.white30 : const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return _buildProfileCard(profile);
                      },
                    ),
            ),
          ],
        ),

        // Bottom Action Bar
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E4E8))),
          ),
          child: Row(
            children: [
              // Add Profile Button
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () => _addOrEditProfile(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_t('Add', 'புதியது')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFCC00),
                    side: const BorderSide(color: Color(0xFFFFCC00)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAndApply,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(
                    _t('SAVE ACTIVE PROFILES', 'சேமி (SAVE)'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: _hasUnsavedChanges ? 4 : 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(LocationProfile profile) {
    final locsList = profile.locations
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .filter((s) => s.isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: profile.isActive ? const Color(0xFF00C853) : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E4E8)),
          width: profile.isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: profile.isActive ? const Color(0xFF00C853).withOpacity(0.15) : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 18,
                    color: profile.isActive ? const Color(0xFF00C853) : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: profile.isActive ? (isDark ? Colors.white : const Color(0xFF111827)) : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                        ),
                      ),
                      Text(
                        profile.isActive
                            ? _t('🟢 ACTIVE (Will accept drops)', '🟢 ஆக்டிவ் (சவாரிகளை ஏற்கும்)')
                            : _t('⚪ OFF (Will ignore drops)', '⚪ ஆஃப் (சவாரிகளை ஏற்காது)'),
                        style: TextStyle(
                          fontSize: 11,
                          color: profile.isActive ? const Color(0xFF00C853) : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                          fontWeight: profile.isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                  onPressed: () => _addOrEditProfile(profile),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _t('Edit', 'திருத்து'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _deleteProfile(profile),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _t('Delete', 'நீக்கு'),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: profile.isActive,
                  activeColor: const Color(0xFF00C853),
                  activeTrackColor: const Color(0xFF00C853).withOpacity(0.3),
                  inactiveThumbColor: const Color(0xFF888888),
                  inactiveTrackColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD1D5DB),
                  onChanged: (val) {
                    setState(() {
                      profile.isActive = val;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
            Divider(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8), height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: locsList.map((loc) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.isActive ? (isDark ? const Color(0xFF152A15) : const Color(0xFFE8F5E9)) : (isDark ? const Color(0xFF252525) : const Color(0xFFF1F3F6)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: profile.isActive ? const Color(0xFF00C853).withOpacity(0.3) : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB)),
                    ),
                  ),
                  child: Text(
                    loc,
                    style: TextStyle(
                      fontSize: 11,
                      color: profile.isActive ? (isDark ? Colors.white : const Color(0xFF1B5E20)) : (isDark ? Colors.white60 : const Color(0xFF4B5563)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

extension IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
