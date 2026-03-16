import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Assuming screenutil is used
import 'package:twilio_voice/twilio_voice.dart';

class CallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  final bool
  isIncoming; // true if we accepted an incoming call, false if we started one

  const CallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool isMuted = false;
  bool isSpeakerOn = false;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenToCallEvents();
    // Ensure mic is unmuted and speaker is set to default (earpiece) when the call screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TwilioVoice.instance.call.toggleMute(false);
      await TwilioVoice.instance.call.toggleSpeaker(true);
      if (mounted) setState(() => isSpeakerOn = true);
    });
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _listenToCallEvents() {
    TwilioVoice.instance.callEventsListener.listen((event) {
      if (event == CallEvent.callEnded) {
        // Verify enum value in your version
        _endCall();
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final newMute = !isMuted;
    await TwilioVoice.instance.call.toggleMute(newMute);
    setState(() => isMuted = newMute);
  }

  Future<void> _toggleSpeaker() async {
    final newSpeaker = !isSpeakerOn;
    await TwilioVoice.instance.call.toggleSpeaker(newSpeaker);
    setState(() => isSpeakerOn = newSpeaker);
  }

  Future<void> _endCall() async {
    await TwilioVoice.instance.call.hangUp();
    // await CallKitService().endAllCalls();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1C2E), // Dark background
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 50.h),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            SizedBox(height: 20.h),
            Text(
              widget.callerName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              widget.callerNumber,
              style: TextStyle(color: Colors.white70, fontSize: 16.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              _formatDuration(_callDuration),
              style: TextStyle(color: Colors.white54, fontSize: 14.sp),
            ),
            const Spacer(),
            // Controls
            Container(
              padding: EdgeInsets.only(bottom: 50.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "mute",
                        onPressed: _toggleMute,
                        backgroundColor: isMuted
                            ? Colors.white
                            : Colors.white24,
                        child: Icon(
                          isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text("Mute", style: TextStyle(color: Colors.white)),
                    ],
                  ),

                  // End Call
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "hangup",
                        onPressed: _endCall,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text("End", style: TextStyle(color: Colors.white)),
                    ],
                  ),

                  // Speaker
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "speaker",
                        onPressed: _toggleSpeaker,
                        backgroundColor: isSpeakerOn
                            ? Colors.white
                            : Colors.white24,
                        child: Icon(
                          isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                          color: isSpeakerOn ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Speaker",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
