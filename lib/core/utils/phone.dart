import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer on [number] (spaces around it are ignored).
Future<bool> callNumber(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number.trim()));
