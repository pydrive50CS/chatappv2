import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class WaveBubble extends StatefulWidget {
  final String audioBytes;

  const WaveBubble({
    super.key,
    required this.audioBytes,
  });

  @override
  State<WaveBubble> createState() => _WaveBubbleState();
}

class _WaveBubbleState extends State<WaveBubble> {
  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;
  String? tempAudioFilePath = null;

  final playerWaveStyle = const PlayerWaveStyle(
    fixedWaveColor: Colors.white54,
    liveWaveColor: Colors.white,
    spacing: 6,
  );

  @override
  void initState() {
    super.initState();
    _saveAndPreparePlayer();
    controller = PlayerController();
    playerStateSubscription = controller.onPlayerStateChanged.listen((_) {
      setState(() {});
    });
  }

  Future<void> _saveAndPreparePlayer() async {
    try {
      final tempDir = await getTemporaryDirectory();
      tempAudioFilePath = "${tempDir.path}/temp_audio.m4a";
      // Decode the audio bytes and write them to a temporary file
      final file = File(tempAudioFilePath!); // Safely unwrap the nullable variable
      await file.writeAsBytes(base64.decode(widget.audioBytes)); // Convert to bytes
      // setState(() {});
      // Prepare player with the temp file
      await controller.preparePlayer(
        path: tempAudioFilePath!,
        shouldExtractWaveform: true,
      );
    } catch (e) {
      debugPrint('Error saving audio file: $e');
      tempAudioFilePath = null; // Set to null if there's an error
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return tempAudioFilePath != null
        ? Container(
            padding: const EdgeInsets.only(
              bottom: 6,
              right: 10,
              top: 6,
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF276bfd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!controller.playerState.isStopped)
                  IconButton(
                    onPressed: () async {
                      controller.playerState.isPlaying
                          ? await controller.pausePlayer()
                          : await controller.startPlayer(
                              finishMode: FinishMode.pause,
                            );
                    },
                    icon: Icon(
                      controller.playerState.isPlaying ? Icons.stop : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                AudioFileWaveforms(
                  size: Size(MediaQuery.of(context).size.width / 2, 40),
                  playerController: controller,
                  // waveformType: widget.index?.isOdd ?? false ? WaveformType.fitWidth : WaveformType.long,
                  waveformType: WaveformType.fitWidth,
                  playerWaveStyle: playerWaveStyle,
                ),
                const SizedBox(width: 10),
              ],
            ),
          )
        : const SizedBox.shrink();
  }
}
