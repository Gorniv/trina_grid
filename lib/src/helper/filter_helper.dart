// ignore_for_file: prefer_asserts_with_message

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';

typedef SetFilterPopupHandler = void Function(
  TrinaGridStateManager? stateManager,
);

class FilterHelper {
  /// A value to identify all column searches when searching filters.
  static const String filterFieldAllColumns = 'trinaFilterAllColumns';

  /// The field name of the column that includes the field values of the column
  /// when searching for a filter.
  static const String filterFieldColumn = 'column';

  /// The field name of the column including the filter type
  /// when searching for a filter.
  static const String filterFieldType = 'type';

  /// The field name of the column containing the value to be searched
  /// when searching for a filter.
  static const String filterFieldValue = 'value';

  static const List<TrinaFilterType> defaultFilters = <TrinaFilterType>[
    TrinaFilterTypeContains(),
    TrinaFilterTypeEquals(),
    TrinaFilterTypeStartsWith(),
    TrinaFilterTypeEndsWith(),
    TrinaFilterTypeGreaterThan(),
    TrinaFilterTypeGreaterThanOrEqualTo(),
    TrinaFilterTypeLessThan(),
    TrinaFilterTypeLessThanOrEqualTo(),
    TrinaFilterTypeRegex(),
  ];

  /// Create a row to contain filter information.
  static TrinaRow createFilterRow({
    String? columnField,
    TrinaFilterType? filterType,
    String? filterValue,
    dynamic filterValueObject,
  }) {
    return TrinaRow(
      cells: <String, TrinaCell>{
        filterFieldColumn: TrinaCell(
          value: columnField ?? filterFieldAllColumns,
        ),
        filterFieldType: TrinaCell(
          value: filterType ?? const TrinaFilterTypeContains(),
        ),
        filterFieldValue: TrinaCell(
          value: filterValue ?? '',
          filterValue: filterValueObject,
        ),
      },
    );
  }

  /// Converts rows containing filter information into comparison functions.
  static FilteredListFilter<TrinaRow?>? convertRowsToFilter(
    List<TrinaRow?> rows,
    List<TrinaColumn>? enabledFilterColumns,
  ) {
    if (rows.isEmpty) {
      return null;
    }

    return (TrinaRow? row) {
      bool? flag;
      if (row == null) {
        return false;
      }
      for (final TrinaRow? e in rows) {
        if (e == null) {
          continue;
        }
        final TrinaCell? cellValue = e.cells[filterFieldType];
        if (cellValue == null) {
          continue;
        }
        final TrinaFilterType? filterType = cellValue.value as TrinaFilterType?;
        if (filterType == null) {
          continue;
        }
        if (e.cells[filterFieldColumn]!.value == filterFieldAllColumns) {
          bool? flagAllColumns;

          row.cells.forEach((String key, TrinaCell value) {
            final TrinaColumn? foundColumn =
                enabledFilterColumns?.firstWhereOrNull(
              (TrinaColumn element) => element.field == key,
            );

            if (foundColumn != null) {
              flagAllColumns = compareOr(
                flagAllColumns,
                compareByFilterType(
                  filterType: filterType,
                  base: value.value?.toString(),
                  baseObject: value.filterValue,
                  search: e.cells[filterFieldValue]?.value?.toString() ?? '',
                  searchObject: e.cells[filterFieldValue]?.filterValue,
                  column: foundColumn,
                ),
              );
            }
          });

          flag = compareAnd(flag, flagAllColumns);
        } else {
          final TrinaColumn? foundColumn =
              enabledFilterColumns?.firstWhereOrNull(
            (TrinaColumn element) =>
                element.field == e.cells[filterFieldColumn]?.value,
          );

          if (foundColumn != null) {
            flag = compareAnd(
              flag,
              compareByFilterType(
                filterType: filterType,
                base: row.cells[e.cells[filterFieldColumn]?.value]?.value
                        ?.toString() ??
                    '',
                baseObject:
                    row.cells[e.cells[filterFieldColumn]?.value]?.filterValue,
                search: e.cells[filterFieldValue]?.value?.toString() ?? '',
                searchObject: e.cells[filterFieldValue]?.filterValue,
                column: foundColumn,
              ),
            );
          }
        }
      }

      return flag ?? false;
    };
  }

