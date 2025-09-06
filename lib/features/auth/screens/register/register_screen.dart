import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../cubit/auth_cubit.dart';
import '../../../../widgets/loading_ui.dart';
import 'register_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  trailing: const Icon(Icons.photo_library),
                  title: const Text('معرض الصور'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                if (_selectedImage != null)
                  ListTile(
                    trailing: const Icon(Icons.delete),
                    title: const Text('إزالة الصورة'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.red),
        ),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          final cubit = context.read<AuthCubit>();

          if (state is SendCodeSuccess) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RegisterOtpScreen(
                  cubit: cubit,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<AuthCubit>();

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              height: double.infinity,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
                ),
              ),
              alignment: Alignment.center,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        Center(
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'أدخل معلوماتك',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'أنشئ حسابك لتبدأ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey.shade200,
                                        border: Border.all(
                                          color: Colors.red.shade300,
                                          width: 2,
                                        ),
                                      ),
                                      child: _selectedImage != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              child: Image.file(
                                                _selectedImage!,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.grey.shade600,
                                                  size: 30,
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  'إضافة صورة',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextFormField(
                                    controller: cubit.nameController,
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      labelText: 'الاسم الكامل',
                                      hintText: 'مثال: أحمد العلي',
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.grey),
                                        onPressed: () =>
                                            cubit.nameController.clear(),
                                        tooltip: 'مسح الاسم',
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'الاسم الكامل مطلوب';
                                      }
                                      if (value.length < 2) {
                                        return 'يجب أن يتكون الاسم من حرفين على الأقل';
                                      }
                                      if (value.length > 50) {
                                        return 'يجب أن يكون الاسم أقل من ٥٠ حرفًا';
                                      }
                                      if (!RegExp(
                                              r"^[a-zA-Z\u0621-\u064A\u0660-\u0669\s\-'\.]+$")
                                          .hasMatch(value)) {
                                        return 'مسموح فقط بالأحرف والمسافات والشرطات';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: cubit.phoneController,
                                    keyboardType: TextInputType.phone,
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      suffixText: ' ٩٦٣+',
                                      suffixStyle:
                                          TextStyle(color: Colors.black),
                                      labelText: '٩٩٩٩٩٩٩٩٩ ٩٦٣+',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'هذا الحقل مطلوب';
                                      } else if (value.length != 9) {
                                        return 'الرجاء إدخال رقم هاتف صحيح بدون الصفر';
                                      } else {
                                        return null;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  state is SendCodeLoading
                                      ? const LoadingUi()
                                      : SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            autofocus: true,
                                            onPressed: () {
                                              final cubit =
                                                  context.read<AuthCubit>();
                                              if (formKey.currentState!
                                                  .validate()) {
                                                cubit.setProfileImage(
                                                    _selectedImage);
                                                cubit.sendOtp(
                                                    'phone_number_register');
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                            ),
                                            child:
                                                const Text('إرسال رمز التسجيل'),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
