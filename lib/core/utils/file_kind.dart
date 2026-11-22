/// What a file really is, read from its first bytes rather than its name.
///
/// A PDF picked through the photo picker reached the server as ".jpg" (prod,
/// 20 Nov 2026), and every screen then tried to draw it as a picture. The
/// content is what decides the stored extension now.
enum FileKind {
  pdf('pdf', 'application/pdf'),
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp'),
  gif('gif', 'image/gif'),
  heic('heic', 'image/heic'),
  unknown('', 'application/octet-stream');

  const FileKind(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  bool get isPdf => this == FileKind.pdf;
  bool get isImage => this != FileKind.pdf && this != FileKind.unknown;

  /// Reads [bytes]' signature; [FileKind.unknown] when it is none of these.
  static FileKind of(List<int> bytes) {
    bool starts(List<int> sig, [int at = 0]) {
      if (bytes.length < at + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (bytes[at + i] != sig[i]) return false;
      }
      return true;
    }

    if (starts(const [0x25, 0x50, 0x44, 0x46])) return FileKind.pdf; // %PDF
    if (starts(const [0xFF, 0xD8, 0xFF])) return FileKind.jpeg;
    if (starts(const [0x89, 0x50, 0x4E, 0x47])) return FileKind.png;
    if (starts(const [0x47, 0x49, 0x46, 0x38])) return FileKind.gif; // GIF8
    if (starts(const [0x52, 0x49, 0x46, 0x46]) && // RIFF....WEBP
        starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return FileKind.webp;
    }
    if (starts(const [0x66, 0x74, 0x79, 0x70], 4) && // ....ftypheic / mif1
        (starts(const [0x68, 0x65, 0x69], 8) ||
            starts(const [0x6D, 0x69, 0x66], 8))) {
      return FileKind.heic;
    }
    return FileKind.unknown;
  }

  /// Whether a stored [path] is a PDF by its name.
  static bool isPdfPath(String path) => path.toLowerCase().endsWith('.pdf');
}
