import 'dart:math' as math;
import 'package:easy_table/src/cell.dart';
import 'package:easy_table/src/column.dart';
import 'package:easy_table/src/internal/columns_metrics.dart';
import 'package:easy_table/src/internal/divider_painter.dart';
import 'package:easy_table/src/internal/header_cell.dart';
import 'package:easy_table/src/internal/scroll_controller.dart';
import 'package:easy_table/src/internal/table_layout.dart';
import 'package:easy_table/src/model.dart';
import 'package:easy_table/src/row_callbacks.dart';
import 'package:easy_table/src/row_hover_listener.dart';
import 'package:easy_table/src/theme/header_theme_data.dart';
import 'package:easy_table/src/theme/theme.dart';
import 'package:easy_table/src/theme/theme_data.dart';
import 'package:flutter/material.dart';

/// Table view designed for a large number of data.
///
/// The type [ROW] represents the data of each row.
class EasyTable<ROW> extends StatefulWidget {
//TODO handle negative values
//TODO allow null and use defaults?
  const EasyTable(this.model,
      {Key? key,
      this.horizontalScrollController,
      this.verticalScrollController,
      this.onHoverListener,
      this.onRowTap,
      this.onRowDoubleTap,
      this.columnsFit = false,
      int? visibleRowsCount})
      : _visibleRowsCount = visibleRowsCount == null || visibleRowsCount > 0
            ? visibleRowsCount
            : null,
        super(key: key);

  final EasyTableModel<ROW>? model;
  final ScrollController? horizontalScrollController;
  final ScrollController? verticalScrollController;
  final OnRowHoverListener? onHoverListener;
  final RowDoubleTapCallback<ROW>? onRowDoubleTap;
  final RowTapCallback<ROW>? onRowTap;
  final bool columnsFit;
  final int? _visibleRowsCount;

  int? get visibleRowsCount => _visibleRowsCount;

  @override
  State<StatefulWidget> createState() => _EasyTableState<ROW>();
}

/// The [EasyTable] state.
class _EasyTableState<ROW> extends State<EasyTable<ROW>> {
  late ScrollController _verticalScrollController;
  late ScrollController _horizontalScrollController;

  final ScrollController _headerHorizontalScrollController = ScrollController();

