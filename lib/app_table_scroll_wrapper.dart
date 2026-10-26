import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

class AppTableScrollWrapper extends StatefulWidget {
  final Widget child;
  final double initialScale;
  final double minScale;
  final double maxScale;
  final String? tableTitle;
  final List<Widget>? extraActions;
  final bool pinHeader;

  const AppTableScrollWrapper({
    super.key,
    required this.child,
    this.initialScale = 1.0,
    this.minScale = 0.70,
    this.maxScale = 1.50,
    this.tableTitle,
    this.extraActions,
    this.pinHeader = false,
  });

  @override
  State<AppTableScrollWrapper> createState() => _AppTableScrollWrapperState();
}

class _AppTableScrollWrapperState extends State<AppTableScrollWrapper> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late double _scale;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialScale;
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _scale = (_scale + 0.10).clamp(widget.minScale, widget.maxScale);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale - 0.10).clamp(widget.minScale, widget.maxScale);
    });
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ألوان شريط السحب والمسار
    final trackColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final thumbColor = const Color(0xFF0EA5E9).withOpacity(0.85);

    return LayoutBuilder(builder: (context, constraints) {
      final bounded = constraints.hasBoundedHeight;

      return Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط أدوات التحكم بالجدول (العنوان، التكبير/التصغير، وإعادة الضبط)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                if (widget.tableTitle != null) ...[
                  const Icon(Icons.table_chart_rounded,
                      size: 18, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 8),
                  Text(
                    widget.tableTitle!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 14),
                ],
                const Spacer(),
                if (widget.extraActions != null) ...widget.extraActions!,

                // أدوات التكبير والتصغير
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تصغير الجدول (Zoom Out)',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.zoom_out_rounded, size: 18),
                        onPressed: _scale > widget.minScale ? _zoomOut : null,
                      ),
                      InkWell(
                        onTap: _resetZoom,
                        borderRadius: BorderRadius.circular(4),
                        child: Tooltip(
                          message:
                              'إعادة التكبير للوضع الافتراضي (100%)\nيمكنك استخدام Ctrl + عجلة الفأرة أيضاً',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              '${(_scale * 100).round()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Consolas',
                                color: _scale == 1.0
                                    ? null
                                    : const Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'تكبير الجدول (Zoom In)',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.zoom_in_rounded, size: 18),
                        onPressed: _scale < widget.maxScale ? _zoomIn : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // مساحة الجدول مع شريط السحب الأفقي والرأسي
          _flex(
            bounded,
            Listener(
              // دعم اختصار ويندوز: Ctrl + عجلة الماوس لتكبير وتصغير الجدول
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent &&
                    (HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isMetaPressed)) {
                  if (pointerSignal.scrollDelta.dy < 0) {
                    _zoomIn();
                  } else if (pointerSignal.scrollDelta.dy > 0) {
                    _zoomOut();
                  }
                }
              },
              child: ScrollConfiguration(
                // تمكين السحب المباشر بواسطة الماوس وشاشات اللمس
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: RawScrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 10,
                  radius: const Radius.circular(5),
                  thumbColor: thumbColor,
                  trackColor: trackColor,
                  notificationPredicate: (notif) =>
                      notif.metrics.axis == Axis.vertical,
                  child: RawScrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 13, // خط سحب أفقي عريض وواضح لسحب الجدول
                    radius: const Radius.circular(6),
                    thumbColor: thumbColor,
                    trackColor: trackColor,
                    notificationPredicate: (notif) =>
                        notif.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: MediaQuery(
                          // تكبير أو تصغير نصوص الجدول برمجياً دون فقدان الجودة
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.linear(_scale),
                          ),
                          child: Theme(
                            // مواءمة ارتفاع الصفوف والمسافات مع نسبة التكبير الحالية
                            data: theme.copyWith(
                              dataTableTheme: DataTableThemeData(
                                headingRowHeight:
                                    (46 * _scale).clamp(28.0, 90.0),
                                dataRowMinHeight:
                                    (46 * _scale).clamp(26.0, 90.0),
                                dataRowMaxHeight:
                                    (58 * _scale).clamp(32.0, 110.0),
                                columnSpacing: (18 * _scale).clamp(10.0, 48.0),
                                horizontalMargin:
                                    (16 * _scale).clamp(8.0, 40.0),
                              ),
                            ),
                            child: widget.pinHeader
                                ? _PinnedTableHeader(
                                    controller: _verticalController,
                                    height: widget.child is DataTable
                                        ? ((widget.child as DataTable)
                                                .headingRowHeight ??
                                            46 * _scale)
                                        : 46 * _scale,
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    child: widget.child,
                                  )
                                : widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  // Expanded فقط عند وجود ارتفاع محدود، وإلا يُترك الجدول بحجمه الطبيعي
  Widget _flex(bool bounded, Widget w) => bounded ? Expanded(child: w) : w;
}

/// Repaints the original heading at the viewport edge, preserving column widths
/// and routing pointer events back to its original sort/filter controls.
class _PinnedTableHeader extends SingleChildRenderObjectWidget {
  const _PinnedTableHeader(
      {required this.controller,
      required this.height,
      required this.color,
      required super.child});
  final ScrollController controller;
  final double height;
  final Color color;

  @override
  _PinnedTableRender createRenderObject(BuildContext context) =>
      _PinnedTableRender(controller, height, color);

  @override
  void updateRenderObject(
      BuildContext context, _PinnedTableRender renderObject) {
    renderObject.update(controller, height, color);
  }
}

class _PinnedTableRender extends RenderProxyBox {
  _PinnedTableRender(this.controller, this.headingHeight, this.color);
  ScrollController controller;
  double headingHeight;
  Color color;
  double get scrollOffset => controller.hasClients
      ? controller.offset.clamp(0.0,
          size.height - headingHeight < 0 ? 0.0 : size.height - headingHeight)
      : 0;

  void update(ScrollController next, double height, Color background) {
    if (controller != next) {
      if (attached) controller.removeListener(markNeedsPaint);
      controller = next;
      if (attached) controller.addListener(markNeedsPaint);
    }
    headingHeight = height;
    color = background;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    controller.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    controller.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final dy = scrollOffset;
    if (dy <= 0 || child == null) return;
    final pinnedOffset = offset + Offset(0, dy);
    context.pushClipRect(needsCompositing, pinnedOffset,
        Rect.fromLTWH(0, 0, size.width, headingHeight), (ctx, origin) {
      ctx.canvas.drawRect(
          Rect.fromLTWH(origin.dx, origin.dy, size.width, headingHeight),
          Paint()..color = color);
      ctx.paintChild(child!, origin);
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final dy = scrollOffset;
    if (dy > 0 && position.dy >= dy && position.dy < dy + headingHeight) {
      return result.addWithPaintOffset(
          offset: Offset(0, dy),
          position: position,
          hitTest: (result, local) => child!.hitTest(result, position: local));
    }
    return super.hitTestChildren(result, position: position);
  }
}
