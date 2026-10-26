import 'package:flutter/material.dart';

/// The date itself determines the color, independently of filtering or sorting.
Color campaignDateColor(String date,
    {required bool dark, bool accent = false}) {
  final normalized = date.trim();
  final parsed = DateTime.tryParse(normalized);
  final seed = parsed == null
      ? normalized.codeUnits
          .fold<int>(0, (hash, c) => (hash * 31 + c) & 0x7fffffff)
      : DateTime.utc(parsed.year, parsed.month, parsed.day)
          .difference(DateTime.utc(2020))
          .inDays;
  final hue = (seed * 137.508) % 360;
  return HSVColor.fromAHSV(
          1,
          hue,
          accent ? (dark ? .45 : .8) : (dark ? .32 : .10),
          accent ? (dark ? .95 : .48) : (dark ? .22 : 1))
      .toColor();
}

TableBorder campaignSheetBorder(bool dark) => TableBorder.all(
      color: dark ? const Color(0xFF3B4B52) : const Color(0xFFD6E0DB),
      width: .6,
    );

/// Stable identity colors remain the same across dates, sorting and restarts.
class CampaignIdentityBadge extends StatelessWidget {
  const CampaignIdentityBadge(this.value,
      {super.key, this.accountCode = false});

  final String value;
  final bool accountCode;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = value.trim();
    if (label.isEmpty) return const Text('—');
    final normalized = accountCode ? label.toUpperCase() : label;
    final seed = normalized.codeUnits.fold<int>(
        accountCode ? 17 : 43, (hash, c) => (hash * 31 + c) & 0x7fffffff);
    final hue = (seed * 137.508) % 360;
    final foreground =
        HSLColor.fromAHSL(1, hue, .65, dark ? .80 : .28).toColor();
    final background =
        HSLColor.fromAHSL(1, hue, .52, dark ? .20 : .93).toColor();
    final border = HSLColor.fromAHSL(1, hue, .45, dark ? .40 : .72).toColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: .7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: foreground, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(normalized,
            style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: accountCode ? 'Consolas' : null)),
      ]),
    );
  }
}
