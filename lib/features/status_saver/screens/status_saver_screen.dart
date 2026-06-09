import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_16kb/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_16kb/return_code.dart';

class StatusSaverScreen extends StatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  State<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends State<StatusSaverScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _permissionDenied = false;

  List<StatusItem> _imageStatuses = [];
  List<StatusItem> _videoStatuses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatuses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });

    if (kIsWeb) {
      setState(() {
        _imageStatuses = [];
        _videoStatuses = [];
        _loading = false;
      });
      return;
    }

    if (Platform.isAndroid) {
      // Proactively request storage permission on older Android devices (pre-13),
      // but do not block if it returns denied (especially on Android 13+ / 16 where it is deprecated/fails).
      try {
        await Permission.storage.request();
      } catch (e) {
        debugPrint('Storage permission request error: $e');
      }
    }

    try {
      final List<String> searchPaths = [
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
        '/storage/emulated/0/WhatsApp/Media/.Statuses',
        '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
        '/storage/emulated/0/Android/media/com.gbwhatsapp/GBWhatsApp/Media/.Statuses',
      ];

      List<File> imageFiles = [];
      List<File> videoFiles = [];
      bool successfullyReadAny = false;
      bool hasPermissionError = false;

      for (final p in searchPaths) {
        final dir = Directory(p);
        if (await dir.exists()) {
          try {
            final List<FileSystemEntity> entities = dir.listSync();
            successfullyReadAny = true;
            for (final entity in entities) {
              if (entity is File) {
                final path = entity.path.toLowerCase();
                if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
                  imageFiles.add(entity);
                } else if (path.endsWith('.mp4') || path.endsWith('.gif')) {
                  videoFiles.add(entity);
                }
              }
            }
          } catch (e) {
            debugPrint('Failed to list WhatsApp statuses directory $p: $e');
            hasPermissionError = true;
          }
        }
      }

      if (!successfullyReadAny && hasPermissionError) {
        setState(() {
          _permissionDenied = true;
        });
      }

      setState(() {
        _imageStatuses = imageFiles
            .map((f) => StatusItem(path: f.path, isLocal: true, isVideo: false))
            .toList();
        _videoStatuses = videoFiles
            .map((f) => StatusItem(path: f.path, isLocal: true, isVideo: true))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading native statuses: $e');
      setState(() {
        _imageStatuses = [];
        _videoStatuses = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveStatus(StatusItem item) async {
    // Show saving progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String? tempFilePath;

    try {
      // Request gallery access (iOS only, Android uses MediaStore with no runtime permissions required)
      if (Platform.isIOS) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted) {
            Navigator.pop(context); // Pop loader
            _showError('Gallery permission is required to save statuses.');
            return;
          }
        }
      }

      String filePath = item.path;

      // Copy or download to app temporary directory first to avoid sharing/permission restrictions
      final tempDir = await getTemporaryDirectory();
      final extension = item.isVideo ? "mp4" : "jpg";
      tempFilePath = '${tempDir.path}/temp_status_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      if (item.isLocal) {
        final localFile = File(item.path);
        if (await localFile.exists()) {
          await localFile.copy(tempFilePath);
          filePath = tempFilePath;
        } else {
          throw Exception('Local status file does not exist.');
        }
      } else {
        // In simulator mode, download mock file first
        final response = await http.get(Uri.parse(item.path));
        if (response.statusCode == 200) {
          final file = File(tempFilePath);
          await file.writeAsBytes(response.bodyBytes);
          filePath = tempFilePath;
        } else {
          throw Exception('Failed to download mock status file.');
        }
      }

      // Save using gal to album "Media Mate"
      if (item.isVideo) {
        await Gal.putVideo(filePath, album: 'Media Mate');
      } else {
        await Gal.putImage(filePath, album: 'Media Mate');
      }

      Navigator.pop(context); // Pop loader
      _showSuccess(
        item.isVideo
            ? 'Video saved to Gallery under "Media Mate" album.'
            : 'Image saved to Gallery under "Media Mate" album.'
      );
    } catch (e) {
      Navigator.pop(context); // Pop loader
      debugPrint('Save status error: $e');
      _showError('Failed to save status. Error: $e');
    } finally {
      // Clean up temp file
      try {
        if (tempFilePath != null && await File(tempFilePath).exists()) {
          await File(tempFilePath).delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _shareStatus(StatusItem item) async {
    try {
      String sharePath = item.path;
      bool needDelete = false;

      if (!item.isLocal) {
        // Download first to share
        final tempDir = await getTemporaryDirectory();
        final filename = 'share_status_${DateTime.now().millisecondsSinceEpoch}.${item.isVideo ? "mp4" : "jpg"}';
        final tempPath = '${tempDir.path}/$filename';

        final response = await http.get(Uri.parse(item.path));
        final file = File(tempPath);
        await file.writeAsBytes(response.bodyBytes);
        sharePath = tempPath;
        needDelete = true;
      }

      final xFile = XFile(sharePath);
      await Share.shareXFiles([xFile], text: 'Shared via Media Mate');

      if (needDelete) {
        await File(sharePath).delete();
      }
    } catch (e) {
      debugPrint('Share error: $e');
      _showError('Failed to share status: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
    ));
  }

  void _previewStatus(StatusItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StatusPreviewScreen(
          item: item,
          onSave: () => _saveStatus(item),
          onShare: () => _shareStatus(item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WhatsApp Status Saver',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.image_outlined), text: 'Images'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Videos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatuses,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _permissionDenied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, size: 64, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Storage Permission Required',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Storage permission is required to search and save your viewed WhatsApp statuses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadStatuses,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Grant Permission'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatusGrid(_imageStatuses),
                    _buildStatusGrid(_videoStatuses),
                  ],
                ),
    );
  }

  Widget _buildStatusGrid(List<StatusItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No statuses found',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open WhatsApp, view some of your friends\' statuses, and then check back here!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _previewStatus(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image view or Video thumbnail
                item.isVideo
                    ? (item.isLocal
                        ? VideoThumbnailWidget(videoPath: item.path)
                        : const Center(child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white)))
                    : (item.isLocal
                        ? Image.file(
                            File(item.path),
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            item.path,
                            fit: BoxFit.cover,
                          )),

                // Video play overlay
                if (item.isVideo)
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                // Quick download button overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white, size: 20),
                      onPressed: () => _saveStatus(item),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StatusItem {
  final String path;
  final bool isLocal;
  final bool isVideo;
  final String? title;

  StatusItem({
    required this.path,
    required this.isLocal,
    required this.isVideo,
    this.title,
  });
}

class StatusPreviewScreen extends StatefulWidget {
  final StatusItem item;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const StatusPreviewScreen({
    super.key,
    required this.item,
    required this.onSave,
    required this.onShare,
  });

  @override
  State<StatusPreviewScreen> createState() => _StatusPreviewScreenState();
}

class _StatusPreviewScreenState extends State<StatusPreviewScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo) {
      _initVideo();
    }
  }

  void _initVideo() {
    _videoController = widget.item.isLocal
        ? VideoPlayerController.file(File(widget.item.path))
        : VideoPlayerController.network(widget.item.path);

    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _videoController!.play();
        _videoController!.setLooping(true);
        _isPlaying = true;
      }
    }).catchError((error) {
      debugPrint("Error initializing video player: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not play video status: $error")),
        );
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.item.title ?? 'Status Preview',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: widget.onShare,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: widget.onSave,
          ),
        ],
      ),
      body: Center(
        child: widget.item.isVideo
            ? (_videoController != null && _videoController!.value.isInitialized
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                        _isPlaying = !_isPlaying;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        if (!_isPlaying)
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator())
            : (widget.item.isLocal
                ? Image.file(
                    File(widget.item.path),
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    widget.item.path,
                    fit: BoxFit.contain,
                  )),
      ),
    );
  }
}

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  const VideoThumbnailWidget({super.key, required this.videoPath});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _thumbnailPath = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final filename = 'thumb_${widget.videoPath.hashCode}.jpg';
      final thumbFile = File('${tempDir.path}/$filename');

      if (await thumbFile.exists()) {
        if (mounted) {
          setState(() {
            _thumbnailPath = thumbFile.path;
            _loading = false;
          });
        }
        return;
      }

      // Extract a frame from the video using FFmpeg (output-seeking at start of video)
      final cmd = '-y -i "${widget.videoPath}" -ss 00:00:00 -vframes 1 -vf "scale=320:-1" "${thumbFile.path}"';
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && await thumbFile.exists()) {
        if (mounted) {
          setState(() {
            _thumbnailPath = thumbFile.path;
            _loading = false;
          });
        }
      } else {
        final logs = await session.getLogsAsString();
        debugPrint('FFmpeg video thumbnail generation failed: $logs');
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint("Error generating video thumbnail: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_thumbnailPath != null) {
      return Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(Icons.video_library, color: Colors.white30, size: 40),
      ),
    );
  }
}
