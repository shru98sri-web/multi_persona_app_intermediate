class _UnsupportedVideoController {
  const _UnsupportedVideoController();
}
dynamic localVideoController(String path) => throw UnsupportedError('Local video playback is not supported on this platform.');
Future<String?> writeLocalBytes(List<int> bytes, String fileName) async =>
    throw UnsupportedError('Local file writing is not supported on this platform.');
