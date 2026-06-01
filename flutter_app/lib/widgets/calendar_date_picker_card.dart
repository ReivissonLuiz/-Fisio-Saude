/// Calendário embutido com card — evita Container opaco sobre o Ink do dia selecionado.
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CalendarDatePickerCard extends StatelessWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;
  final SelectableDayPredicate? selectableDayPredicate;
  final double borderRadius;

  const CalendarDatePickerCard({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    this.selectableDayPredicate,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    // Material fornece superfície para o Ink do dia selecionado (evita bug do Container opaco).
    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: CalendarDatePicker(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        selectableDayPredicate: selectableDayPredicate,
        onDateChanged: onDateChanged,
      ),
    );
  }
}