  /// Converts List&lt;TrinaRow&gt; type with filtering information to Map type.
  ///
  /// [allField] determines the key value of the filter applied to the entire scope.
  /// Default is all.
  ///
  /// ```dart
  /// // The return value below is an example of the condition
  /// in which two filtering is applied with the Contains type condition to all ranges.
  /// {all: [{Contains: abc}, {Contains: 123}]}
  ///
  /// // If filtering is applied to a column, the key is the field name of the column.
  /// {column1: [{Contains: abc}]}
  /// ```
  static Map<String, List<Map<String, String>>> convertRowsToMap(
    List<TrinaRow> filterRows, {
    String allField = 'all',
  }) {
    final Map<String, List<Map<String, String>>> map =
        <String, List<Map<String, String>>>{};

    if (filterRows.isEmpty) {
      return map;
    }

    for (final TrinaRow row in filterRows) {
      String columnField = row.cells[FilterHelper.filterFieldColumn]!.value;

      if (columnField == FilterHelper.filterFieldAllColumns) {
        columnField = allField;
      }

      final String filterType =
          (row.cells[FilterHelper.filterFieldType]!.value as TrinaFilterType)
              .title;

      final filterValue = row.cells[FilterHelper.filterFieldValue]!.value;

      if (map.containsKey(columnField)) {
        map[columnField]!.add(<String, String>{filterType: filterValue});
      } else {
        map[columnField] = <Map<String, String>>[
          <String, String>{filterType: filterValue},
        ];
      }
    }

    return map;
  }

  /// Whether [column] is included in [filteredRows].
  ///
  /// That is, check if it is a filtered column.
  /// If there is a search condition for all columns in [filteredRows],
  /// it is regarded as a filtering column.
  static bool isFilteredColumn(
    TrinaColumn column,
    List<TrinaRow?>? filteredRows,
  ) {
    if (filteredRows == null || filteredRows.isEmpty) {
      return false;
    }

    for (TrinaRow? row in filteredRows) {
      if (row!.cells[filterFieldColumn]!.value == filterFieldAllColumns ||
          row.cells[filterFieldColumn]!.value == column.field) {
        return true;
      }
    }

    return false;
  }

  /// Opens a pop-up for filtering.
  static void filterPopup(FilterPopupState popupState) {
    TrinaGridPopup(
      width: popupState.width,
      height: popupState.height,
      context: popupState.context,
      createHeader: popupState.createHeader,
      columns: popupState.makeColumns(),
      rows: popupState.filterRows,
      configuration: popupState.configuration,
      onLoaded: popupState.onLoaded,
      onChanged: popupState.onChanged,
      onSelected: popupState.onSelected,
      mode: TrinaGridMode.popup,
    );
  }

  /// 'or' comparison with null values
  static bool compareOr(bool? a, bool b) {
    return a != true ? a == true || b : true;
  }

  /// 'and' comparison with null values
  static bool? compareAnd(bool? a, bool? b) {
    return a != false ? b : false;
  }

  /// Compare [base] and [search] with [TrinaFilterType.compare].
  static bool compareByFilterType({
    required TrinaFilterType filterType,
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String search,
    required TrinaColumn column,
  }) {
    bool compare = false;

    if (column.type is TrinaColumnTypeWithNumberFormat) {
      final TrinaColumnTypeWithNumberFormat numberColumn =
          column.type as TrinaColumnTypeWithNumberFormat;

      compare = compare ||
          filterType.compare(
            base: numberColumn.applyFormat(base),
            baseObject: baseObject,
            search: search,
            searchObject: searchObject,
            column: column,
          );

      search = search.replaceFirst(
        numberColumn.numberFormat.symbols.DECIMAL_SEP,
        '.',
      );
    }

    return compare ||
        filterType.compare(
          base: base,
          baseObject: baseObject,
          search: search,
          searchObject: searchObject,
          column: column,
        );
  }

