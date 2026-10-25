/// Data models for the Quranic handwriting prompts parsed from collection_manifest.json.
library;

class LinePrompt {
  final int lineIndex;
  final int gStart;
  final int gEnd;
  final String displayTextUthmani;
  final String writtenImlai;

  const LinePrompt({
    required this.lineIndex,
    required this.gStart,
    required this.gEnd,
    required this.displayTextUthmani,
    required this.writtenImlai,
  });

  factory LinePrompt.fromJson(Map<String, dynamic> json) {
    return LinePrompt(
      lineIndex: (json['line_index'] as num).toInt(),
      gStart: (json['g_start'] as num).toInt(),
      gEnd: (json['g_end'] as num).toInt(),
      displayTextUthmani: json['display_text_uthmani'] as String? ?? '',
      writtenImlai: json['written_imlai'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'line_index': lineIndex,
        'g_start': gStart,
        'g_end': gEnd,
        'display_text_uthmani': displayTextUthmani,
        'written_imlai': writtenImlai,
      };
}

class PromptItem {
  final int seqIndex;
  final String promptId;
  final String writerId;
  final String tier;
  final String packType;
  final bool isTrainingEligible;
  final int numCanvasLines;
  final int surah;
  final int ayahStart;
  final int ayahEnd;
  final int gStart;
  final int gEnd;
  final String displayTextUthmani;
  final String writtenImlai;
  final String canonicalImlai;
  final List<LinePrompt> linePrompts;
  final Map<String, dynamic>? errorMeta;
  final String? uiNoticeAr;
  final Map<String, dynamic> rawJson;

  const PromptItem({
    required this.seqIndex,
    required this.promptId,
    required this.writerId,
    required this.tier,
    required this.packType,
    required this.isTrainingEligible,
    required this.numCanvasLines,
    required this.surah,
    required this.ayahStart,
    required this.ayahEnd,
    required this.gStart,
    required this.gEnd,
    required this.displayTextUthmani,
    required this.writtenImlai,
    required this.canonicalImlai,
    required this.linePrompts,
    this.errorMeta,
    this.uiNoticeAr,
    required this.rawJson,
  });

  factory PromptItem.fromJson(Map<String, dynamic> json) {
    final linePromptsList = (json['line_prompts'] as List<dynamic>?)
            ?.map((e) => LinePrompt.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return PromptItem(
      seqIndex: (json['seq_index'] as num).toInt(),
      promptId: json['prompt_id'] as String? ?? '',
      writerId: json['writer_id'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      packType: json['pack_type'] as String? ?? '',
      isTrainingEligible: json['is_training_eligible'] as bool? ?? true,
      numCanvasLines: (json['num_canvas_lines'] as num?)?.toInt() ?? 1,
      surah: (json['surah'] as num?)?.toInt() ?? 1,
      ayahStart: (json['ayah_start'] as num?)?.toInt() ?? 1,
      ayahEnd: (json['ayah_end'] as num?)?.toInt() ?? 1,
      gStart: (json['g_start'] as num?)?.toInt() ?? 0,
      gEnd: (json['g_end'] as num?)?.toInt() ?? 0,
      displayTextUthmani: json['display_text_uthmani'] as String? ?? '',
      writtenImlai: json['written_imlai'] as String? ?? '',
      canonicalImlai: json['canonical_imlai'] as String? ?? '',
      linePrompts: linePromptsList,
      errorMeta: json['error_meta'] as Map<String, dynamic>?,
      uiNoticeAr: json['ui_notice_ar'] as String?,
      rawJson: json,
    );
  }

  /// User-friendly Arabic pack name for badges
  String get packLabelArabic {
    switch (packType) {
      case 'shared_core':
        return 'الحزمة أ: المعايرة الأساسية';
      case 'disjoint_coverage':
        return 'الحزمة ب: التغطية المتفرقة';
      case 'multiline_cross_ayah':
        return 'الحزمة ج: الأسطر المتعددة';
      case 'intentional_error_eval':
        return 'الحزمة د: اختبار الدقة الذكي';
      default:
        return 'الحزمة: $packType';
    }
  }

  /// Arabic Surah & Ayah reference label
  String get referenceLabelArabic {
    final surahName = _surahNames[surah] ?? 'سورة $surah';
    if (ayahStart == ayahEnd) {
      return '$surahName • آية $ayahStart';
    } else {
      return '$surahName • الآيات $ayahStart–$ayahEnd';
    }
  }

  static const Map<int, String> _surahNames = {
    1: 'سورة الفاتحة',
    2: 'سورة البقرة',
    3: 'سورة آل عمران',
    4: 'سورة النساء',
    5: 'سورة المائدة',
    6: 'سورة الأنعام',
    7: 'سورة الأعراف',
    8: 'سورة الأنفال',
    9: 'سورة التوبة',
    10: 'سورة يونس',
    11: 'سورة هود',
    12: 'سورة يوسف',
    13: 'سورة الرعد',
    14: 'سورة إبراهيم',
    15: 'سورة الحجر',
    16: 'سورة النحل',
    17: 'سورة الإسراء',
    18: 'سورة الكهف',
    19: 'سورة مريم',
    20: 'سورة طه',
    21: 'سورة الأنبياء',
    22: 'سورة الحج',
    23: 'سورة المؤمنون',
    24: 'سورة النور',
    25: 'سورة الفرقان',
    26: 'سورة الشعراء',
    27: 'سورة النمل',
    28: 'سورة القصص',
    29: 'سورة العنكبوت',
    30: 'سورة الروم',
    31: 'سورة لقمان',
    32: 'سورة السجدة',
    33: 'سورة الأحزاب',
    34: 'سورة سبأ',
    35: 'سورة فاطر',
    36: 'سورة يس',
    37: 'سورة الصافات',
    38: 'سورة ص',
    39: 'سورة الزمر',
    40: 'سورة غافر',
    41: 'سورة فصلت',
    42: 'سورة الشورى',
    43: 'سورة الزخرف',
    44: 'سورة الدخان',
    45: 'سورة الجاثية',
    46: 'سورة الأحقاف',
    47: 'سورة محمد',
    48: 'سورة الفتح',
    49: 'سورة الحجرات',
    50: 'سورة ق',
    51: 'سورة الذاريات',
    52: 'سورة الطور',
    53: 'سورة النجم',
    54: 'سورة القمر',
    55: 'سورة الرحمن',
    56: 'سورة الواقعة',
    57: 'سورة الحديد',
    58: 'سورة المجادلة',
    59: 'سورة الحشر',
    60: 'سورة الممتحنة',
    61: 'سورة الصف',
    62: 'سورة الجمعة',
    63: 'سورة المنافقون',
    64: 'سورة التغابن',
    65: 'سورة الطلاق',
    66: 'سورة التحريم',
    67: 'سورة الملك',
    68: 'سورة القلم',
    69: 'سورة الحاقة',
    70: 'سورة المعارج',
    71: 'سورة نوح',
    72: 'سورة الجن',
    73: 'سورة المزمل',
    74: 'سورة المدثر',
    75: 'سورة القيامة',
    76: 'سورة الإنسان',
    77: 'سورة المرسلات',
    78: 'سورة النبأ',
    79: 'سورة النازعات',
    80: 'سورة عبس',
    81: 'سورة التكوير',
    82: 'سورة الانفطار',
    83: 'سورة المطففين',
    84: 'سورة الانشقاق',
    85: 'سورة البروج',
    86: 'سورة الطارق',
    87: 'سورة الأعلى',
    88: 'سورة الغاشية',
    89: 'سورة الفجر',
    90: 'سورة البلد',
    91: 'سورة الشمس',
    92: 'سورة الليل',
    93: 'سورة الضحى',
    94: 'سورة الشرح',
    95: 'سورة التين',
    96: 'سورة العلق',
    97: 'سورة القدر',
    98: 'سورة البينة',
    99: 'سورة الزلزلة',
    100: 'سورة العاديات',
    101: 'سورة القارعة',
    102: 'سورة التكاثر',
    103: 'سورة العصر',
    104: 'سورة الهمزة',
    105: 'سورة الفيل',
    106: 'سورة قريش',
    107: 'سورة الماعون',
    108: 'سورة الكوثر',
    109: 'سورة الكافرون',
    110: 'سورة النصر',
    111: 'سورة المسد',
    112: 'سورة الإخلاص',
    113: 'سورة الفلق',
    114: 'سورة الناس',
  };
}
