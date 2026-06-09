import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

class YoutubeDownloaderScreen extends StatefulWidget {
  const YoutubeDownloaderScreen({super.key});

  @override
  State<YoutubeDownloaderScreen> createState() => _YoutubeDownloaderScreenState();
}

class _YoutubeDownloaderScreenState extends State<YoutubeDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();

  bool _fetching = false;
  Video? _videoInfo;
  StreamManifest? _streamManifest;
  List<StreamOption> _options = [];
  StreamOption? _selectedOption;

  bool _downloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';
  bool _isCancelled = false;
  bool _isBackgrounded = false;

  @override
  void dispose() {
    _urlController.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      setState(() {
        _urlController.text = clipboardData!.text!;
      });
      _fetchVideoInfo();
    }
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter or paste a YouTube URL.');
      return;
    }

    setState(() {
      _fetching = true;
      _videoInfo = null;
      _streamManifest = null;
      _options = [];
      _selectedOption = null;
    });

    try {
      // Parse video ID safely
      String? videoId;
      try {
        videoId = VideoId.parseVideoId(url);
      } catch (_) {
        // Handled below
      }

      if (videoId == null) {
        _showError('Invalid YouTube URL. Please check the link.');
        setState(() => _fetching = false);
        return;
      }

      // Fetch video metadata & stream manifest
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      final List<StreamOption> availableOptions = [];

      // 1. Check for 1080p video-only stream + best audio stream (requires FFmpeg muxing)
      final video1080Streams = manifest.videoOnly.where((v) => v.videoQualityLabel == '1080p').toList();
      StreamInfo? videoOnly1080;
      if (video1080Streams.isNotEmpty) {
        // Prioritize mp4 container with H.264 (avc) codec for performance & compatibility
        videoOnly1080 = video1080Streams.firstWhere(
          (v) => v.container.name == 'mp4' && v.videoCodec.toLowerCase().startsWith('avc'),
          orElse: () => video1080Streams.firstWhere(
            (v) => v.container.name == 'mp4',
            orElse: () => video1080Streams.first,
          ),
        );
      }
      final bestAudio = manifest.audioOnly.withHighestBitrate();

      if (videoOnly1080 != null) {
        availableOptions.add(StreamOption(
          qualityLabel: '1080p Full HD (HQ)',
          format: 'mp4',
          description: 'Best quality, merges audio & video streams.',
          videoStreamInfo: videoOnly1080,
          audioStreamInfo: bestAudio,
          isMuxRequired: true,
          sizeBytes: videoOnly1080.size.totalBytes + bestAudio.size.totalBytes,
        ));
      }

      // 2. Fetch muxed streams (already combined, fast download, usually up to 720p)
      for (final stream in manifest.muxed) {
        availableOptions.add(StreamOption(
          qualityLabel: '${stream.videoQualityLabel} HD',
          format: 'mp4',
          description: 'Standard combined video & audio.',
          videoStreamInfo: stream,
          isMuxRequired: false,
          sizeBytes: stream.size.totalBytes,
        ));
      }

      // 3. Audio only option
      availableOptions.add(StreamOption(
        qualityLabel: 'Audio Only (MP3)',
        format: 'mp3',
        description: 'Highest quality audio stream.',
        audioStreamInfo: bestAudio,
        isMuxRequired: false,
        sizeBytes: bestAudio.size.totalBytes,
      ));

      setState(() {
        _videoInfo = video;
        _streamManifest = manifest;
        _options = availableOptions;
        if (availableOptions.isNotEmpty) {
          _selectedOption = availableOptions.first;
        }
        _fetching = false;
      });
    } catch (e) {
      debugPrint('Error fetching video: $e');
      _showError('Failed to fetch video details. Check connection or video availability.');
      setState(() => _fetching = false);
    }
  }

  Future<void> _startDownload() async {
    if (_videoInfo == null || _selectedOption == null) return;

    // Check gallery permissions
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        _showError('Gallery save permission denied. Cannot download video.');
        return;
      }
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Preparing download files...';
      _isCancelled = false;
      _isBackgrounded = false;
    });

    String? tempVideoPath;
    String? tempAudioPath;
    String? finalOutPath;

    try {
      final opt = _selectedOption!;
      final sanitizedTitle = _videoInfo!.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final format = opt.format;
      final finalFileName = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.$format';

      final tempDir = await getTemporaryDirectory();

      if (opt.isMuxRequired) {
        // Muxing required (1080p)
        // Use completely safe names for FFmpeg input paths to prevent any parsing/quoting failures
        tempVideoPath = '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        tempAudioPath = '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        finalOutPath = '${tempDir.path}/temp_muxed_${DateTime.now().millisecondsSinceEpoch}.mp4';

        // 1. Download Video Stream
        setState(() => _statusText = 'Downloading video stream (0%)...');
        await _downloadStreamToFile(opt.videoStreamInfo!, tempVideoPath, (progress) {
          setState(() {
            _downloadProgress = progress * 0.5; // Video is first half
            _statusText = 'Downloading video stream (${(progress * 100).toInt()}%)...';
          });
        });

        // 2. Download Audio Stream
        setState(() => _statusText = 'Downloading audio stream (0%)...');
        await _downloadStreamToFile(opt.audioStreamInfo!, tempAudioPath, (progress) {
          setState(() {
            _downloadProgress = 0.5 + (progress * 0.45); // Audio is next 45%
            _statusText = 'Downloading audio stream (${(progress * 100).toInt()}%)...';
          });
        });

        // 3. Mux Video + Audio using FFmpeg
        setState(() {
          _downloadProgress = 0.95;
          _statusText = 'Merging audio & video streams (FFmpeg)...';
        });

        if (_isCancelled) throw Exception('Download cancelled by user.');

        // Clean output if exists
        final outFile = File(finalOutPath);
        if (await outFile.exists()) await outFile.delete();

        // Determine if transcoding is required (if the stream container is not MP4 or codec is not AVC/H.264)
        final bool isH264 = opt.videoStreamInfo is VideoStreamInfo &&
            opt.videoStreamInfo!.container.name == 'mp4' &&
            (opt.videoStreamInfo as VideoStreamInfo).videoCodec.toLowerCase().startsWith('avc');
        
        final String videoCodecArg = isH264 
            ? 'copy' 
            : 'libx264 -preset ultrafast -pix_fmt yuv420p';

        final cmd = '-i "$tempVideoPath" -i "$tempAudioPath" -c:v $videoCodecArg -c:a aac -map 0:v:0 -map 1:a:0 -y "$finalOutPath"';
        final session = await FFmpegKit.execute(cmd);
        final returnCode = await session.getReturnCode();

        // Delete temporary parts
        if (await File(tempVideoPath).exists()) await File(tempVideoPath).delete();
        if (await File(tempAudioPath).exists()) await File(tempAudioPath).delete();
        tempVideoPath = null;
        tempAudioPath = null;

        if (_isCancelled) {
          if (await File(finalOutPath).exists()) await File(finalOutPath).delete();
          throw Exception('Download cancelled by user.');
        }

        if (ReturnCode.isSuccess(returnCode)) {
          // Save final output to gallery under album "Media Mate"
          await Gal.putVideo(finalOutPath, album: 'Media Mate');
          await File(finalOutPath).delete();
          finalOutPath = null;

          _showSuccess('Successfully saved Full HD video to Gallery under "Media Mate" album.');
        } else {
          final logs = await session.getLogsAsString();
          debugPrint('FFmpeg failure: $logs');
          throw Exception('FFmpeg muxing failed.');
        }
      } else {
        // Direct stream download or Audio Only
        if (opt.format == 'mp3') {
          // Download audio to a temp file first and then convert to MP3
          tempAudioPath = '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.${opt.audioStreamInfo!.container.name}';
          finalOutPath = '${tempDir.path}/temp_converted_${DateTime.now().millisecondsSinceEpoch}.mp3';

          setState(() => _statusText = 'Downloading audio stream (0%)...');
          await _downloadStreamToFile(opt.audioStreamInfo!, tempAudioPath, (progress) {
            setState(() {
              _downloadProgress = progress * 0.5;
              _statusText = 'Downloading audio stream (${(progress * 100).toInt()}%)...';
            });
          });

          setState(() {
            _downloadProgress = 0.8;
            _statusText = 'Converting to MP3 format (FFmpeg)...';
          });

          if (_isCancelled) throw Exception('Download cancelled by user.');

          // Clean output if exists
          final outFile = File(finalOutPath);
          if (await outFile.exists()) await outFile.delete();

          // Convert to MP3 using FFmpeg
          final cmd = '-i "$tempAudioPath" -c:a libmp3lame -q:a 2 -y "$finalOutPath"';
          final session = await FFmpegKit.execute(cmd);
          final returnCode = await session.getReturnCode();

          if (await File(tempAudioPath).exists()) {
            await File(tempAudioPath).delete();
          }
          tempAudioPath = null;

          if (_isCancelled) {
            if (await File(finalOutPath).exists()) await File(finalOutPath).delete();
            throw Exception('Download cancelled by user.');
          }

          if (!ReturnCode.isSuccess(returnCode)) {
            throw Exception('FFmpeg audio conversion failed.');
          }

          // Attempt to save to downloads or fallback to share sheet
          bool saved = false;
          String destPath = '';
          try {
            Directory? downloadsDir;
            if (Platform.isAndroid) {
              downloadsDir = Directory('/storage/emulated/0/Download');
            } else {
              downloadsDir = await getDownloadsDirectory();
            }

            downloadsDir ??= await getApplicationDocumentsDirectory();
            final mediaMateDir = Directory('${downloadsDir.path}/Media Mate/Video Downloader');
            if (!await mediaMateDir.exists()) {
              await mediaMateDir.create(recursive: true);
            }

            destPath = '${mediaMateDir.path}/$finalFileName';
            await File(finalOutPath).copy(destPath);
            await File(finalOutPath).delete();
            finalOutPath = null;
            saved = true;
          } catch (e) {
            debugPrint('Failed to save directly to downloads directory: $e');
          }

          if (saved) {
            _showSuccess('Saved audio file successfully to: "Downloads/Media Mate/Video Downloader/$finalFileName"');
          } else {
            // Fallback to share sheet
            final appDocDir = await getApplicationDocumentsDirectory();
            final destDir = Directory('${appDocDir.path}/Media Mate/Audio');
            if (!await destDir.exists()) {
              await destDir.create(recursive: true);
            }
            destPath = '${destDir.path}/$finalFileName';
            await File(finalOutPath!).copy(destPath);
            await File(finalOutPath!).delete();
            finalOutPath = null;

            // Show share sheet so user can save or send the audio
            await Share.shareXFiles([XFile(destPath)], text: 'Audio downloaded from YouTube');
            
            _showSuccess('Saved audio to app storage and opened share options to save or send the file.');
          }
        } else {
          // Direct video download (muxed)
          finalOutPath = '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final streamInfo = opt.videoStreamInfo!;

          setState(() => _statusText = 'Downloading media (0%)...');
          await _downloadStreamToFile(streamInfo, finalOutPath, (progress) {
            setState(() {
              _downloadProgress = progress * 0.95;
              _statusText = 'Downloading media (${(progress * 100).toInt()}%)...';
            });
          });

          // Save to Gallery
          setState(() {
            _downloadProgress = 0.98;
            _statusText = 'Registering file in Gallery...';
          });

          if (_isCancelled) {
            if (await File(finalOutPath).exists()) await File(finalOutPath).delete();
            throw Exception('Download cancelled by user.');
          }

          // Video saving via Gal
          await Gal.putVideo(finalOutPath, album: 'Media Mate');
          await File(finalOutPath).delete();
          finalOutPath = null;

          _showSuccess('Successfully saved video to Gallery under "Media Mate" album.');
        }
      }
    } catch (e) {
      // Clean up any temp files if cancelled or failed
      try {
        if (tempVideoPath != null && await File(tempVideoPath).exists()) {
          await File(tempVideoPath).delete();
        }
        if (tempAudioPath != null && await File(tempAudioPath).exists()) {
          await File(tempAudioPath).delete();
        }
        if (finalOutPath != null && await File(finalOutPath).exists()) {
          await File(finalOutPath).delete();
        }
      } catch (_) {}

      debugPrint('Download error: $e');
      if (_isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Download cancelled.'),
          backgroundColor: Colors.orangeAccent,
        ));
      } else {
        _showError('Failed to complete download. Error: $e');
      }
    } finally {
      setState(() {
        _downloading = false;
        _isCancelled = false;
        _isBackgrounded = false;
      });
    }
  }

  Future<void> _downloadStreamToFile(
    StreamInfo streamInfo,
    String path,
    Function(double) onProgress,
  ) async {
    final stream = _yt.videos.streamsClient.get(streamInfo);
    final file = File(path);
    final ioSink = file.openWrite();
    
    final totalSize = streamInfo.size.totalBytes;
    int bytesDownloaded = 0;

    try {
      await for (final data in stream) {
        if (_isCancelled) {
          break;
        }
        ioSink.add(data);
        bytesDownloaded += data.length;
        onProgress(bytesDownloaded / totalSize);
      }
    } finally {
      await ioSink.flush();
      await ioSink.close();
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
        title: const Text('Download Finished!'),
        content: Text(
          msg,
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Video Downloader',
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
                // Paste YouTube URL Header
                Text(
                  'Paste YouTube Video URL',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Link entry field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://www.youtube.com/watch?v=...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onSubmitted: (_) => _fetchVideoInfo(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 54,
                      child: IconButton.filledTonal(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste_rounded),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fetch Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _fetching ? null : _fetchVideoInfo,
                    icon: _fetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(
                      _fetching ? 'Fetching Video Details...' : 'Fetch Video Details',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Video info panel
                if (_videoInfo != null) ...[
                  // Video Details card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            _videoInfo!.thumbnails.highResUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _videoInfo!.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _videoInfo!.author,
                                      style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                    ),
                                  ),
                                  Icon(Icons.access_time, size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(_videoInfo!.duration),
                                    style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quality choice label
                  Text(
                    'Select Resolution / Format',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quality choices
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final opt = _options[index];
                      final isSelected = _selectedOption == opt;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: isSelected
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
                            : theme.colorScheme.surface,
                        child: ListTile(
                          onTap: () => setState(() => _selectedOption = opt),
                          leading: Icon(
                            opt.format == 'mp3' ? Icons.audiotrack : Icons.video_collection,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            opt.qualityLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(opt.description, style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            _formatSize(opt.sizeBytes),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Start download button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _downloading ? null : _startDownload,
                      icon: const Icon(Icons.download_for_offline),
                      label: const Text('Download to Device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),

          // Minimized Background progress indicator banner (at the bottom)
          if (_downloading && _isBackgrounded)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: theme.colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Downloading: ${(_downloadProgress * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Cancel Button
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            _isCancelled = true;
                          });
                        },
                      ),
                      // Maximize Button to show full dialog again
                      IconButton(
                        icon: const Icon(Icons.open_in_full, size: 18),
                        onPressed: () {
                          setState(() {
                            _isBackgrounded = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Full screen Download Progress HUD Overlay
          if (_downloading && !_isBackgrounded)
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
                          'Downloading Media...',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_downloadProgress * 100).toInt()}% Completed',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Cancel button
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isCancelled = true;
                                });
                              },
                              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                              label: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                            ),
                            // Download in background button
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isBackgrounded = true;
                                });
                              },
                              icon: const Icon(Icons.downloading),
                              label: const Text('Run in BG'),
                            ),
                          ],
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
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'unknown';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, "0")}';
  }

  String _formatSize(int bytes) {
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class StreamOption {
  final String qualityLabel;
  final String format;
  final String description;
  final StreamInfo? videoStreamInfo;
  final AudioOnlyStreamInfo? audioStreamInfo;
  final bool isMuxRequired;
  final int sizeBytes;

  StreamOption({
    required this.qualityLabel,
    required this.format,
    required this.description,
    this.videoStreamInfo,
    this.audioStreamInfo,
    required this.isMuxRequired,
    required this.sizeBytes,
  });
}
