import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderManager {
  RecorderController recorderController = RecorderController()
    ..androidEncoder = AndroidEncoder.aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 44100;

  String? path;
  late Directory appDirectory;

  bool isRecording = false;
  bool isRecordingCompleted = false;

  Future<void> initialize() async {
    appDirectory = await getApplicationDocumentsDirectory();
    path = "${appDirectory.path}/recording.m4a";
  }

  Future<void> startRecording() async {
    recorderController.reset();
    await recorderController.record(path: path);
    isRecording = true;
  }

  Future<String?> stopRecording() async {
    path = await recorderController.stop(false);
    if (path != null) {
      isRecordingCompleted = true;
      final file = File(path!);
      final bytes = await file.readAsBytes(); // Read the audio file as bytes
      final base64String = base64Encode(bytes);
      log("Recorded file path: $path");
      log("Recorded file size: ${File(path!).lengthSync()}");
      return base64String;
    }
    isRecording = false;
    return null;
  }

  Widget buildWaveform(BuildContext context) {
    return AudioWaveforms(
      enableGesture: true,
      shouldCalculateScrolledPosition: true,
      size: Size(MediaQuery.of(context).size.width / 2, 50),
      recorderController: recorderController,
      waveStyle: const WaveStyle(
        waveColor: Colors.white,
        extendWaveform: true,
        showMiddleLine: false,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.only(left: 18),
      margin: const EdgeInsets.symmetric(horizontal: 15),
    );
  }

  void dispose() {
    recorderController.dispose();
  }
}
