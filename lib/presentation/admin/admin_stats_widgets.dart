import 'dart:math' as math;

import 'package:eflutter/core/loading/loading_widget.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

// Màu theo Figma P6·1: series theo thứ tự cố định, chữ luôn dùng màu chữ (không dùng màu series).
const statsText = Color(0xFF1F1F1F);
const statsMuted = Color(0xFF6B6B6B);
const statsLabel = Color(0xFF52514E);
const statsBorder = Color(0xFFE3E3E3);
const statsInnerBorder = Color(0xFFEEEEEE);
const statsGrid = Color(0xFFEFEFEF);
const statsAxis = Color(0xFFC9C9C9);
const statsTrack = Color(0xFFF1F3F5);
const statsStrip = Color(0xFFF7F8FA);
const statsPrimary = Color(0xFF1A73C9);
const statsSeries1 = Color(0xFF2A78D6);
const statsSeries2 = Color(0xFFEB6834);
const statsSeries3 = Color(0xFF1BAF7A);
const statsSeries1Light = Color(0xFF9EC5F4);
const statsGood = Color(0xFF0B7A0B);
const statsGoodBg = Color(0xFFE6F4EA);
const statsBad = Color(0xFFC5221F);
const statsBadBg = Color(0xFFFCE8E6);

final _number = NumberFormat.decimalPattern('en_US');
String formatCount(num v) => _number.format(v);

const _axisStyle = TextStyle(fontSize: 11, color: statsMuted);

/// Khối lớn (Learning, Community…): tiêu đề, mô tả, nội dung; tự lo loading / lỗi / thử lại.
class StatsBlock extends StatelessWidget {
  const StatsBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.builder,
    this.minHeight = 320,
  });
  final String title;
  final String subtitle;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: statsBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: statsText,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: statsMuted)),
        const SizedBox(height: 20),
        if (loading)
          SizedBox(
            height: minHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  const AppLoader(),
                  Text(
                    'Loading ${title.toLowerCase()} stats…',
                    style: const TextStyle(fontSize: 12, color: statsMuted),
                  ),
                ],
              ),
            ),
          )
        else if (error != null)
          SizedBox(
            height: minHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: statsBadBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      SolarIconsOutline.dangerCircle,
                      color: Color(0xFFD93025),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Couldn't load ${title.toLowerCase()} stats",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: statsText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$error\nOther blocks are unaffected.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: statsMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statsPrimary,
                      side: const BorderSide(color: statsPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          builder(context),
      ],
    ),
  );
}

/// Dải tóm tắt nền xám: mỗi ô một nhãn, một số và ghi chú phụ.
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.items});
  final List<(String label, String value, String? note)> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: statsStrip,
      borderRadius: BorderRadius.circular(8),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, (label, value, note)) in items.indexed) ...[
            if (i > 0)
              const VerticalDivider(width: 1, thickness: 1, color: statsBorder),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: statsMuted),
                    ),
                    Text.rich(
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: statsText,
                        ),
                        children: [
                          if (note != null)
                            TextSpan(
                              text: '  $note',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: statsMuted,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Ô biểu đồ viền nhạt bên trong một khối.
class ChartPanel extends StatelessWidget {
  const ChartPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.legend = const [],
    this.trailing,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final List<(String, Color)> legend;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: BoxDecoration(
      border: Border.all(color: statsInnerBorder),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statsText,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 12, color: statsMuted),
                    ),
                ],
              ),
            ),
            if (legend.isNotEmpty)
              Wrap(
                spacing: 14,
                children: [
                  for (final (name, color) in legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 6,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: statsLabel,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

/// Thông báo trạng thái rỗng giữ nguyên chiều cao biểu đồ.
class EmptyChart extends StatelessWidget {
  const EmptyChart({super.key, required this.height, required this.message});
  final double height;
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: statsMuted),
      ),
    ),
  );
}

/// Bước lưới trục Y "đẹp" (1, 2, 5 × 10ⁿ) để có khoảng 4 vạch.
double niceInterval(num max) {
  if (max <= 4) return 1;
  final raw = max / 4;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  for (final step in [1, 2, 5, 10]) {
    if (raw <= step * magnitude) return step * magnitude;
  }
  return 10 * magnitude;
}

String _dayLabel(String day) => DateFormat('d MMM').format(DateTime.parse(day));

