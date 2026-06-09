import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../../../core/language_provider.dart';

class AddMusicScreen extends StatefulWidget {
  const AddMusicScreen({super.key});

  @override
  State<AddMusicScreen> createState() => _AddMusicScreenState();
}

class _AddMusicScreenState extends State<AddMusicScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  File? _selectedImage;
  String? _selectedAudioPath;
  String? _selectedAudioName;
  bool _isOnlineAudio = false;

  double _durationSeconds = 15.0; // Export video length (s)
  bool _isPlaying = false;
  bool _exporting = false;
  double _exportProgress = 0.0;
  String _exportStatus = '';

  late AnimationController _visualizerController;

  // Royalty-free loop presets (direct stable mp3 links)
  final List<MusicPreset> _presets = [
    MusicPreset(
      name: 'Chill Lofi Loop',
      artist: 'Media Mate Beats',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3', // Streamable loop
    ),
    MusicPreset(
      name: 'Acoustic Folk Jam',
      artist: 'Guitar Acoustic',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    MusicPreset(
      name: 'Ambient Piano Breeze',
      artist: 'Melancholic Piano',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];

  MusicPreset? _activePreset;

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) {
            _visualizerController.repeat(reverse: true);
          } else {
            _visualizerController.stop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _visualizerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _pickAudioLocal() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await _audioPlayer.stop();
        setState(() {
          _selectedAudioPath = result.files.single.path;
          _selectedAudioName = result.files.single.name;
          _isOnlineAudio = false;
          _activePreset = null;
        });

        // Set player source and play it
        await _audioPlayer.setSourceDeviceFile(_selectedAudioPath!);
        await _audioPlayer.play(DeviceFileSource(_selectedAudioPath!));
      }
    } catch (e) {
      _showError('Error picking audio: $e');
    }
  }

  Future<void> _selectPreset(MusicPreset preset) async {
    await _audioPlayer.stop();
    setState(() {
      _activePreset = preset;
      _selectedAudioPath = preset.url;
      _selectedAudioName = preset.name;
      _isOnlineAudio = true;
    });

    await _audioPlayer.setSourceUrl(preset.url);
    await _audioPlayer.play(UrlSource(preset.url));
  }

  void _loadAudioFromLink() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Audio from Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a direct link to an MP3 or WAV file on the internet:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://example.com/soundtrack.mp3',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
                Navigator.pop(context);
                _selectCustomLink(url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid HTTP/HTTPS URL')),
                );
              }
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomLink(String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _audioPlayer.stop();

      await _audioPlayer.setSourceUrl(url);
      await _audioPlayer.play(UrlSource(url));

    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'online_audio.mp3';

    setState(() {
      _selectedAudioPath = url;
      _isOnlineAudio = true;
      _selectedAudioName = fileName;
      _activePreset = MusicPreset(
        name: fileName,
        artist: 'Internet Link',
        url: url,
      );
    });
      
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully loaded internet audio: $fileName')),
    );
    } catch (e) {
      debugPrint('Error loading audio from link: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load audio: $e')),
      );
    } finally {
      Navigator.pop(context);
    }
  }

  Future<void> _togglePlay() async {
    if (_selectedAudioPath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_isOnlineAudio) {
        await _audioPlayer.play(UrlSource(_selectedAudioPath!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_selectedAudioPath!));
      }
    }
  }

  Future<void> _startExport() async {
    if (_selectedImage == null) {
      _showError('Please select a background image first.');
      return;
    }
    if (_selectedAudioPath == null) {
      _showError('Please select background music first.');
      return;
    }

    // Stop playback
    await _audioPlayer.stop();

    setState(() {
      _exporting = true;
      _exportProgress = 0.0;
      _exportStatus = 'Preparing media files...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      String finalAudioPath = _selectedAudioPath!;

      if (_isOnlineAudio) {
        setState(() => _exportStatus = 'Downloading soundtrack (15%)...');
        // Download online soundtrack preset to local temp file before FFmpeg compile
        final filename = 'preset_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final tempPath = '${tempDir.path}/$filename';
        
        final response = await http.get(Uri.parse(_selectedAudioPath!));
        if (response.statusCode == 200) {
          final file = File(tempPath);
          await file.writeAsBytes(response.bodyBytes);
          finalAudioPath = tempPath;
        } else {
          throw Exception('Failed to download preset audio.');
        }
      }

      setState(() => _exportStatus = 'Merging image and soundtrack (FFmpeg)...');
      _exportProgress = 0.4;

      final outputFilename = 'media_mate_music_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final outputPath = '${tempDir.path}/$outputFilename';

      // 1. Force scale dimensions to be divisible by 2 to prevent libx264 crashes on odd image sizes
      // 2. Loop image frame and combine with audio
      final cmd = '-loop 1 -i "${_selectedImage!.path}" -i "$finalAudioPath" '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -t ${_durationSeconds.toInt()} '
          '-pix_fmt yuv420p -c:a aac -b:a 192k -shortest -y "$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      // Clean up temp online audio if downloaded
      if (_isOnlineAudio) {
        await File(finalAudioPath).delete();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _exportProgress = 0.9;
          _exportStatus = 'Saving compiled video to Gallery...';
        });

        // Save to Gallery under "Media Mate" album
        await Gal.putVideo(outputPath, album: 'Media Mate');
        await File(outputPath).delete();

        _showSuccess('Video with background music successfully saved to your Gallery under "Media Mate" album!');
      } else {
        final logs = await session.getLogsAsString();
        debugPrint('FFmpeg Error: $logs');
        throw Exception('FFmpeg compilation failed.');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      _showError('Failed to compile video. Error: $e');
    } finally {
      setState(() => _exporting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
        title: const Text('Export Completed!'),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, child) {
        final lang = ref.watch(languageProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Add Music to Images'.tr(lang),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Select Image Card
                    Text(
                      '1. Select Background Image'.tr(lang),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Choose Background Image'.tr(lang),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 2. Select Music Card
                    Text(
                      'Select Audio Track'.tr(lang),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Selected soundtrack indicator
                    if (_selectedAudioName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            // Visualizer pulses when playing
                            AnimatedBuilder(
                              animation: _visualizerController,
                              builder: (context, child) {
                                return Row(
                                  children: List.generate(4, (index) {
                                    final heights = [16.0, 24.0, 12.0, 20.0];
                                    double h = heights[index];
                                    if (_isPlaying) {
                                      h *= (0.3 + 0.7 * _visualizerController.value);
                                    }
                                    return Container(
                                      width: 3,
                                      height: h,
                                      margin: const EdgeInsets.only(right: 3),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAudioName!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    (_isOnlineAudio ? 'Online Preset' : 'Local Audio File').tr(lang),
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                              iconSize: 36,
                              color: theme.colorScheme.primary,
                              onPressed: _togglePlay,
                            ),
                          ],
                        ),
                      ),

                    // Audio pick button row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickAudioLocal,
                            icon: const Icon(Icons.folder_open),
                            label: Text('Choose local audio file'.tr(lang)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadAudioFromLink,
                            icon: const Icon(Icons.link),
                            label: Text('Load Audio from Link'.tr(lang)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sound Presets Label
                    Text(
                      'Or Choose Online Presets:'.tr(lang),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    // Music presets list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _presets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final preset = _presets[index];
                        final isSelected = _activePreset == preset;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          color: isSelected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15) : theme.colorScheme.surface,
                          child: ListTile(
                            onTap: () => _selectPreset(preset),
                            leading: Icon(
                              Icons.music_video_rounded,
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                            ),
                            title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(preset.artist, style: const TextStyle(fontSize: 12)),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                                : const Icon(Icons.arrow_forward_ios, size: 14),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // 3. Export settings card
                    Text(
                      '3. Export Settings'.tr(lang),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Video Duration'.tr(lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${_durationSeconds.toInt()} ' + 'Seconds'.tr(lang),
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Slider(
                              min: 5.0,
                              max: 30.0,
                              divisions: 5,
                              value: _durationSeconds,
                              onChanged: (val) {
                                setState(() => _durationSeconds = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Start Export button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _exporting ? null : _startExport,
                        icon: const Icon(Icons.video_library),
                        label: Text('Export Music Video'.tr(lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Export Progress HUD Overlay
              if (_exporting)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 24),
                            Text(
                              'Compiling Music Video...'.tr(lang),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _exportStatus,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: _exportProgress,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_exportProgress * 100).toInt()}% ' + 'Completed'.tr(lang),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MusicPreset {
  final String name;
  final String artist;
  final String url;

  MusicPreset({
    required this.name,
    required this.artist,
    required this.url,
  });
}
