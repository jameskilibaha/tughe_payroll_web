import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';

/// Building blocks for forms, so every form in the admin panel looks and behaves the same:
/// a titled section, a text field, a drop-down, a date field (calendar picker), a responsive grid
/// of fields, a notice banner and the Cancel / Save buttons.

/// A heading inside a form: icon, bold title and a thin rule.
class FormSection extends StatelessWidget {
  const FormSection(this.title, {super.key, this.icon, this.hint});

  final String title;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: Pal.primary), const SizedBox(width: 8)],
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Pal.brandText)),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: Pal.border, height: 1)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// A text field with the app's look: floating label (a `*` when required), optional icon, hint,
/// helper text and error text. Pass [errorText] to mark the field as wrong.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.icon,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.obscure = false,
    this.suffix,
    this.prefixText,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.errorText,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final Widget? suffix;
  final String? prefixText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final String? errorText;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: enabled ? Pal.text : Pal.textMuted),
      decoration: InputDecoration(
        labelText: required ? '${tr(label)} *' : tr(label),
        hintText: hint == null ? null : tr(hint!),
        helperText: helper == null ? null : tr(helper!),
        errorText: errorText == null ? null : tr(errorText!),
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        prefixText: prefixText,
        suffixIcon: suffix,
      ),
    );
  }
}

/// A drop-down with the same look as [AppTextField].
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
    this.required = false,
    this.errorText,
    this.labelOf,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final IconData? icon;
  final bool required;
  final String? errorText;

  /// How an item is shown (defaults to its `toString()`).
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(10),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Pal.textSecondary),
      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Pal.text),
      decoration: InputDecoration(
        labelText: required ? '${tr(label)} *' : tr(label),
        errorText: errorText == null ? null : tr(errorText!),
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(value: item, child: Text(labelOf == null ? '$item' : labelOf!(item), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}

/// A date field: tapping it opens a calendar; the value is written as `YYYY-MM-DD` (what the
/// server expects), so it can never be mistyped.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.onPicked,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final VoidCallback? onPicked;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.text.trim());
    final first = firstDate ?? DateTime(1940);
    final last = lastDate ?? DateTime(now.year + 5, 12, 31);
    var initial = current ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked == null) return;
    controller.text = picked.toIso8601String().substring(0, 10);
    onPicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pick(context),
      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Pal.text),
      decoration: InputDecoration(
        labelText: required ? '${tr(label)} *' : tr(label),
        errorText: errorText == null ? null : tr(errorText!),
        prefixIcon: const Icon(Icons.calendar_month_outlined, size: 18),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

/// Lays fields out in [columns] columns, falling back to one column on a narrow dialog.
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.children, this.columns = 2, this.spacing = 14});

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 420 ? 1 : (c.maxWidth < 560 && columns > 2 ? 2 : columns);
      final width = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final w in children) SizedBox(width: width, child: w)],
      );
    });
  }
}

enum NoticeKind { error, info, success }

/// A message box inside a form (a failed save, a hint, a success).
class FormNotice extends StatelessWidget {
  const FormNotice(this.message, {super.key, this.kind = NoticeKind.error});

  final String message;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      NoticeKind.error => Colors.red,
      NoticeKind.success => Colors.green,
      NoticeKind.info => Colors.blue,
    };
    final icon = switch (kind) {
      NoticeKind.error => Icons.error_outline,
      NoticeKind.success => Icons.check_circle_outline,
      NoticeKind.info => Icons.info_outline,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Pal.fg(color.shade700)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, height: 1.35, color: Pal.text))),
        ],
      ),
    );
  }
}

/// The Cancel and Save buttons at the foot of a form, with a spinner while saving.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.onSubmit,
    required this.submitLabel,
    this.onCancel,
    this.cancelLabel = 'Ghairi',
    this.busy = false,
    this.danger = false,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 18),
  });

  final VoidCallback? onSubmit;
  final String submitLabel;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final bool busy;

  /// A destructive action (deleting, clearing): the main button is red.
  final bool danger;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Pal.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: busy ? null : onCancel, child: Text(cancelLabel)),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: busy ? null : onSubmit,
            style: danger ? ElevatedButton.styleFrom(backgroundColor: Pal.danger, foregroundColor: Colors.white) : null,
            child: busy
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Pal.onPrimary))
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }
}