  int? _hoveredRowIndex;
  void _setHoveredRowIndex(int? value) {
    if (_hoveredRowIndex != value) {
      setState(() {
        _hoveredRowIndex = value;
      });
      if (widget.onHoverListener != null) {
        widget.onHoverListener!(_hoveredRowIndex);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    widget.model?.addListener(_rebuild);

    _horizontalScrollController =
        widget.horizontalScrollController ?? EasyTableScrollController();
    _verticalScrollController =
        widget.verticalScrollController ?? EasyTableScrollController();

    _horizontalScrollController.addListener(_syncHorizontalScroll);
  }

  @override
  void dispose() {
    widget.model?.removeListener(_rebuild);
    _horizontalScrollController.removeListener(_syncHorizontalScroll);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EasyTable<ROW> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model?.removeListener(_rebuild);
      widget.model?.addListener(_rebuild);
    }
    if (widget.horizontalScrollController != null) {
      _horizontalScrollController.removeListener(_syncHorizontalScroll);
      _horizontalScrollController = widget.horizontalScrollController!;
      _horizontalScrollController.addListener(_syncHorizontalScroll);
    }
    if (widget.verticalScrollController != null) {
      _verticalScrollController = widget.verticalScrollController!;
    }
  }

  void _rebuild() {
    setState(() {});
  }

  void _syncHorizontalScroll() {
    if (_headerHorizontalScrollController.hasClients) {
      _headerHorizontalScrollController
          .jumpTo(_horizontalScrollController.offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget table = LayoutBuilder(builder: (context, constraints) {
      if (widget.model != null) {
        EasyTableModel<ROW> model = widget.model!;
        EasyTableThemeData theme = EasyTableTheme.of(context);

        double contentWidth = constraints.maxWidth;
        if (widget.columnsFit == false) {
          contentWidth = math.max(
              contentWidth,
              model.columnsWidth +
                  (model.columnsLength * theme.columnDividerThickness));
        }

        ColumnsMetrics columnsMetrics = widget.columnsFit
            ? ColumnsMetrics.columnsFit(
                model: model,
                containerWidth: contentWidth,
                columnDividerThickness: theme.columnDividerThickness)
            : ColumnsMetrics.resizable(
                model: model,
                columnDividerThickness: theme.columnDividerThickness);

        double rowHeight = theme.cell.contentHeight;
        if (theme.cell.padding != null) {
          rowHeight += theme.cell.padding!.vertical;
        }

        HeaderThemeData headerTheme = theme.header;
        double headerHeight = headerTheme.height;
        Widget? header;
        if (headerHeight > 0) {
          header = _header(
              context: context,
              model: model,
              columnsMetrics: columnsMetrics,
              contentWidth: contentWidth);
        }

        Widget body = _body(
            context: context,
            model: model,
            columnsMetrics: columnsMetrics,
            contentWidth: contentWidth,
            rowHeight: rowHeight);

        return ClipRect(
            child: TableLayout(
                header: header,
                body: body,
                rowsCount: model.rowsLength,
                visibleRowsCount: widget.visibleRowsCount,
                rowHeight: rowHeight,
                headerHeight: headerHeight));
      }
      return Container();
    });
    EasyTableThemeData theme = EasyTableTheme.of(context);
    if (theme.decoration != null) {
      table = Container(child: table, decoration: theme.decoration);
    }
    return table;
  }

  /// Builds the header
  Widget _header(
      {required BuildContext context,
      required EasyTableModel<ROW> model,
      required ColumnsMetrics columnsMetrics,
      required double contentWidth}) {
    List<Widget> children = [];
    for (int columnIndex = 0;
        columnIndex < model.columnsLength;
        columnIndex++) {
      EasyTableColumn<ROW> column = model.columnAt(columnIndex);
      children.add(EasyTableHeaderCell<ROW>(
          model: model, column: column, resizable: !widget.columnsFit));
    }

    Widget header = _horizontalLayout(
        context: context, columnsMetrics: columnsMetrics, children: children);

    EasyTableThemeData theme = EasyTableTheme.of(context);

    if (theme.header.columnDividerColor != null) {
      header = CustomPaint(
          child: header,
          foregroundPainter: DividerPainter(
              columnsMetrics: columnsMetrics,
              color: theme.header.columnDividerColor!));
    }

    if (theme.header.bottomBorderHeight > 0 &&
        theme.header.bottomBorderColor != null) {
      header = Container(
          child: header,
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      width: theme.header.bottomBorderHeight,
                      color: theme.header.bottomBorderColor!))));
    }

    if (widget.columnsFit) {
      return header;
    }
    // scrollable header
    return CustomScrollView(
        controller: _headerHorizontalScrollController,
        scrollDirection: Axis.horizontal,
        slivers: [SliverToBoxAdapter(child: header)]);
  }

