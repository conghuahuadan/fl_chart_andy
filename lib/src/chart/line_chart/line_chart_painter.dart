import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:flutter/material.dart';

/// Paints [LineChartData] in the canvas, it can be used in a [CustomPainter]
class LineChartPainter {
  /// Paints [dataList] into canvas, it is the animating [LineChartData],
  /// [targetData] is the animation's target and remains the same
  /// during animation, then we should use it  when we need to show
  /// tooltips or something like that, because [dataList] is changing constantly.
  ///
  /// [textScale] used for scaling texts inside the chart,
  /// parent can use [MediaQuery.textScaleFactor] to respect
  /// the system's font size.
  LineChartPainter() : super() {
    _barPaint = Paint()..style = PaintingStyle.stroke;

    _barAreaPaint = Paint()..style = PaintingStyle.fill;

    _clearBarAreaPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x00000000)
      ..blendMode = BlendMode.dstIn;
  }

  late Paint _barPaint;
  late Paint _barAreaPaint;
  late Paint _clearBarAreaPaint;

  /// Paints [LineChartData] into the provided canvas.
  void paint(
    BuildContext context,
    CanvasWrapper canvasWrapper,
      LineChartData data,
  ) {
    if (data.lineBarsData.isEmpty) {
      return;
    }
    /// draw each line independently on the chart
    for (var i = 0; i < data.lineBarsData.length; i++) {
      final barData = data.lineBarsData[i];

      if (!barData.show) {
        continue;
      }

      drawBarLine(canvasWrapper, barData, data);
    }
  }

  List<List<FlSpot>> splitByNullSpots(List<FlSpot> spots) {
    final barList = <List<FlSpot>>[[]];

    // handle nullability by splitting off the list into multiple
    // separate lists when separated by nulls
    for (final spot in spots) {
      if (spot.isNotNull()) {
        barList.last.add(spot);
      } else if (barList.last.isNotEmpty) {
        barList.add([]);
      }
    }
    // remove last item if one or more last spots were null
    if (barList.last.isEmpty) {
      barList.removeLast();
    }
    return barList;
  }

  @visibleForTesting
  void drawBarLine(
    CanvasWrapper canvasWrapper,
    LineChartBarData barData,
      LineChartData data,
  ) {
    final viewSize = canvasWrapper.size;
    final barList = splitByNullSpots(barData.spots);

    // paint each sublist that was built above
    // bar is passed in separately from barData
    // because barData is the whole line
    // and bar is a piece of that line
    for (final bar in barList) {
      final barPath = generateBarPath(viewSize, barData, bar, data);

      final belowBarPath =
          generateBelowBarPath(viewSize, barData, barPath, bar, data);

      final completelyFillAboveBarPath = generateAboveBarPath(
        viewSize,
        barData,
        barPath,
        bar,
        data,
        fillCompletely: true,
      );

      drawBelowBar(
        canvasWrapper,
        belowBarPath,
        completelyFillAboveBarPath,
        data,
        barData,
      );
      drawBar(canvasWrapper, barPath, barData, data);
    }
  }

  /// Generates a path, based on [LineChartBarData.isStepChart] for step style, and normal style.
  @visibleForTesting
  Path generateBarPath(
    Size viewSize,
    LineChartBarData barData,
    List<FlSpot> barSpots,
      LineChartData data, {
    Path? appendToPath,
  }) {
    return generateNormalBarPath(
      viewSize,
      barData,
      barSpots,
      data,
      appendToPath: appendToPath,
    );
  }

  /// firstly we generate the bar line that we should draw,
  /// then we reuse it to fill below bar space.
  /// there is two type of barPath that generate here,
  /// first one is the sharp corners line on spot connections
  /// second one is curved corners line on spot connections,
  /// and we use isCurved to find out how we should generate it,
  /// If you want to concatenate paths together for creating an area between
  /// multiple bars for example, you can pass the appendToPath
  @visibleForTesting
  Path generateNormalBarPath(
    Size viewSize,
    LineChartBarData barData,
    List<FlSpot> barSpots,
      LineChartData data, {
    Path? appendToPath,
  }) {
    final path = appendToPath ?? Path();
    final size = barSpots.length;

    var temp = Offset.zero;

    final x = getPixelX(barSpots[0].x, viewSize, data);
    final y = getPixelY(barSpots[0].y, viewSize, data);
    if (appendToPath == null) {
      path.moveTo(x, y);
      if (size == 1) {
        path.lineTo(x, y);
      }
    } else {
      path.lineTo(x, y);
    }
    for (var i = 1; i < size; i++) {
      /// CurrentSpot
      final current = Offset(
        getPixelX(barSpots[i].x, viewSize, data),
        getPixelY(barSpots[i].y, viewSize, data),
      );

      /// previous spot
      final previous = Offset(
        getPixelX(barSpots[i - 1].x, viewSize, data),
        getPixelY(barSpots[i - 1].y, viewSize, data),
      );

      /// next point
      final next = Offset(
        getPixelX(barSpots[i + 1 < size ? i + 1 : i].x, viewSize, data),
        getPixelY(barSpots[i + 1 < size ? i + 1 : i].y, viewSize, data),
      );

      final controlPoint1 = previous + temp;

      /// if the isCurved is false, we set 0 for smoothness,
      /// it means we should not have any smoothness then we face with
      /// the sharped corners line
      final smoothness = 0.0;
      temp = ((next - previous) / 2) * smoothness;

      final controlPoint2 = current - temp;

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    return path;
  }

  /// it generates below area path using a copy of [barPath],
  /// if cutOffY is provided by the [BarAreaData], it cut the area to the provided cutOffY value,
  /// if [fillCompletely] is true, the cutOffY will be ignored,
  /// and a completely filled path will return,
  @visibleForTesting
  Path generateBelowBarPath(
    Size viewSize,
    LineChartBarData barData,
    Path barPath,
    List<FlSpot> barSpots,
      LineChartData data, {
    bool fillCompletely = false,
  }) {
    final belowBarPath = Path.from(barPath);

    /// Line To Bottom Right
    var x = getPixelX(barSpots[barSpots.length - 1].x, viewSize, data);
    double y;
    if (!fillCompletely && barData.belowBarData.applyCutOffY) {
      y = getPixelY(barData.belowBarData.cutOffY, viewSize, data);
    } else {
      y = viewSize.height;
    }
    belowBarPath.lineTo(x, y);

    /// Line To Bottom Left
    x = getPixelX(barSpots[0].x, viewSize, data);
    if (!fillCompletely && barData.belowBarData.applyCutOffY) {
      y = getPixelY(barData.belowBarData.cutOffY, viewSize, data);
    } else {
      y = viewSize.height;
    }
    belowBarPath.lineTo(x, y);

    /// Line To Top Left
    x = getPixelX(barSpots[0].x, viewSize, data);
    y = getPixelY(barSpots[0].y, viewSize, data);
    belowBarPath
      ..lineTo(x, y)
      ..close();

    return belowBarPath;
  }

  /// it generates above area path using a copy of [barPath],
  /// if cutOffY is provided by the [BarAreaData], it cut the area to the provided cutOffY value,
  /// if [fillCompletely] is true, the cutOffY will be ignored,
  /// and a completely filled path will return,
  @visibleForTesting
  Path generateAboveBarPath(
    Size viewSize,
    LineChartBarData barData,
    Path barPath,
    List<FlSpot> barSpots,
      LineChartData data, {
    bool fillCompletely = false,
  }) {
    final aboveBarPath = Path.from(barPath);

    /// Line To Top Right
    var x = getPixelX(barSpots[barSpots.length - 1].x, viewSize, data);
    double y;
    y = 0.0;

    aboveBarPath.lineTo(x, y);

    /// Line To Top Left
    x = getPixelX(barSpots[0].x, viewSize, data);
    y = 0.0;

    aboveBarPath.lineTo(x, y);

    /// Line To Bottom Left
    x = getPixelX(barSpots[0].x, viewSize, data);
    y = getPixelY(barSpots[0].y, viewSize, data);
    aboveBarPath
      ..lineTo(x, y)
      ..close();

    return aboveBarPath;
  }

  /// firstly we draw [belowBarPath], then if cutOffY value is provided in [BarAreaData],
  /// [belowBarPath] maybe draw over the main bar line,
  /// then to fix the problem we use [filledAboveBarPath] to clear the above section from this draw.
  @visibleForTesting
  void drawBelowBar(
    CanvasWrapper canvasWrapper,
    Path belowBarPath,
    Path filledAboveBarPath,
      LineChartData data,
    LineChartBarData barData,
  ) {
    if (!barData.belowBarData.show) {
      return;
    }

    final viewSize = canvasWrapper.size;

    final belowBarLargestRect = Rect.fromLTRB(
      getPixelX(barData.mostLeftSpot.x, viewSize, data),
      getPixelY(barData.mostTopSpot.y, viewSize, data),
      getPixelX(barData.mostRightSpot.x, viewSize, data),
      viewSize.height,
    );

    final belowBar = barData.belowBarData;
    _barAreaPaint.setColorOrGradient(
      belowBar.color,
      belowBar.gradient,
      belowBarLargestRect,
    );

    if (barData.belowBarData.applyCutOffY) {
      canvasWrapper.saveLayer(
        Rect.fromLTWH(0, 0, viewSize.width, viewSize.height),
        Paint(),
      );
    }

    canvasWrapper.drawPath(belowBarPath, _barAreaPaint);

    // clear the above area that get out of the bar line
    if (barData.belowBarData.applyCutOffY) {
      canvasWrapper
        ..drawPath(filledAboveBarPath, _clearBarAreaPaint)
        ..restore();
    }
  }

  /// draw the main bar line by the [barPath]
  @visibleForTesting
  void drawBar(
    CanvasWrapper canvasWrapper,
    Path barPath,
    LineChartBarData barData,
      LineChartData data,
  ) {
    if (!barData.show) {
      return;
    }
    final viewSize = canvasWrapper.size;

    _barPaint
      ..strokeCap = barData.isStrokeCapRound ? StrokeCap.round : StrokeCap.butt
      ..strokeJoin =
          StrokeJoin.round;

    final rectAroundTheLine = Rect.fromLTRB(
      getPixelX(barData.mostLeftSpot.x, viewSize, data),
      getPixelY(barData.mostTopSpot.y, viewSize, data),
      getPixelX(barData.mostRightSpot.x, viewSize, data),
      getPixelY(barData.mostBottomSpot.y, viewSize, data),
    );
    _barPaint
      ..setColorOrGradient(
        barData.color,
        barData.gradient,
        rectAroundTheLine,
      )
      ..maskFilter = null
      ..strokeWidth = barData.barWidth
      ..transparentIfWidthIsZero();

    canvasWrapper.drawPath(barPath, _barPaint);
  }

  double getPixelX(double spotX, Size viewSize, LineChartData data) {
    final deltaX = data.maxX - data.minX;
    if (deltaX == 0.0) {
      return 0;
    }
    return ((spotX - data.minX) / deltaX) * viewSize.width;
  }

  /// With this function we can convert our [FlSpot] y
  /// to the view base axis y.
  double getPixelY(double spotY, Size viewSize,LineChartData data) {
    final deltaY = data.maxY - data.minY;
    if (deltaY == 0.0) {
      return viewSize.height;
    }
    return viewSize.height - (((spotY - data.minY) / deltaY) * viewSize.height);
  }
}

extension PaintExtension on Paint {
  /// Hides the paint's color, if strokeWidth is zero
  void transparentIfWidthIsZero() {
    if (strokeWidth == 0) {
      shader = null;
      color = color.withOpacity(0);
    }
  }

  void setColorOrGradient(Color? color, Gradient? gradient, Rect rect) {
    if (gradient != null) {
      this.color = Colors.black;
      shader = gradient.createShader(rect);
    } else {
      this.color = color ?? Colors.transparent;
      shader = null;
    }
  }
}