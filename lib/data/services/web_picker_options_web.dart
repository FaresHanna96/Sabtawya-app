import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Safari reports the window as focused again before the chosen file is ready
/// (a file from iCloud / Files takes a moment). With the default, that was
/// taken for a cancel and the pick silently returned nothing.
WebOptions pdfWebOptions() =>
    const FilePickerWebOptions(cancelUploadOnWindowBlur: false);
