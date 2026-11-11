import 'dart:io';
import 'package:video_player/video_player.dart';

VideoPlayerController localVideoController(String path) =>
    VideoPlayerController.file(File(path));

Future<String?> writeLocalBytes(List<int> bytes, String fileName) async {
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
