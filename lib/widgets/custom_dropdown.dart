import 'package:flutter/material.dart';

class CustomDropdownButton extends StatelessWidget {
  final double? width;
  final String hintText;
  final dynamic value;
  final List<DropdownMenuItem> items;
  final void Function(dynamic value) onSelected;
  final String? Function(dynamic value)? validator;

  const CustomDropdownButton({
    required this.items,
    required this.hintText,
    required this.onSelected,
    this.value,
    this.validator,
    this.width,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField(
      borderRadius: BorderRadius.circular(6),
      value: value,
      decoration: InputDecoration(
        label: Text(
          hintText,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            12,
          ),
        ),
      ),
      dropdownColor: Colors.white,
      validator: validator,
      selectedItemBuilder: (context) => items,
      items: items,
      onChanged: onSelected,
    );
  }
}
