import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/language_provider.dart';
import 'collage_home_screen.dart';
import '../../status_saver/screens/status_saver_screen.dart';
import '../../downloader/screens/youtube_downloader_screen.dart';
import '../../music_editor/screens/add_music_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeMode == ThemeMode.dark
                ? [const Color(0xFF0F0F1A), const Color(0xFF151522)]
                : [const Color(0xFFF5F6FC), const Color(0xFFEAEBFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Media Mate'.tr(lang),
                            style: GoogleFonts.outfit(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your Ultimate Media Toolbox'.tr(lang),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Language Switcher Button
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.translate),
                            color: Theme.of(context).colorScheme.primary,
                            onPressed: () {
                              ref.read(languageProvider.notifier).toggleLanguage();
                              final newLang = ref.read(languageProvider);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newLang == AppLanguage.hindi 
                                        ? 'भाषा हिन्दी में बदली गई' 
                                        : 'Language switched to English',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Switch Language'.tr(lang),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Theme Switcher Button
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              ref.read(themeModeProvider.notifier).toggleTheme();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Features Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.78,
                  children: [
                    _buildFeatureCard(
                      context: context,
                      title: 'Collage Creator'.tr(lang),
                      description: 'Blend and style photos into grids or freeform designs.'.tr(lang),
                      icon: Icons.dashboard_outlined,
                      primaryColor: const Color(0xFF6366F1),
                      secondaryColor: const Color(0xFFA5B4FC),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const CollageHomeScreen()),
                      ),
                    ),
                    _buildFeatureCard(
                      context: context,
                      title: 'Status Saver'.tr(lang),
                      description: 'View, save & share your WhatsApp media statuses.'.tr(lang),
                      icon: Icons.offline_share_outlined,
                      primaryColor: const Color(0xFF10B981),
                      secondaryColor: const Color(0xFF6EE7B7),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const StatusSaverScreen()),
                      ),
                    ),
                    _buildFeatureCard(
                      context: context,
                      title: 'Video Downloader'.tr(lang),
                      description: 'Download YouTube videos in high quality & audio formats.'.tr(lang),
                      icon: Icons.cloud_download_outlined,
                      primaryColor: const Color(0xFFEF4444),
                      secondaryColor: const Color(0xFFFCA5A5),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const YoutubeDownloaderScreen()),
                      ),
                    ),
                    _buildFeatureCard(
                      context: context,
                      title: 'Music Added'.tr(lang),
                      description: 'Combine beautiful images with local or online soundtracks.'.tr(lang),
                      icon: Icons.music_note_outlined,
                      primaryColor: const Color(0xFFF59E0B),
                      secondaryColor: const Color(0xFFFDE68A),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AddMusicScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.5),
          width: 1,
        ),
      ),
      color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.6 : 0.8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: primaryColor.withValues(alpha: 0.1),
        highlightColor: primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(16), // Reduced from 20 for better spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Circle with Gradient
              Container(
                padding: const EdgeInsets.all(10), // Reduced from 12
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24, // Reduced from 26
                ),
              ),
              const Spacer(),
              // Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Reduced from 18
                  letterSpacing: -0.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4), // Reduced from 6
              // Description
              Text(
                description,
                maxLines: 2, // Reduced from 3 to prevent overflow on small screens
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11, // Reduced from 11.5
                  height: 1.3,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
