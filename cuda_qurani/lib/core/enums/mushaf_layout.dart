// lib/core/enums/mushaf_layout.dart

enum MushafLayout {
  qpc,      // 604 halaman, glyph fonts (p1-p604)
  indopak,  // 610 halaman, single font (IndoPak Nastaleeq)
}

extension MushafLayoutExtension on MushafLayout {
  String get displayName {
    switch (this) {
      case MushafLayout.qpc:
        return 'QPC Hafs';
      case MushafLayout.indopak:
        return 'Indo-Pak';
    }
  }

  int get totalPages {
    switch (this) {
      case MushafLayout.qpc:
        return 604;
      case MushafLayout.indopak:
        return 610;
    }
  }

  String get fontFamily {
    switch (this) {
      case MushafLayout.qpc:
        return 'dynamic'; // p1, p2, p3, etc.
      case MushafLayout.indopak:
        return 'IndoPak-Nastaleeq';
    }
  }

  bool get isGlyphBased {
    switch (this) {
      case MushafLayout.qpc:
        return true;
      case MushafLayout.indopak:
        return false;
    }
  }

  static MushafLayout fromString(String value) {
    switch (value.toLowerCase()) {
      case 'qpc':
        return MushafLayout.qpc;
      case 'indopak':
        return MushafLayout.indopak;
      default:
        return MushafLayout.qpc; // Default
    }
  }

  String toStringValue() {
    switch (this) {
      case MushafLayout.qpc:
        return 'qpc';
      case MushafLayout.indopak:
        return 'indopak';
    }
  }
}