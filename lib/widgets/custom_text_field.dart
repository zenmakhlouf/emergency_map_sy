import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  final int? maxLines;
  final bool enabled;
  final bool readOnly;
  final bool autoFocus;
  final bool isPassword;
  final bool shouldCloseWhenTapOutSide;
  final double? width;
  final double? horizontalPadding;
  final String? label;
  final String? hintText;
  final String? suffixText;
  final String? prefixText;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final TextAlign textAlign;
  final TextInputType? type;
  final TextDirection? textDirection;
  final TextInputAction action;
  final TextCapitalization textCapitalization;
  final TextEditingController controller;
  final List<TextInputFormatter> inputFormatters;
  final void Function()? onTap;
  final void Function()? onEditingCompleted;
  final void Function(String value)? onChanged;
  final void Function(String value)? onSubmitted;
  final String? Function(String? value)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    this.type,
    this.label,
    this.onTap,
    this.width,
    this.hintText,
    this.maxLines,
    this.validator,
    this.onChanged,
    this.prefixText,
    this.prefixIcon,
    this.suffixText,
    this.suffixIcon,
    this.onSubmitted,
    this.textDirection,
    this.enabled = true,
    this.readOnly = false,
    this.autoFocus = false,
    this.horizontalPadding,
    this.isPassword = false,
    this.onEditingCompleted,
    this.inputFormatters = const [],
    this.textAlign = TextAlign.start,
    this.action = TextInputAction.done,
    this.shouldCloseWhenTapOutSide = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onTap: widget.onTap,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      keyboardType: widget.type,
      textAlign: widget.textAlign,
      validator: widget.validator,
      autofocus: widget.autoFocus,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      controller: widget.controller,
      textInputAction: widget.action,
      canRequestFocus: !widget.readOnly,
      textDirection: widget.textDirection,
      inputFormatters: widget.inputFormatters,
      textAlignVertical: TextAlignVertical.center,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.isPassword ? !_isVisible : false,
      decoration: InputDecoration(
        errorMaxLines: 2,
        // contentPadding: EdgeInsets.symmetric(
        //   vertical: 0,
        //   horizontal:
        //       widget.horizontalPadding ?? Dimensions.defaultPadding(context),
        // ),
        labelText: widget.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        hintText: widget.hintText,
        hintStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(
                widget.prefixIcon,
              ),
        suffixText: widget.suffixText,
        prefixText: widget.prefixText,
        suffixIcon: widget.isPassword
            ? IconButton(
                autofocus: false,
                onPressed: () => setState(() => _isVisible = !_isVisible),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
              )
            : widget.suffixIcon,
      ),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingCompleted,
      onTapOutside:
          widget.shouldCloseWhenTapOutSide ? (_) => FocusScope.of(context).unfocus() : null,
    );
  }
}