FlTitlesData _titles({
  required double interval,
  required int count,
  required String Function(int i) label,
  double reserved = 36,
}) {
  // Khoảng 6 nhãn trục X, luôn có nhãn cuối.
  final every = math.max(1, (count / 6).ceil());
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: reserved,
        interval: interval,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(meta.formattedValue, style: _axisStyle),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          if (i < 0 || i >= count || (i % every != 0 && i != count - 1)) {
            return const SizedBox.shrink();
          }
          // Nhãn sát nhãn cuối thì bỏ để không chồng chữ.
          if (i != count - 1 && count - 1 - i < every / 2) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            child: Text(label(i), style: _axisStyle),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (v) =>
      FlLine(color: v == 0 ? statsAxis : statsGrid, strokeWidth: 1),
);

const _tooltipBorder = BorderSide(color: statsBorder);
const _tooltipTitle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: statsText,
);
const _tooltipLine = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: statsLabel,
);

/// Cột chồng theo ngày; tooltip hiện ngày, từng series và tổng.
class StackedDailyColumns extends StatelessWidget {
  const StackedDailyColumns({
    super.key,
    required this.days,
    required this.values,
    required this.series,
    this.height = 240,
  });
  final List<String> days;

  /// values[i][j]: giá trị series j của ngày i.
  final List<List<int>> values;
  final List<(String, Color)> series;
  final double height;

