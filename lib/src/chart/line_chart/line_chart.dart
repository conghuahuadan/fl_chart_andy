import 'package:fl_chart/src/chart/line_chart/line_chart_painter.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LineChart extends StatefulWidget {
  const LineChart(
    this.spots,
    this.color, {
    this.chartRendererKey,
    super.key,
  });

  final Key? chartRendererKey;

  final List<SpotMo> spots;

  final Color color;

  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffeeeeee)),
      ),
      child: LineChartLeaf(
        spots: widget.spots,
        color: widget.color,
      ),
    );
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {}
}

class LineChartLeaf extends LeafRenderObjectWidget {
  const LineChartLeaf({
    super.key,
    required this.spots,
    required this.color,
  });

  final List<SpotMo> spots;
  final Color color;

  @override
  RenderLineChart createRenderObject(BuildContext context) =>
      RenderLineChart(context,  spots, color);

}

class RenderLineChart extends RenderBox {
  RenderLineChart(
      BuildContext context, List<SpotMo> spots, Color color)
      : _buildContext = context,
        _spots = spots,
        _color = color;

  BuildContext _buildContext;

  List<SpotMo> _spots;
  Color _color;

  @visibleForTesting
  LineChartPainter painter = LineChartPainter();

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    painter.paint(_buildContext, CanvasWrapper(canvas, size), _spots, _color);
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

class SpotMo {

  const SpotMo(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => '($x, $y)';

  static const SpotMo nullSpot = SpotMo(double.nan, double.nan);

  static const SpotMo zero = SpotMo(0, 0);

  bool isNull() => this == nullSpot;

  bool isNotNull() => !isNull();
}