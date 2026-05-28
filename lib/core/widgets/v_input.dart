import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// Themed text input. Wraps Material's TextFormField with project decoration
/// + obscure-toggle for password fields.
class VInput extends StatefulWidget {
  const VInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<VInput> createState() => _VInputState();
}

class _VInputState extends State<VInput> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        errorText: widget.errorText,
        prefixIcon: widget.prefix,
        suffixIcon: _buildSuffix(hasError),
        counterText: '',
        constraints: const BoxConstraints(minHeight: 52),
      ),
    );
  }

  Widget? _buildSuffix(bool hasError) {
    if (widget.obscure) {
      return IconButton(
        icon: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
        tooltip: _obscured ? 'Show' : 'Hide',
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }
    if (hasError) {
      return const Icon(LucideIcons.circleAlert, size: 20, color: AppColors.error);
    }
    return widget.suffix;
  }
}
