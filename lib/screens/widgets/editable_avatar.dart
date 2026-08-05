import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../utils/image_picker_helper.dart';

/// Reusable circular avatar that fetches and shows a photo file (by
/// filename, via [fetchBytes]) or falls back to initials, with a small
/// camera-icon overlay to pick and replace it.
class EditableAvatar extends StatefulWidget {
  const EditableAvatar({
    super.key,
    required this.photoFileName,
    required this.fetchBytes,
    required this.fallbackText,
    required this.onPhotoPicked,
    this.radius = 20,
    this.backgroundColor,
    this.editable = true,
  });

  final String? photoFileName;
  final Future<List<int>> Function(String fileName) fetchBytes;
  final String fallbackText;
  final ValueChanged<String> onPhotoPicked;
  final double radius;
  final Color? backgroundColor;
  final bool editable;

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  Uint8List? _bytes;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant EditableAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoFileName != widget.photoFileName) _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    final name = widget.photoFileName;
    if (name == null || name.isEmpty) {
      if (mounted) setState(() { _bytes = null; _loadedFor = null; });
      return;
    }
    if (_loadedFor == name) return;
    try {
      final bytes = await widget.fetchBytes(name);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loadedFor = name;
      });
    } catch (_) {
      if (mounted) setState(() => _bytes = null);
    }
  }

  Future<void> _pick() async {
    final result = await pickImageAsBase64();
    if (result != null) widget.onPhotoPicked(result);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.blue.shade700,
      backgroundImage: _bytes != null ? MemoryImage(_bytes!) : null,
      child: _bytes == null
          ? Text(widget.fallbackText,
              style: TextStyle(color: Colors.white, fontSize: widget.radius * 0.55, fontWeight: FontWeight.bold))
          : null,
    );

    if (!widget.editable) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _pick,
            child: Container(
              padding: EdgeInsets.all(widget.radius * 0.15),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.camera_alt, size: widget.radius * 0.5, color: Colors.blue.shade700),
            ),
          ),
        ),
      ],
    );
  }
}
