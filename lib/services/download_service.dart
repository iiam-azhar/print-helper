import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
// ignore: unused_import
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/widgets/toasts.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse result) {
  debugPrint('Notification background action detected: ${result.actionId}');
  if (result.actionId == 'cancel_download' && result.id != null) {
     // This will be handled in the main isolate if showsUserInterface is true,
     // but we register it here just in case.
     DownloadService.instance.cancelDownload(result.id!);
  }
}

class DownloadService {
  static final DownloadService instance = DownloadService._();
  DownloadService._();

  static const _scannerChannel = MethodChannel('com.printhelper.print_helper/media_scanner');

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio();
  final Map<int, CancelToken> _cancelTokens = {};

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification action detected: ${details.actionId} for ID: ${details.id}');
        if (details.actionId == 'cancel_download' && details.id != null) {
          cancelDownload(details.id!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    
    // Create Android Notification Channel
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        'download_channel',
        'Downloads',
        description: 'Notifications for file downloads',
        importance: Importance.low,
      ));
    }

    _isInitialized = true;
  }

  Future<void> cancelDownload(int notificationId) async {
    final token = _cancelTokens[notificationId];
    debugPrint('Attempting to cancel download for ID: $notificationId (Token found: ${token != null})');
    if (token != null && !token.isCancelled) {
      token.cancel("User cancelled download");
      _cancelTokens.remove(notificationId);
      await _notifications.cancel(notificationId);
      showToast(message: 'Download cancelled');
    } else {
      // In case token is gone (separate isolate), we still clear the notification
      await _notifications.cancel(notificationId);
    }
  }

  Future<void> downloadFile({
    required String url,
    required String fileName,
    Map<String, dynamic>? headers,
  }) async {
    try {
      await init();

      final int notificationId = fileName.hashCode;

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/Printhelper');
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        } catch (e) {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            dir = Directory('${extDir.path}/Printhelper');
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
          }
        }
      } else {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          dir = Directory('${downloadsDir.path}/Printhelper');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
        }
      }

      if (dir == null) {
        throw Exception("Could not determine download directory");
      }
      
      final savePath = '${dir.path}/$fileName';

      // Initial notification
      final cancelToken = CancelToken();
      _cancelTokens[notificationId] = cancelToken;

      _showProgressNotification(notificationId, fileName, 0);
      int lastReportedProgress = 0;

      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            // Only update notification if progress has increased by at least 3%
            // to avoid bottlenecking the download with UI updates.
            if ((progress - lastReportedProgress >= 3 || progress == 100) && progress < 100) {
              lastReportedProgress = progress;
              _showProgressNotification(notificationId, fileName, progress);
            }
          }
        },
      );

      _cancelTokens.remove(notificationId);
      await _notifications.cancel(notificationId);
      _showCompletedNotification(notificationId, fileName, savePath);

      if (Platform.isAndroid) {
        try {
          await _scannerChannel.invokeMethod('scanFile', {'path': savePath});
        } catch (e) {
          debugPrint("Media scanner error: $e");
        }
      }

      showToast(message: 'File downloaded to: $savePath');
    } on DioException catch (de) {
      final int notificationId = fileName.hashCode;
      if (de.type == DioExceptionType.cancel) {
        debugPrint('Download cancelled: $fileName');
        _cancelTokens.remove(notificationId);
        return;
      }
      debugPrint('Download Error for $fileName: $de');
      _showErrorNotification(notificationId, fileName);
    } catch (e) {
      debugPrint('Download Error for $fileName: $e');
      final int notificationId = fileName.hashCode;
      _showErrorNotification(notificationId, fileName);
      rethrow;
    } finally {
      _cancelTokens.remove(fileName.hashCode);
    }
  }

  void _showProgressNotification(int id, String fileName, int progress) {
    _notifications.show(
      id,
      'Downloading $fileName',
      '$progress%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Notifications for file downloads',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          ongoing: true,
          autoCancel: false,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'cancel_download',
              'Cancel',
              cancelNotification: true,
              showsUserInterface: true, // Crucial for triggering callback in main isolate
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          subtitle: 'Downloading $progress%',
        ),
      ),
    );
  }

  void _showCompletedNotification(int id, String fileName, String path) {
    _notifications.show(
      id,
      'Download Completed',
      fileName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Notifications for file downloads',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          subtitle: 'Success',
        ),
      ),
    );
  }

  void _showErrorNotification(int id, String fileName) {
    _notifications.show(
      id,
      'Download Failed',
      'Failed to download $fileName',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          subtitle: 'Failed',
        ),
      ),
    );
  }
}