  /// Builds the table body.
  Widget _body(
      {required BuildContext context,
      required EasyTableModel<ROW> model,
      required ColumnsMetrics columnsMetrics,
      required double contentWidth,
      required double rowHeight}) {
    EasyTableThemeData theme = EasyTableTheme.of(context);

    Widget list = ListView.builder(
        controller: _verticalScrollController,
        itemExtent: rowHeight + theme.rowDividerThickness,
        itemBuilder: (context, index) {
          return _row(
              context: context,
              model: model,
              columnsMetrics: columnsMetrics,
              visibleRowIndex: index);
        },
        itemCount: model.visibleRowsLength);

    if (theme.row.columnDividerColor != null) {
      list = CustomPaint(
          child: list,
          foregroundPainter: DividerPainter(
              columnsMetrics: columnsMetrics,
              color: theme.row.columnDividerColor!));
    }

    list =
        MouseRegion(child: list, onExit: (event) => _setHoveredRowIndex(null));

    if (widget.columnsFit) {
      return Scrollbar(
          isAlwaysShown: true,
          controller: _verticalScrollController,
          child: list);
    }

    return Scrollbar(
        isAlwaysShown: true,
        controller: _horizontalScrollController,
        child: Scrollbar(
            isAlwaysShown: true,
            controller: _verticalScrollController,
            notificationPredicate: (p) {
              return true;
            },
            child: CustomScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(
                          child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: list),
                          width: contentWidth))
                ])));
  }

  /// Builds a single table row.
  Widget _row(
      {required BuildContext context,
      required EasyTableModel<ROW> model,
      required ColumnsMetrics columnsMetrics,
      required int visibleRowIndex}) {
    EasyTableThemeData theme = EasyTableTheme.of(context);
    ROW row = model.visibleRowAt(visibleRowIndex);
    List<Widget> children = [];
    for (int columnIndex = 0;
        columnIndex < model.columnsLength;
        columnIndex++) {
      EasyTableColumn<ROW> column = model.columnAt(columnIndex);
      children.add(_cell(
          context: context,
          row: row,
          column: column,
          visibleRowIndex: visibleRowIndex));
    }

    Widget rowWidget = _horizontalLayout(
        context: context, columnsMetrics: columnsMetrics, children: children);

    if (_hoveredRowIndex == visibleRowIndex && theme.row.hoveredColor != null) {
      rowWidget = Container(
          child: rowWidget, color: theme.row.hoveredColor!(visibleRowIndex));
    } else if (theme.row.color != null) {
      rowWidget =
          Container(child: rowWidget, color: theme.row.color!(visibleRowIndex));
    }

    MouseCursor cursor = MouseCursor.defer;

    if (widget.onRowTap != null || widget.onRowDoubleTap != null) {
      cursor = SystemMouseCursors.click;
      rowWidget = GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: rowWidget,
        onDoubleTap: widget.onRowDoubleTap != null
            ? () => widget.onRowDoubleTap!(row)
            : null,
        onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
      );
    }

    rowWidget = MouseRegion(
        cursor: cursor,
        child: rowWidget,
        onEnter: (event) => _setHoveredRowIndex(visibleRowIndex));

    if (theme.rowDividerThickness > 0) {
      rowWidget = Padding(
          child: rowWidget,
          padding: EdgeInsets.only(bottom: theme.rowDividerThickness));
    }

    return rowWidget;
  }

  /// Builds a table cell.
  Widget _cell(
      {required BuildContext context,
      required ROW row,
      required EasyTableColumn<ROW> column,
      required int visibleRowIndex}) {
    EasyTableThemeData theme = EasyTableTheme.of(context);
    Widget? cell;

    if (column.cellBuilder != null) {
      cell = column.cellBuilder!(context, row);
    } else {
      final TextStyle? textStyle = theme.cell.textStyle;
      bool nullValue = false;
      if (column.stringValueMapper != null) {
        final String? value = column.stringValueMapper!(row);
        if (value != null) {
          cell = EasyTableCell.string(value: value, textStyle: textStyle);
        } else {
          nullValue = true;
        }
      } else if (column.intValueMapper != null) {
        final int? value = column.intValueMapper!(row);
        if (value != null) {
          cell = EasyTableCell.int(value: value, textStyle: textStyle);
        } else {
          nullValue = true;
        }
      } else if (column.doubleValueMapper != null) {
        final double? value = column.doubleValueMapper!(row);
        if (value != null) {
          cell = EasyTableCell.double(
              value: value,
              fractionDigits: column.fractionDigits,
              textStyle: textStyle);
        } else {
          nullValue = true;
        }
      } else if (column.objectValueMapper != null) {
        final Object? value = column.objectValueMapper!(row);
        if (value != null) {
          return EasyTableCell.string(
              value: value.toString(), textStyle: textStyle);
        } else {
          nullValue = true;
        }
      }
      if (nullValue && theme.cell.nullValueColor != null) {
        cell = Container(color: theme.cell.nullValueColor!(visibleRowIndex));
      }
    }
    return ClipRect(child: cell);
  }

  Widget _horizontalLayout(
      {required BuildContext context,
      required ColumnsMetrics columnsMetrics,
      required List<Widget> children}) {
    EasyTableThemeData theme = EasyTableTheme.of(context);
    for (int i = 0; i < children.length; i++) {
      LayoutWidth layoutWidth = columnsMetrics.columns[i];
      children[i] = SizedBox(child: children[i], width: layoutWidth.width);
      if (theme.columnDividerThickness > 0) {
        children[i] = Padding(
            child: children[i],
            padding: EdgeInsets.only(right: theme.columnDividerThickness));
      }
    }
    return Row(
        children: children, crossAxisAlignment: CrossAxisAlignment.stretch);
  }
}
