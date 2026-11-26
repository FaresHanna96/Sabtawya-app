{{flutter_js}}
{{flutter_build_config}}

// Without Flutter's own service worker, which now only removes itself:
// app-sw.js (registered in index.html) saves the app for offline use.
_flutter.loader.load();
