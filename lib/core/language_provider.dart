import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { english, hindi }

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    return AppLanguage.english;
  }

  void setLanguage(AppLanguage lang) {
    state = lang;
  }

  void toggleLanguage() {
    state = state == AppLanguage.english ? AppLanguage.hindi : AppLanguage.english;
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

extension StringTranslation on String {
  String tr(AppLanguage lang) {
    if (lang == AppLanguage.english) return this;
    return _translations[this] ?? this;
  }
}

const Map<String, String> _translations = {
  // Common / Navigation
  'Cancel': 'रद्द करें',
  'Save': 'सहेजें',
  'Share': 'साझा करें',
  'Download': 'डाउनलोड',
  'Loading...': 'लोड हो रहा है...',
  'Success': 'सफलता',
  'Error': 'त्रुटि',
  'Allow & Save': 'अनुमति दें और सहेजें',
  'Rename': 'नाम बदलें',
  'Delete': 'हटाएं',
  'Back': 'पीछे',

  // HomeScreen
  'Media Mate': 'मीडिया मीट',
  'Your Ultimate Media Toolbox': 'आपका परम मीडिया टूलबॉक्स',
  'Collage Creator': 'कोलाज निर्माता',
  'Blend and style photos into grids or freeform designs.': 'तस्वीरों को ग्रिड या फ्रीफॉर्म डिज़ाइन में मिलाएं और स्टाइल करें।',
  'Status Saver': 'स्टेटस सेवर',
  'View, save & share your WhatsApp media statuses.': 'व्हाट्सएप मीडिया स्टेटस देखें, सहेजें और साझा करें।',
  'Video Downloader': 'वीडियो डाउनलोडर',
  'Download YouTube videos in high quality & audio formats.': 'यूट्यूब वीडियो को उच्च गुणवत्ता और ऑडियो प्रारूपों में डाउनलोड करें।',
  'Music Added': 'संगीत जोड़ें',
  'Combine beautiful images with local or online soundtracks.': 'सुंदर छवियों को लोकल या ऑनलाइन साउंडट्रैक के साथ संयोजित करें।',
  'Switch Language': 'भाषा बदलें',
  'Language Switched': 'भाषा बदल दी गई है',

  // Status Saver
  'Images': 'चित्र',
  'Videos': 'वीडियो',
  'Storage permission is required to search and save your viewed WhatsApp statuses.': 'आपके देखे गए व्हाट्सएप स्टेटस को खोजने और सहेजने के लिए स्टोरेज की अनुमति आवश्यक है।',
  'Grant Permission': 'अनुमति दें',
  'No statuses found': 'कोई स्टेटस नहीं मिला',
  'Open WhatsApp, view some of your friends\' statuses, and then check back here!': 'व्हाट्सएप खोलें, अपने दोस्तों के कुछ स्टेटस देखें, और फिर यहाँ वापस जाँचें!',
  'Status Preview': 'स्टेटस पूर्वावलोकन',
  'Could not play video status: \$error': 'वीडियो स्टेटस नहीं चलाया जा सका: \$error',
  'Successfully saved to Gallery!': 'गैलरी में सफलतापूर्वक सहेजा गया!',
  'Failed to save status': 'स्टेटस सहेजने में विफल',
  'WhatsApp Business': 'व्हाट्सएप बिजनेस',
  'Successfully saved to Gallery under "Media Mate" folder.': 'गैलरी में "Media Mate" फ़ोल्डर के अंतर्गत सफलतापूर्वक सहेजा गया।',
  'Mock Status Saver': 'मॉक स्टेटस सेवर',
  'WhatsApp Status Saver': 'व्हाट्सएप स्टेटस सेवर',

  // Collage Creator Home & Editor
  'Create New Collage': 'नया कोलाज बनाएं',
  'Select Aspect Ratio': 'आस्पेक्ट रेशियो चुनें',
  'Recent Drafts': 'हाल के ड्राफ्ट',
  'No projects yet': 'अभी तक कोई प्रोजेक्ट नहीं है',
  'Create a new collage to see drafts here.': 'यहाँ ड्राफ्ट देखने के लिए एक नया कोलाज बनाएं।',
  'Are you sure you want to permanently delete this collage draft?': 'क्या आप वाकई इस कोलाज ड्राफ्ट को स्थायी रूप से हटाना चाहते हैं?',
  'Delete Draft': 'ड्राफ्ट हटाएं',
  'Rename Collage': 'कोलाज का नाम बदलें',
  'Enter collage name': 'कोलाज का नाम दर्ज करें',
  'Grid Assist': 'ग्रिड सहायता',
  'Snap Guides': 'स्नैप गाइड',
  'Grid Layout': 'ग्रिड लेआउट',
  'Background': 'पृष्ठभूमि',
  'Borders': 'बॉर्डर',
  'Add Layers': 'लेयर जोड़ें',
  'Export': 'निर्यात करें',
  'Text': 'टेक्स्ट',
  'Sticker': 'स्टिकर',
  'Add Emoji or Sticker': 'इमोजी या स्टिकर जोड़ें',
  'Scale & Position': 'स्केल और स्थिति',
  'Select text to edit styling.': 'स्टाइलिंग संपादित करने के लिए टेक्स्ट का चयन करें।',
  'Edit Text Content': 'टेक्स्ट सामग्री संपादित करें',
  'Font Family': 'फॉन्ट फैमिली',
  'Text Color': 'टेक्स्ट का रंग',
  'Spacing': 'दूरी',
  'Radius': 'त्रिज्या',
  'Border Color': 'बॉर्डर का रंग',
  'Solid Color': 'ठोस रंग',
  'Gradient': 'ग्रेडिएंट',
  'Solid': 'ठोस',
  'Choose Solid Color': 'ठोस रंग चुनें',
  'Adjust Photo Filters': 'फोटो फिल्टर समायोजित करें',
  'Brightness': 'चमक',
  'Contrast': 'अंतर (कॉन्ट्रास्ट)',
  'Saturation': 'संतृप्ति (सैचुरेशन)',
  'Save PNG': 'PNG सहेजें',
  'Save JPEG': 'JPEG सहेजें',
  'Export Collage': 'कोलाज निर्यात करें',
  'Do you want to proceed?': 'क्या आप आगे बढ़ना चाहते हैं?',
  'Failed to compile collage.': 'कोलाज संकलित करने में विफल।',

  // Add Music Screen
  'Choose Background Image': 'पृष्ठभूमि छवि चुनें',
  'Select Background Image': 'पृष्ठभूमि छवि का चयन करें',
  'Change Image': 'छवि बदलें',
  'Select Audio Track': 'ऑडियो ट्रैक चुनें',
  'Choose local audio file': 'लोकल ऑडियो फ़ाइल चुनें',
  'Background Presets': 'पृष्ठभूमि प्रीसेट',
  'Waveform Visualizer': 'वेवफॉर्म विज़ुअलाइज़र',
  'Generating video...': 'वीडियो बनाया जा रहा है...',
  'Export Video': 'वीडियो निर्यात करें',
  'Successfully saved video to Gallery!': 'गैलरी में वीडियो सफलतापूर्वक सहेजा गया!',
  'Or Choose Online Presets:': 'या ऑनलाइन प्रीसेट चुनें:',
  'Or Choose Presets:': 'या प्रीसेट चुनें:',
  'Custom Audio Link': 'कस्टम ऑडियो लिंक',
  'Load Audio from Link': 'लिंक से ऑडियो लोड करें',
  'Enter Audio URL (.mp3, .wav)': 'ऑडियो यूआरएल दर्ज करें (.mp3, .wav)',
  'Enter direct audio stream link': 'सीधा ऑडियो स्ट्रीम लिंक दर्ज करें',
  'Load': 'लोड करें',
  'Invalid Audio URL': 'अमान्य ऑडियो यूआरएल',
  'Selected Audio:': 'चयनित ऑडियो:',
  'Pick Local Audio': 'लोकल ऑडियो चुनें',
  '3. Export Settings': '3. निर्यात सेटिंग्स',
  'Video Duration': 'वीडियो की अवधि',
  'Seconds': 'सेकंड',
  'Export Music Video': 'संगीत वीडियो निर्यात करें',
  'Compiling Music Video...': 'संगीत वीडियो बनाया जा रहा है...',
  'Completed': 'पूरा हुआ',

  // Youtube Downloader
  'Enter or paste YouTube video link': 'यूट्यूब वीडियो लिंक दर्ज करें या पेस्ट करें',
  'Analyze Link': 'लिंक का विश्लेषण करें',
  'Paste Link': 'लिंक पेस्ट करें',
  'Searching video details...': 'वीडियो विवरण खोजा जा रहा है...',
  'Invalid YouTube URL. Please check the link.': 'अमान्य यूट्यूब यूआरएल। कृपया लिंक की जांच करें।',
  'Download Options': 'डाउनलोड विकल्प',
  'Audio Only (MP3)': 'केवल ऑडियो (MP3)',
  'Downloading...': 'डाउनलोड हो रहा है...',
  'Preparing download...': 'डाउनलोड की तैयारी हो रही है...',
  'Download Finished!': 'डाउनलोड समाप्त!',
  'Saved audio file successfully to:': 'ऑडियो फ़ाइल को सफलतापूर्वक सहेजा गया:',
  'Successfully saved video to Gallery under "Media Mate" album.': 'गैलरी में "Media Mate" एल्बम के अंतर्गत वीडियो सफलतापूर्वक सहेजा गया।',
  'Download cancelled.': 'डाउनलोड रद्द कर दिया गया।',
  'Download cancelled': 'डाउनलोड रद्द',
};