  @override
  Widget build(BuildContext context) {
    final totals = [for (final v in values) v.fold<int>(0, (a, b) => a + b)];
    final maxTotal = totals.fold<int>(0, math.max);
    final interval = niceInterval(maxTotal);
    final maxY = math.max(interval, (maxTotal / interval).ceil() * interval);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final pitch = (box.maxWidth - 40) / math.max(days.length, 1);
          final width = (pitch * 0.55).clamp(2.0, 18.0);
          return BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: _grid(interval),
              titlesData: _titles(
                interval: interval,
                count: days.length,
                label: (i) => _dayLabel(days[i]),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.white,
                  tooltipBorder: _tooltipBorder,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  maxContentWidth: 200,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, i, rod, rodIndex) => BarTooltipItem(
                    DateFormat('d MMM yyyy').format(DateTime.parse(days[i])),
                    _tooltipTitle,
                    textAlign: TextAlign.left,
                    children: [
                      for (final (j, (name, _)) in series.indexed)
                        TextSpan(
                          text: '\n$name: ${values[i][j]}',
                          style: _tooltipLine,
                        ),
                      if (series.length > 1)
                        TextSpan(
                          text: '\nTotal: ${totals[i]}',
                          style: _tooltipLine.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              barGroups: [
                for (final (i, v) in values.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totals[i].toDouble(),
                        width: width,
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        rodStackItems: [
                          for (final (j, (_, color)) in series.indexed)
                            BarChartRodStackItem(
                              v
                                  .take(j)
                                  .fold<int>(0, (a, b) => a + b)
                                  .toDouble(),
                              v
                                  .take(j + 1)
                                  .fold<int>(0, (a, b) => a + b)
                                  .toDouble(),
                              color,
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Đường theo ngày (1–2 series); tooltip crosshair hiện ngày và giá trị.
class DailyLines extends StatelessWidget {
  const DailyLines({
    super.key,
    required this.days,
    required this.series,
    this.height = 200,
    this.fitY = false,
  });
  final List<String> days;
  final List<(String, Color, List<int>)> series;
  final double height;

  /// true: trục Y bắt đầu gần giá trị nhỏ nhất thay vì 0 (đường tích luỹ).
  final bool fitY;

  @override
  Widget build(BuildContext context) {
    final values = series.expand((s) => s.$3);
    final maxValue = values.fold<int>(0, math.max);
    final minValue = fitY && values.isNotEmpty ? values.reduce(math.min) : 0;
    final interval = niceInterval(math.max(maxValue - minValue, 1));
    final minY = (minValue / interval).floor() * interval;
    final maxY = math.max(
      minY + interval,
      (maxValue / interval).ceil() * interval,
    );
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY.toDouble(),
          maxY: maxY,
          minX: 0,
          maxX: math.max(days.length - 1, 1).toDouble(),
          borderData: FlBorderData(show: false),
          gridData: _grid(interval),
          titlesData: _titles(
            interval: interval,
            count: days.length,
            label: (i) => _dayLabel(days[i]),
            reserved: 30,
          ),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  const FlLine(color: statsAxis, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (spot, _, bar, _) => FlDotCirclePainter(
                      radius: 4,
                      color: bar.color ?? statsSeries1,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              tooltipBorder: _tooltipBorder,
              tooltipBorderRadius: BorderRadius.circular(8),
              maxContentWidth: 200,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final (k, spot) in spots.indexed)
                  LineTooltipItem(
                    k == 0
                        ? '${DateFormat('d MMM yyyy').format(DateTime.parse(days[spot.x.round()]))}\n'
                        : '',
                    _tooltipTitle,
                    textAlign: TextAlign.left,
                    children: [
                      TextSpan(
                        text: '${series[spot.barIndex].$1}: ${spot.y.round()}',
                        style: _tooltipLine,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final (_, color, values) in series)
              LineChartBarData(
                spots: [
                  for (final (i, v) in values.indexed)
                    FlSpot(i.toDouble(), v.toDouble()),
                ],
                color: color,
                barWidth: 2,
                isCurved: false,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

/// Phân bố điểm 0–10 (10 ô), kèm điểm trung bình ở tiêu đề.
class ScoreHistogram extends StatelessWidget {
  const ScoreHistogram({super.key, required this.buckets, this.height = 240});
  final List<int> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = buckets.fold<int>(0, math.max);
    final interval = niceInterval(maxValue);
    final maxY = math.max(interval, (maxValue / interval).ceil() * interval);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: _grid(interval),
            titlesData: _titles(
              interval: interval,
              count: buckets.length,
              label: (i) => '$i–${i + 1}',
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.white,
                tooltipBorder: _tooltipBorder,
                tooltipBorderRadius: BorderRadius.circular(8),
                getTooltipItem: (group, i, rod, _) => BarTooltipItem(
                  'Score $i–${i + 1}\n',
                  _tooltipTitle,
                  children: [
                    TextSpan(
                      text: '${buckets[i]} submissions',
                      style: _tooltipLine,
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (final (i, v) in buckets.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v.toDouble(),
                      width: (box.maxWidth - 40) / buckets.length - 4,
                      color: statsSeries1,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách thanh ngang: nhãn, thanh (chung một thang [max]), số, chữ phụ bên phải.
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({
    super.key,
    required this.items,
    this.max,
    this.labelWidth = 140,
    this.track = false,
    this.decimals = 0,
    this.rowGap = 10,
  });
  final List<(String label, double value, String? trailing)> items;
  final double? max;
  final double labelWidth;
  final bool track;
  final int decimals;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    final scale = max ?? items.fold<double>(0, (a, b) => math.max(a, b.$2));
    return Column(
      spacing: rowGap,
      children: [
        for (final (label, value, trailing) in items)
          Tooltip(
            message: '$label: ${value.toStringAsFixed(decimals)}',
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: statsText),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final barWidth = scale <= 0
                          ? 0.0
                          : box.maxWidth * value / scale;
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: track ? statsTrack : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 10,
                            width: math.max(barWidth, value > 0 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: statsSeries1,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    decimals == 0
                        ? formatCount(value)
                        : value.toStringAsFixed(decimals),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statsText,
                    ),
                  ),
                ),
                if (trailing != null)
                  SizedBox(
                    width: 64,
                    child: Text(
                      trailing,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: statsMuted),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Đường xu hướng nhỏ trong thẻ KPI (một series, không trục).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox(width: 64, height: 24);
    final maxY = values.fold<double>(0, math.max);
    final minY = values.fold<double>(maxY, math.min);
    return SizedBox(
      width: 64,
      height: 24,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY == minY ? minY + 1 : maxY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v),
              ],
              color: statsSeries1,
              barWidth: 2,
              dotData: FlDotData(
                checkToShowDot: (spot, _) => spot.x == values.length - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Viên tăng/giảm so với kỳ trước: mũi tên + chữ, xanh khi tốt, đỏ khi xấu.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.text, required this.up});
  final String text;
  final bool up;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: up ? statsGoodBg : statsBadBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '${up ? '▲' : '▼'} $text',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: up ? statsGood : statsBad,
      ),
    ),
  );
}
