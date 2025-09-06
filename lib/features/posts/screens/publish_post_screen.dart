import 'package:emergency_map_sy/widgets/success_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../widgets/custom_dropdown.dart';
import '../../../widgets/custom_elevated_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/error_snack_bar.dart';
import '../../../widgets/loading_ui.dart';
import '../../../widgets/try_again_ui.dart';
import '../cubit/posts_cubit.dart';
import '../models/post.dart';
import '../widgets/post_images_picker.dart';

class PublishPostScreen extends StatelessWidget {
  final Post? post;

  const PublishPostScreen({super.key, this.post});

  @override
  Widget build(BuildContext context) {
    const spacing = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish your problem'),
      ),
      body: BlocProvider(
        create: (context) => PostsCubit()..initPostInfo(),
        child: BlocConsumer<PostsCubit, PostsState>(
          listener: (context, state) {
            final cubit = context.read<PostsCubit>();

            if (state is PostsSuccess && post != null) {
              cubit.nameController.text = post!.title;
              cubit.descriptionController.text = post!.description;
              cubit.selectedCity = cubit.cities.firstWhere(
                (element) => element.id == post!.city!.id,
              );
              cubit.selectedType = cubit.civilEmergencyTypes.firstWhere(
                (element) => element.id == post!.type!.id,
              );
              cubit.existingImages = post!.images;
            }

            if (state is PublishSuccess) {
              Navigator.pop(context);
              showSuccessSnackBar(
                message: 'Your report has been published successfully.',
                context: context,
              );
            }

            if (state is PublishError) {
              showErrorSnackBar(
                message: state.message,
                context: context,
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<PostsCubit>();

            if (state is PostsLoading) {
              return const LoadingUi();
            }

            if (state is PostsError) {
              return TryAgainUi(
                message: state.message,
                onRetry: () => cubit.initPostInfo(),
              );
            }

            return Form(
              key: cubit.formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  CustomDropdownButton(
                    value: cubit.selectedCity,
                    items: cubit.cities
                        .map(
                          (city) => DropdownMenuItem(
                            value: city,
                            child: Text(city.name),
                          ),
                        )
                        .toList(),
                    onSelected: (value) {
                      if (value != null) cubit.selectCity(value);
                    },
                    hintText: 'Select a city',
                  ),
                  spacing,
                  CustomDropdownButton(
                    value: cubit.selectedType,
                    items: cubit.civilEmergencyTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name),
                          ),
                        )
                        .toList(),
                    onSelected: (value) {
                      if (value != null) cubit.selectType(value);
                    },
                    hintText: 'Select a type',
                  ),
                  spacing,
                  CustomTextField(
                    label: 'name',
                    shouldCloseWhenTapOutSide: true,
                    controller: cubit.nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required.';
                      }
                      return null;
                    },
                  ),
                  spacing,
                  CustomTextField(
                    maxLines: 5,
                    label: 'description',
                    shouldCloseWhenTapOutSide: true,
                    controller: cubit.descriptionController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required.';
                      }
                      return null;
                    },
                  ),
                  spacing,
                  PostImagesPicker(cubit: cubit),
                  spacing,
                  spacing,
                  state is PublishLoading
                      ? const LoadingUi()
                      : CustomElevatedButton(
                          label: 'Save',
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            if (cubit.formKey.currentState!.validate() &&
                                cubit.selectedCity != null &&
                                cubit.selectedType != null) {
                              post == null ? cubit.publishPost() : cubit.edit(post!);
                            }
                          },
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
