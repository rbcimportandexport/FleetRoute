{{flutter_js}}
{{flutter_build_config}}

// Do not register a service worker. Fleet and duty screens must always load
// the currently deployed application bundle instead of an obsolete PWA cache.
if (_flutter.buildConfig && _flutter.buildConfig.builds) {
  for (const build of _flutter.buildConfig.builds) {
    if (build.mainJsPath) {
      build.mainJsPath = build.mainJsPath + '?v=' + Date.now();
    }
  }
}
_flutter.loader.load();
