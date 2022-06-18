import 'package:easy_table/src/internal/layout_child.dart';
import 'package:easy_table/src/internal/row_callbacks.dart';
import 'package:easy_table/src/internal/table_layout.dart';
import 'package:easy_table/src/internal/row_range.dart';
import 'package:easy_table/src/internal/table_layout_settings.dart';
import 'package:easy_table/src/internal/table_scroll_controllers.dart';
import 'package:easy_table/src/internal/table_scrollbar.dart';
import 'package:easy_table/src/internal/table_theme_metrics.dart';
import 'package:easy_table/src/last_visible_row_listener.dart';
import 'package:easy_table/src/model.dart';
import 'package:easy_table/src/row_hover_listener.dart';
import 'package:easy_table/src/theme/theme.dart';
import 'package:easy_table/src/theme/theme_data.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

@internal
class TableLayoutBuilder<ROW> extends StatelessWidget {
  const TableLayoutBuilder(
      {Key? key,
      required this.onHoverListener,
      required this.hoveredRowIndex,
      required this.scrollControllers,
      required this.multiSortEnabled,
      required this.onLastVisibleRowListener,
      required this.model,
      required this.themeMetrics,
      required this.columnsFit,
      required this.visibleRowsLength,
      required this.rowCallbacks,
      required this.onDragScroll,
      required this.scrolling})
      : super(key: key);

  final int? hoveredRowIndex;
  final OnLastVisibleRowListener? onLastVisibleRowListener;
  final OnRowHoverListener onHoverListener;
  final TableScrollControllers scrollControllers;
  final EasyTableModel<ROW>? model;
  final bool multiSortEnabled;
  final bool columnsFit;
  final int? visibleRowsLength;
  final OnDragScroll onDragScroll;
  final bool scrolling;
  final RowCallbacks<ROW> rowCallbacks;
  final TableThemeMetrics themeMetrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _builder);
  }

  Widget _builder(BuildContext context, BoxConstraints constraints) {
    final EasyTableThemeData theme = EasyTableTheme.of(context);

    TableLayoutSettings<ROW> layoutSettings = TableLayoutSettings<ROW>(
        constraints: constraints,
        model: model,
        theme: theme,
        columnsFit: columnsFit,
        offsets: scrollControllers.offsets,
        themeMetrics: themeMetrics,
        visibleRowsLength: visibleRowsLength);

    final List<LayoutChild> children = [];

    if (layoutSettings.hasVerticalScrollbar) {
      children.add(LayoutChild.verticalScrollbar(
          child: TableScrollbar(
              axis: Axis.vertical,
              contentSize: layoutSettings.contentHeight,
              scrollController: scrollControllers.vertical,
              color: theme.scrollbar.verticalColor,
              borderColor: theme.scrollbar.verticalBorderColor,
              onDragScroll: onDragScroll)));
    }

    if (themeMetrics.hasHeader) {
      children.add(LayoutChild.header(
          layoutSettings: layoutSettings,
          model: model,
          resizable: !columnsFit,
          multiSortEnabled: multiSortEnabled));
      if (layoutSettings.hasVerticalScrollbar) {
        children.add(LayoutChild.topCorner());
      }
    }

    if (layoutSettings.hasHorizontalScrollbar) {
      children.add(LayoutChild.leftPinnedHorizontalScrollbar(TableScrollbar(
          axis: Axis.horizontal,
          scrollController: scrollControllers.leftPinnedContentArea,
          color: theme.scrollbar.pinnedHorizontalColor,
          borderColor: theme.scrollbar.pinnedHorizontalBorderColor,
          contentSize: layoutSettings.leftPinnedContentWidth,
          onDragScroll: onDragScroll)));
      children.add(LayoutChild.unpinnedHorizontalScrollbar(TableScrollbar(
          axis: Axis.horizontal,
          scrollController: scrollControllers.unpinnedContentArea,
          color: theme.scrollbar.unpinnedHorizontalColor,
          borderColor: theme.scrollbar.unpinnedHorizontalBorderColor,
          contentSize: layoutSettings.unpinnedContentWidth,
          onDragScroll: onDragScroll)));
      if (layoutSettings.hasVerticalScrollbar) {
        children.add(LayoutChild.bottomCorner());
      }
    }

    children.add(LayoutChild<ROW>.rows(
        model: model,
        layoutSettings: layoutSettings,
        scrolling: scrolling,
        rowCallbacks: rowCallbacks));

    Widget layout = TableLayout<ROW>(
        layoutSettings: layoutSettings, theme: theme, children: children);
    if (onLastVisibleRowListener != null) {
      layout = NotificationListener<ScrollMetricsNotification>(
          child: layout,
          onNotification: (notification) {
            RowRange? rowRange = RowRange.build(
                scrollOffset: scrollControllers.verticalOffset,
                height: layoutSettings.cellsBounds.height,
                rowHeight: themeMetrics.rowHeight);
            if (rowRange != null) {
              onLastVisibleRowListener!(rowRange.lastIndex);
            }
            return false;
          });
    }
    return layout;
  }
}