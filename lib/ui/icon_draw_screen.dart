import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// หน้าวาดไอคอนบิลด้วยนิ้ว แล้วส่งกลับเป็น base64 PNG
class IconDrawScreen extends StatefulWidget {
  const IconDrawScreen({super.key});

  @override
  State<IconDrawScreen> createState() => _IconDrawScreenState();
}

class _IconDrawScreenState extends State<IconDrawScreen> {
  static const double _size = 240;
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  Color _penColor = const Color(0xFF1F7A6C);
  double _penWidth = 10;

  void _start(Offset point) {
    setState(() => _current = [point]);
  }

  void _update(Offset point) {
    if (_current == null) return;
    setState(() => _current!.add(point));
  }

  void _end() {
    if (_current == null) return;
    setState(() {
      _strokes.add(List<Offset>.from(_current!));
      _current = null;
    });
  }

  Future<String?> _export() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // พื้นหลังโปร่งใส
    final paint = Paint()
      ..color = _penColor
      ..strokeWidth = _penWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> stroke) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, _penWidth / 2, paint);
      }
    }

    for (final stroke in _strokes) {
      drawStroke(stroke);
    }
    if (_current != null) drawStroke(_current!);

    final image = await recorder.endRecording().toImage(
          _size.toInt(),
          _size.toInt(),
        );
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final Uint8List bytes = byteData.buffer.asUint8List();
    return base64Encode(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('วาดไอคอนบิล'),
        actions: [
          IconButton(
            tooltip: 'ล้างภาพ',
            onPressed: () => setState(() {
              _strokes.clear();
              _current = null;
            }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanStart: (d) {
                          final box = context.findRenderObject() as RenderBox;
                          _start(box.globalToLocal(d.globalPosition));
                        },
                        onPanUpdate: (d) {
                          final box = context.findRenderObject() as RenderBox;
                          _update(box.globalToLocal(d.globalPosition));
                        },
                        onPanEnd: (_) => _end(),
                        child: CustomPaint(
                          painter: _StrokePainter(
                            strokes: _strokes,
                            current: _current,
                            color: _penColor,
                            width: _penWidth,
                          ),
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in _palette)
                    GestureDetector(
                      onTap: () => setState(() => _penColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: color == _penColor
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                min: 4,
                max: 24,
                divisions: 10,
                value: _penWidth,
                label: '${_penWidth.toInt()}',
                onChanged: (v) => setState(() => _penWidth = v),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final data = await _export();
                  // ignore: use_build_context_synchronously
                  if (mounted) Navigator.pop(context, data);
                },
                icon: const Icon(Icons.check),
                label: const Text('ใช้ภาพนี้'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _palette = <Color>[
  Color(0xFF1F7A6C),
  Color(0xFF1976D2),
  Color(0xFFD32F2F),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFF388E3C),
  Color(0xFF424242),
  Color(0xFF00838F),
];

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.strokes,
    required this.current,
    required this.color,
    required this.width,
  });

  final List<List<Offset>> strokes;
  final List<Offset>? current;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void draw(List<Offset> stroke) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, width / 2, paint);
      }
    }

    for (final stroke in strokes) {
      draw(stroke);
    }
    if (current != null) draw(current!);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
