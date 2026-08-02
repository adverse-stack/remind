import 'package:flutter/material.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';
import '../widgets/overlay_widget.dart';

class OverlayManager {
  static bool _isShowing = false;

  static Future<bool> requestPermission() async {
    return await FlutterScreenOverlay.requestPermission();
  }

  static Future<bool> hasPermission() async {
    return await FlutterScreenOverlay.hasPermission();
  }

  static Future<void> showOverlay({
    required int taskId,
    required String title,
    required String description,
    required VoidCallback onComplete,
    required VoidCallback onSnooze,
  }) async {
    if (_isShowing) return;

    // Check & request permission
    bool granted = await hasPermission();
    if (!granted) {
      granted = await requestPermission();
      if (!granted) {
        // Fallback: just show a dialog in-app if overlay not allowed
        // We'll handle this in the UI layer
        return;
      }
    }

    _isShowing = true;

    // Build the overlay widget
    final overlayWidget = OverlayWidget(
      taskId: taskId,
      title: title,
      description: description,
      onComplete: () {
        _isShowing = false;
        FlutterScreenOverlay.dismissOverlay();
        onComplete();
      },
      onSnooze: () {
        _isShowing = false;
        FlutterScreenOverlay.dismissOverlay();
        onSnooze();
      },
    );

    await FlutterScreenOverlay.showOverlay(
      widget: overlayWidget,
    );
  }

  static Future<void> dismissOverlay() async {
    if (_isShowing) {
      _isShowing = false;
      await FlutterScreenOverlay.dismissOverlay();
    }
  }
}
