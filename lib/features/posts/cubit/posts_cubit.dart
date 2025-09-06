import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emergency_map_sy/features/posts/models/civil_emergency_types.dart';
import 'package:emergency_map_sy/utils/urls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../../apis/network.dart';
import '../models/city.dart';
import '../models/media.dart';
import '../models/post.dart';

part 'posts_state.dart';

class PostsCubit extends Cubit<PostsState> {
  PostsCubit() : super(PostsInitial());

  List<Post> posts = [];

  final List<File> selectedImages = [];
  final List<int> deletedImageIds = [];
  List<Media> existingImages = [];

  List<City> cities = [];
  List<CivilEmergencyTypes> civilEmergencyTypes = [];

  City? selectedCity;
  CivilEmergencyTypes? selectedType;
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  Future<void> addImages(List<File> images) async {
    selectedImages.addAll(images);
    emit(ImagePicked());
  }

  void removeImage(int index) {
    selectedImages.removeAt(index);
    emit(ImagePicked());
  }

  void removeExistingImage(Media image) {
    existingImages.removeWhere((e) => e.id == image.id);
    deletedImageIds.add(image.id);
    emit(ImagePicked());
  }

  void selectCity(City city) {
    selectedCity = city;
    emit(ChangedSelection());
  }

  void selectType(CivilEmergencyTypes type) {
    selectedType = type;
    emit(ChangedSelection());
  }

  Future<void> getPosts({Map<String, dynamic>? query}) async {
    emit(PostsLoading());
    try {
      final response = await Network.getData(
        url: Urls.civilEmergencies,
        queryParams: query,
      );

      posts = List<Post>.from(
        response.data['data']['civil_emergencies']['data'].map(
          (e) => Post.fromJson(e),
        ),
      );

      emit(PostsSuccess());
    } catch (e) {
      emit(PostsError(message: e.toString()));
    }
  }

  Future<void> initPostInfo() async {
    emit(PostsLoading());
    try {
      await Future.wait(
        [getCities(), getCivilEmergencyTypes()],
      );
      emit(PostsSuccess());
    } catch (e) {
      emit(PostsError(message: e.toString()));
    }
  }

  Future<void> getCities() async {
    final response = await Network.getData(url: Urls.cities);

    cities = List<City>.from(
      response.data['data']['cities'].map(
        (e) => City.fromJson(e),
      ),
    );
  }

  Future<void> getCivilEmergencyTypes() async {
    final response = await Network.getData(url: Urls.civilEmergencyTypes);

    civilEmergencyTypes = List<CivilEmergencyTypes>.from(
      response.data['data']['civil_emergency_types'].map(
        (e) => CivilEmergencyTypes.fromJson(e),
      ),
    );
  }

  Future<void> publishPost() async {
    emit(PublishLoading());
    try {
      final body = FormData.fromMap(
        {
          'title': nameController.text,
          'description': descriptionController.text,
          'city_id': selectedCity!.id,
          'civil_emergency_type_id': selectedType!.id,
        },
      );
      for (int i = 0; i < selectedImages.length; i++) {
        final file = await MultipartFile.fromFile(selectedImages[i].path);
        body.files.add(MapEntry('images[$i]', file));
      }

      await Network.postData(url: Urls.civilEmergencies, body: body);

      emit(PublishSuccess());
    } catch (e) {
      emit(PublishError(message: e.toString()));
    }
  }

  Future<void> edit(Post post) async {
    emit(PublishLoading());
    try {
      final body = FormData.fromMap(
        {
          if (post.title != nameController.text) 'title': nameController.text,
          if (post.description != descriptionController.text)
            'description': descriptionController.text,
          if (post.city!.id != selectedCity!.id) 'city_id': selectedCity!.id,
          if (post.type!.id != selectedType!.id) 'civil_emergency_type_id': selectedType!.id,
        },
      );
      for (int i = 0; i < selectedImages.length; i++) {
        final file = await MultipartFile.fromFile(selectedImages[i].path);
        body.files.add(MapEntry('images[$i]', file));
      }

      for (int i = 0; i < deletedImageIds.length; i++) {
        body.fields.add(MapEntry('trash_images[$i]', deletedImageIds[i].toString()));
      }

      await Network.postData(url: '${Urls.civilEmergencies}/${post.id}?_method=PUT', body: body);

      emit(PublishSuccess());
    } catch (e) {
      emit(PublishError(message: e.toString()));
    }
  }
}
