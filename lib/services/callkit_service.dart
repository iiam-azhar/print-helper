// import 'dart:async';
// import 'package:flutter_callkit_incoming/entities/android_params.dart';
// import 'package:flutter_callkit_incoming/entities/call_event.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/ios_params.dart';
// import 'package:flutter_callkit_incoming/entities/notification_params.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// import 'package:uuid/uuid.dart';

// class CallKitService {
//   factory CallKitService() => _instance;
//   CallKitService._();
//   static final CallKitService _instance = CallKitService._();

//   static const Uuid _uuid = Uuid();

//   /// Listen to call events (Accept, Decline, End, etc.)
//   void listenToEvents({
//     required Function() onAccept,
//     required Function() onDecline,
//     required Function() onEnd,
//   }) {
//     FlutterCallkitIncoming.onEvent.listen((event) {
//       if (event == null) return;
//       switch (event.event) {
//         case Event.actionCallAccept:
//           onAccept();
//           break;
//         case Event.actionCallDecline:
//           onDecline();
//           break;
//         case Event.actionCallEnded:
//           onEnd();
//           break;
//         case Event.actionCallTimeout:
//           // CallKit functionality hidden.
//           // All code in this file has been commented out or removed.
//         default:
