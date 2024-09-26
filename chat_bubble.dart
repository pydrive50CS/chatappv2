import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class WaveBubble extends StatefulWidget {
  final bool isSender;
  final int? index;
  final String? path;
  final double? width;
  final Directory appDirectory;

  const WaveBubble({
    super.key,
    required this.appDirectory,
    this.width,
    this.index,
    this.isSender = false,
    this.path,
  });

  @override
  State<WaveBubble> createState() => _WaveBubbleState();
}

class _WaveBubbleState extends State<WaveBubble> {
  File? file;

  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;

  final playerWaveStyle = const PlayerWaveStyle(
    fixedWaveColor: Colors.white54,
    liveWaveColor: Colors.white,
    spacing: 6,
  );

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _preparePlayer();
    playerStateSubscription = controller.onPlayerStateChanged.listen((_) {
      setState(() {});
    });
  }

  void _preparePlayer() async {
    // Prepare player with extracting waveform if index is even.
    controller.preparePlayer(
      path: widget.path ?? file!.path,
      shouldExtractWaveform: widget.index?.isEven ?? true,
    );
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path != null || file?.path != null) {
      return Container(
        padding: EdgeInsets.only(
          bottom: 6,
          right: widget.isSender ? 0 : 10,
          top: 6,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: widget.isSender ? const Color(0xFF276bfd) : const Color(0xFF343145),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!controller.playerState.isStopped)
              IconButton(
                onPressed: () async {
                  final duration = await controller.getDuration(DurationType.max);
                  log(duration.toString());
                  controller.playerState.isPlaying
                      ? await controller.pausePlayer()
                      : await controller.startPlayer(
                          finishMode: FinishMode.pause,
                        );
                },
                icon: Icon(
                  controller.playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                color: Colors.white,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
            AudioFileWaveforms(
              enableSeekGesture: true,
              size: Size(MediaQuery.of(context).size.width / 1.25, 40),
              playerController: controller,
              // waveformType: widget.index?.isOdd ?? false ? WaveformType.fitWidth : WaveformType.long,
              waveformType: WaveformType.fitWidth,
              playerWaveStyle: playerWaveStyle,
            ),
            if (widget.isSender) const SizedBox(width: 10),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
