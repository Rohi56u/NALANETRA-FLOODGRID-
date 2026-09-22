import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'store.dart';

// ---------------------------------------------------------------------------
// High-Fidelity Shared UI Components — NalaNetra FloodGrid
// Matching mockup styling (gradients, custom shadows, specific typography)
// ---------------------------------------------------------------------------

class GovHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  const GovHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.showBack = false,
    this.onBack,
    this.bottom,
  });

  @override
  // Include the mobile safe-area inset, content row, bottom padding, and the
  // optional tab strip. Keep a small layout reserve for AppBar constraints on
  // narrow phones while using a compact visible gap in the widget tree.
  Size get preferredSize => Size.fromHeight(
    100 + (bottom?.preferredSize.height ?? 0) + (bottom == null ? 0 : 12),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        12 + MediaQuery.paddingOf(context).top,
        16,
        16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GovColors.navy, GovColors.navyDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onBack ?? () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (showBack) const SizedBox(width: 8),
              Hero(
                tag: 'app_logo',
                child: Image.asset(
                  'assets/logo.png',
                  height: 48,
                  width: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.shield, color: GovColors.navy, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 8), bottom!],
        ],
      ),
    );
  }
}

class GovNavDestination {
  final IconData icon;
  final String label;
  GovNavDestination({required this.icon, required this.label});
}

class GovBottomNav extends StatelessWidget {
  final int index;
  final Function(int) onTap;
  final List<GovNavDestination> destinations;

  const GovBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = store.themeMode == AppThemeMode.dark;
    return Material(
      elevation: 16,
      color: isDark ? GovColors.cardDark : Colors.white,
      child: SafeArea(
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (i) {
              final d = destinations[i];
              final active = index == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        d.icon,
                        color: active
                            ? (isDark ? GovColors.gold : GovColors.navy)
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w900
                              : FontWeight.w500,
                          color: active
                              ? (isDark ? GovColors.gold : GovColors.navy)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class GovButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;
  final IconData? icon;

  const GovButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            color ?? GovColors.navy,
            (color ?? GovColors.navy).withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (color ?? GovColors.navy).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SixDigitOtpField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool dark;
  final bool active;
  final bool enabled;

  const SixDigitOtpField({
    super.key,
    required this.controller,
    required this.label,
    required this.dark,
    this.active = false,
    this.enabled = true,
  });

  @override
  State<SixDigitOtpField> createState() => _SixDigitOtpFieldState();
}

class _SixDigitOtpFieldState extends State<SixDigitOtpField> {
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    widget.controller.addListener(_syncFromParent);
    _syncFromParent();
  }

  @override
  void didUpdateWidget(covariant SixDigitOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromParent);
      widget.controller.addListener(_syncFromParent);
      _syncFromParent();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final controller in _digitControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncFromParent() {
    if (_syncing) return;
    final raw = widget.controller.text.replaceAll(RegExp(r'\D'), '');
    final digits = raw.length > 6 ? raw.substring(0, 6) : raw;
    _syncing = true;
    for (var i = 0; i < 6; i++) {
      final next = i < digits.length ? digits[i] : '';
      if (_digitControllers[i].text != next) {
        _digitControllers[i].value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
    _syncing = false;
  }

  void _updateParent() {
    final value = _digitControllers.map((controller) => controller.text).join();
    if (widget.controller.text == value) return;
    _syncing = true;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncing = false;
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6; i++) {
        _digitControllers[i].text = i < digits.length ? digits[i] : '';
      }
    }
    _updateParent();
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.dark ? Colors.white : GovColors.navy;
    return Semantics(
      label: widget.label,
      textField: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: widget.dark ? GovColors.cardDark : const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.active
                ? GovColors.gold
                : GovColors.navy.withValues(alpha: .28),
            width: widget.active ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 21,
                  color: GovColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.active
                          ? GovColors.gold
                          : ink.withValues(alpha: .78),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(6, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 7),
                    child: TextField(
                      controller: _digitControllers[index],
                      focusNode: _focusNodes[index],
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textInputAction: index == 5
                          ? TextInputAction.done
                          : TextInputAction.next,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) => _onChanged(index, value),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: widget.dark ? Colors.white10 : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(
                            color: widget.active
                                ? GovColors.gold.withValues(alpha: .75)
                                : GovColors.navy.withValues(alpha: .22),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: BorderSide(
                            color: widget.active
                                ? GovColors.gold.withValues(alpha: .75)
                                : GovColors.navy.withValues(alpha: .22),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: GovColors.gold,
                            width: 2,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class GovStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const GovStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : GovColors.navy,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GovReportCard extends StatelessWidget {
  final String id;
  final String location;
  final IncidentLifecycle status;
  final String time;
  final VoidCallback onTap;
  final bool isDark;

  const GovReportCard({
    super.key,
    required this.id,
    required this.location,
    required this.status,
    required this.time,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GovColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 48,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        id,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : GovColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.labelEn,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: status.color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
