import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/line_chart/line_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// coverage:ignore-start

/// Low level LineChart Widget.
class LineChartLeaf extends LeafRenderObjectWidget {
  const LineChartLeaf({
    super.key,
    required this.data,
  });

  final LineChartData data;

  @override
  RenderLineChart createRenderObject(BuildContext context) => RenderLineChart(
        context,
        data,
      );

  @override
  void updateRenderObject(BuildContext context, RenderLineChart renderObject) {
    renderObject
      ..data = data
      .._buildContext = context;
  }
}
// coverage:ignore-end

/// Renders our LineChart, also handles hitTest.
class RenderLineChart extends RenderBox {
  BuildContext _buildContext;

  RenderLineChart(
    BuildContext context,
    LineChartData data,
  )   : _buildContext = context,
        _data = data;

  LineChartData get data => _data;
  LineChartData _data;

  set data(LineChartData value) {
    if (_data == value) return;
    _data = value;
    markNeedsPaint();
  }

  // We couldn't mock [size] property of this class, that's why we have this
  @visibleForTesting
  Size? mockTestSize;

  @visibleForTesting
  LineChartPainter painter = LineChartPainter();


  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    painter.paint(
      _buildContext,
      CanvasWrapper(canvas, mockTestSize ?? size),
      data,
    );
    canvas.restore();
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return Size(constraints.maxWidth, constraints.maxHeight);
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