  /// Whether [search] is contains in [base].
  static bool compareContains({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return _compareWithRegExp(RegExp.escape(search!), base!);
  }

  /// Whether [search] is equals to [base].
  static bool compareEquals({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return _compareWithRegExp(
      // ignore: prefer_interpolation_to_compose_strings
      r'^' + RegExp.escape(search!) + r'$',
      base!,
    );
  }

  /// Whether [base] starts with [search].
  static bool compareStartsWith({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return _compareWithRegExp(
      // ignore: prefer_interpolation_to_compose_strings
      r'^' + RegExp.escape(search!),
      base!,
    );
  }

  /// Whether [base] ends with [search].
  static bool compareEndsWith({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return _compareWithRegExp(
      // ignore: prefer_interpolation_to_compose_strings
      RegExp.escape(search!) + r'$',
      base!,
    );
  }

  static bool compareGreaterThan({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return column.type.compare(base, search) == 1;
  }

  static bool compareGreaterThanOrEqualTo({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return column.type.compare(base, search) > -1;
  }

  static bool compareLessThan({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return column.type.compare(base, search) == -1;
  }

  static bool compareLessThanOrEqualTo({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    return column.type.compare(base, search) < 1;
  }

  static bool _compareWithRegExp(
    String pattern,
    String value, {
    bool caseSensitive = false,
  }) {
    return RegExp(pattern, caseSensitive: caseSensitive).hasMatch(value);
  }

  /// Compare [base] with raw regex [search].
  static bool compareRegex({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    if (base == null || search == null || search.isEmpty) {
      return false;
    }

    try {
      return RegExp(search).hasMatch(base);
    } catch (e) {
      // Return false if the regex pattern is invalid
      return false;
    }
  }

  static bool compareMultiItems({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
    bool caseSensitive = true,
  }) {
    if (base == null || search == null) return false;
    final items = search
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (caseSensitive) {
      return items.contains(base.trim());
    } else {
      final baseLower = base.trim().toLowerCase();
      return items.any((item) => item.toLowerCase() == baseLower);
    }
  }
}

/// State for calling filter pop
class FilterPopupState {
  /// [BuildContext] for calling [showDialog]
  final BuildContext context;

  /// [TrinaGridConfiguration] to call [TrinaGridPopup]
  final TrinaGridConfiguration configuration;

  /// A callback function called when adding a new filter.
  final SetFilterPopupHandler handleAddNewFilter;

  /// A callback function called when filter information changes.
  final SetFilterPopupHandler handleApplyFilter;

  /// List of columns to be filtered.
  final List<TrinaColumn> columns;

  /// List with filtering condition information
  final List<TrinaRow> filterRows;

  /// The filter popup opens and focuses on the filter value in the first row.
  final bool focusFirstFilterValue;

  /// Width of filter popup
  final double width;

  /// Height of filter popup
  final double height;

  final void Function()? onClosed;

  FilterPopupState({
    required this.context,
    required this.configuration,
    required this.handleAddNewFilter,
    required this.handleApplyFilter,
    required this.columns,
    required this.filterRows,
    required this.focusFirstFilterValue,
    this.width = 600,
    this.height = 450,
    this.onClosed,
  })  : assert(columns.isNotEmpty),
        _previousFilterRows = <TrinaRow?>[...filterRows];

  TrinaGridStateManager? _stateManager;
  List<TrinaRow?> _previousFilterRows;

  void onLoaded(TrinaGridOnLoadedEvent e) {
    _stateManager = e.stateManager;

    _stateManager!.setSelectingMode(TrinaGridSelectingMode.row, notify: false);

    if (_stateManager!.rows.isNotEmpty) {
      _stateManager!.setKeepFocus(true, notify: false);

      _stateManager!.setCurrentCell(
        _stateManager!.rows.first.cells[FilterHelper.filterFieldValue],
        0,
        notify: false,
      );

      if (focusFirstFilterValue) {
        _stateManager!.setEditing(true, notify: false);
      }
    }

    _stateManager!.notifyListeners();

    _stateManager!.addListener(stateListener);
  }

  void onChanged(TrinaGridOnChangedEvent e) {
    applyFilter();
  }

  void onSelected(TrinaGridOnSelectedEvent e) {
    _stateManager!.removeListener(stateListener);

    if (onClosed != null) {
      onClosed!();
    }
  }

  void stateListener() {
    if (listEquals(_previousFilterRows, _stateManager!.rows) == false) {
      _previousFilterRows = <TrinaRow?>[..._stateManager!.rows];
      applyFilter();
    }
  }

  void applyFilter() {
    handleApplyFilter(_stateManager);
  }

  TrinaGridFilterPopupHeader createHeader(TrinaGridStateManager stateManager) {
    return TrinaGridFilterPopupHeader(
      stateManager: stateManager,
      configuration: configuration,
      handleAddNewFilter: handleAddNewFilter,
    );
  }

  List<TrinaColumn> makeColumns() {
    return _makeFilterColumns(configuration: configuration, columns: columns);
  }

  Map<String, String> _makeFilterColumnMap({
    required TrinaGridConfiguration configuration,
    required List<TrinaColumn> columns,
  }) {
    final Map<String, String> columnMap = <String, String>{
      FilterHelper.filterFieldAllColumns:
          configuration.localeText.filterAllColumns,
    };

    columns
        .where((TrinaColumn element) => element.enableFilterMenuItem)
        .forEach((TrinaColumn element) {
      columnMap[element.field] = element.titleWithGroup;
    });

    return columnMap;
  }

  List<TrinaColumn> _makeFilterColumns({
    required TrinaGridConfiguration configuration,
    required List<TrinaColumn> columns,
  }) {
    final Map<String, String> columnMap = _makeFilterColumnMap(
      configuration: configuration,
      columns: columns,
    );

    return <TrinaColumn>[
      TrinaColumn(
        title: configuration.localeText.filterColumn.toUpperCase(),
        field: FilterHelper.filterFieldColumn,
        type: TrinaColumnType.select(columnMap.keys.toList(growable: false)),
        enableFilterMenuItem: false,
        applyFormatterInEditing: true,
        formatter: (dynamic value) {
          return columnMap[value] ?? '';
        },
      ),
      TrinaColumn(
        title: configuration.localeText.filterType.toUpperCase(),
        field: FilterHelper.filterFieldType,
        type: TrinaColumnType.select(configuration.columnFilter.filters),
        enableFilterMenuItem: false,
        applyFormatterInEditing: true,
        formatter: (dynamic value) {
          return (value?.title ?? '').toString();
        },
      ),
      TrinaColumn(
        title: configuration.localeText.filterValue.toUpperCase(),
        field: FilterHelper.filterFieldValue,
        type: TrinaColumnType.text(),
        enableFilterMenuItem: false,
      ),
    ];
  }
}

class TrinaGridFilterPopupHeader extends StatelessWidget {
  final TrinaGridStateManager? stateManager;
  final TrinaGridConfiguration? configuration;
  final SetFilterPopupHandler? handleAddNewFilter;

  const TrinaGridFilterPopupHeader({
    super.key,
    this.stateManager,
    this.configuration,
    this.handleAddNewFilter,
  });

  void handleAddButton() {
    handleAddNewFilter!(stateManager);
  }

  void handleRemoveButton() {
    if (stateManager!.currentSelectingRows.isEmpty) {
      stateManager!.removeCurrentRow();
    } else {
      stateManager!.removeRows(stateManager!.currentSelectingRows);
    }
  }

  void handleClearButton() {
    if (stateManager!.rows.isEmpty) {
      Navigator.of(stateManager!.gridFocusNode.context!).pop();
    } else {
      stateManager!.removeRows(stateManager!.rows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: Icon(
                Icons.add,
                size: configuration!.style.iconSize,
                color: configuration?.style.addIconColor ??
                    theme.colorScheme.primary,
              ),
              tooltip: configuration?.localeText.addFilter,
              iconSize: configuration!.style.iconSize,
              onPressed: handleAddButton,
            ),
            SizedBox(
              width: configuration!.style.iconSize,
            ),
            IconButton(
              icon: Icon(
                Icons.remove,
                size: configuration!.style.iconSize,
                color: configuration!.style.removeIconColor ??
                    theme.colorScheme.error,
              ),
              tooltip: configuration?.localeText.deleteSelectedFilter,
              iconSize: configuration!.style.iconSize,
              onPressed: handleRemoveButton,
            ),
            SizedBox(
              width: configuration!.style.iconSize,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_forever,
                size: configuration!.style.iconSize,
                color: configuration!.style.removeIconColor ??
                    theme.colorScheme.error,
              ),
              color: configuration!.style.removeIconColor ??
                  theme.colorScheme.error,
              iconSize: configuration!.style.iconSize,
              onPressed: handleClearButton,
              tooltip: configuration!.localeText.resetFilter,
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          color: configuration!.style.iconColor,
          iconSize: configuration!.style.iconSize,
          tooltip: configuration!.localeText.close,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// [base] is the cell values of the column on which the search is based.
/// [search] is the value entered by the user to search.
typedef TrinaCompareFunction = bool Function({
  required dynamic baseObject,
  required String? base,
  required dynamic searchObject,
  required String? search,
  required TrinaColumn column,
});

abstract class TrinaFilterType {
  String get title => throw UnimplementedError();

  TrinaCompareFunction get compare => throw UnimplementedError();
}

class TrinaFilterTypeContains implements TrinaFilterType {
  static String name = 'Contains';

  @override
  String get title => TrinaFilterTypeContains.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareContains;

  const TrinaFilterTypeContains();
}

class TrinaFilterTypeContainsSet implements TrinaFilterType {
  static String name = 'Contains';

  @override
  String get title => TrinaFilterTypeContainsSet.name;

  @override
  TrinaCompareFunction get compare => compareContainsSet;

  const TrinaFilterTypeContainsSet();

  static bool compareContainsSet({
    required dynamic baseObject,
    required String? base,
    required dynamic searchObject,
    required String? search,
    required TrinaColumn column,
  }) {
    if (searchObject == null ||
        (searchObject is Set<String> && searchObject.isEmpty)) {
      return true;
    }
    if (searchObject != null &&
        searchObject is Set<String> &&
        baseObject != null &&
        baseObject is Set<String>) {
      return baseObject.any((String e) => searchObject.contains(e));
    }
    return true;
  }
}

class TrinaFilterTypeEquals implements TrinaFilterType {
  static String name = 'Equals';

  @override
  String get title => TrinaFilterTypeEquals.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareEquals;

  const TrinaFilterTypeEquals();
}

class TrinaFilterTypeStartsWith implements TrinaFilterType {
  static String name = 'Starts with';

  @override
  String get title => TrinaFilterTypeStartsWith.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareStartsWith;

  const TrinaFilterTypeStartsWith();
}

class TrinaFilterTypeEndsWith implements TrinaFilterType {
  static String name = 'Ends with';

  @override
  String get title => TrinaFilterTypeEndsWith.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareEndsWith;

  const TrinaFilterTypeEndsWith();
}

class TrinaFilterTypeGreaterThan implements TrinaFilterType {
  static String name = 'Greater than';

  @override
  String get title => TrinaFilterTypeGreaterThan.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareGreaterThan;

  const TrinaFilterTypeGreaterThan();
}

class TrinaFilterTypeGreaterThanOrEqualTo implements TrinaFilterType {
  static String name = 'Greater than or equal to';

  @override
  String get title => TrinaFilterTypeGreaterThanOrEqualTo.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareGreaterThanOrEqualTo;

  const TrinaFilterTypeGreaterThanOrEqualTo();
}

class TrinaFilterTypeLessThan implements TrinaFilterType {
  static String name = 'Less than';

  @override
  String get title => TrinaFilterTypeLessThan.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareLessThan;

  const TrinaFilterTypeLessThan();
}

class TrinaFilterTypeLessThanOrEqualTo implements TrinaFilterType {
  static String name = 'Less than or equal to';

  @override
  String get title => TrinaFilterTypeLessThanOrEqualTo.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareLessThanOrEqualTo;

  const TrinaFilterTypeLessThanOrEqualTo();
}

class TrinaFilterTypeRegex implements TrinaFilterType {
  static String name = 'Regex';

  @override
  String get title => TrinaFilterTypeRegex.name;

  @override
  TrinaCompareFunction get compare => FilterHelper.compareRegex;

  const TrinaFilterTypeRegex();
}

class TrinaFilterTypeMultiItems implements TrinaFilterType {
  static String name = 'MultiItems';

  final bool caseSensitive;

  const TrinaFilterTypeMultiItems({this.caseSensitive = true});

  @override
  String get title => TrinaFilterTypeMultiItems.name;

  @override
  TrinaCompareFunction get compare => ({
        required dynamic baseObject,
        required String? base,
        required dynamic searchObject,
        required String? search,
        required TrinaColumn column,
      }) =>
          FilterHelper.compareMultiItems(
            baseObject: baseObject,
            base: base,
            searchObject: searchObject,
            search: search,
            column: column,
            caseSensitive: caseSensitive,
          );
}
