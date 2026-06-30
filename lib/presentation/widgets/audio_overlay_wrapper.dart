import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/audio_notification_service.dart';
import 'audio_overlay_widget.dart';

/// Wrapper que escucha eventos de audio y muestra el overlay automáticamente.
/// Se debe usar en las páginas principales para que el overlay aparezca
/// cuando se reproduce audio y desaparezca cuando se cambia de vista.
class AudioOverlayWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final AudioOverlayPosition position;

  const AudioOverlayWrapper({
    super.key,
    required this.child,
    this.enabled = true,
    this.position = AudioOverlayPosition.bottom,
  });

  @override
  State<AudioOverlayWrapper> createState() => _AudioOverlayWrapperState();
}

class _AudioOverlayWrapperState extends State<AudioOverlayWrapper> {
  StreamSubscription<AudioEvent>? _subscription;
  bool _showOverlay = false;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _subscribeToAudioEvents();
    }
  }

  @override
  void didUpdateWidget(AudioOverlayWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _subscribeToAudioEvents();
      } else {
        _unsubscribeFromAudioEvents();
        _hideOverlay();
      }
    }
  }

  void _subscribeToAudioEvents() {
    _subscription = AudioNotificationService.onAudioEvent.listen((event) {
      if (!mounted) return;

      switch (event.type) {
        case AudioEventType.playing:
          setState(() {
            _showOverlay = true;
            _currentText = event.displayText ?? 'Reproduciendo audio';
          });
          break;
        case AudioEventType.stopped:
          _hideOverlay();
          break;
      }
    });
  }

  void _unsubscribeFromAudioEvents() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _hideOverlay() {
    if (mounted) {
      setState(() {
        _showOverlay = false;
      });
    }
  }

  @override
  void dispose() {
    _unsubscribeFromAudioEvents();
    AudioOverlayManager.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          Positioned(
            top: widget.position == AudioOverlayPosition.top
                ? MediaQuery.of(context).padding.top + 16
                : null,
            bottom: widget.position == AudioOverlayPosition.bottom
                ? 120
                : null,
            left: 0,
            right: 0,
            child: AudioOverlayWidget(
              text: _currentText,
              isVisible: _showOverlay,
              onDismiss: _hideOverlay,
              position: widget.position,
            ),
          ),
      ],
    );
  }
}