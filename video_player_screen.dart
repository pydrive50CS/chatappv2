import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

class VideoPlayerWidget extends StatefulWidget {
  final Uint8List videoBytes;

  const VideoPlayerWidget({super.key, required this.videoBytes});

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // widget.videoBytes
    _controller = VideoPlayerController.networkUrl(Uri.parse('https://youtu.be/7lHwMYMLCD0?list=PLinedj3B30sDFRdgPYvjnBs2JsDdHPIMv'))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const CircularProgressIndicator();
  }
}
