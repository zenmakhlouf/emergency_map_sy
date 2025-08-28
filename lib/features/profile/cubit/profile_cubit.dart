import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import '../../../../apis/network.dart';
import '../../../../utils/urls.dart';
import '../models/user_profile.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit() : super(ProfileInitial());

  Future<void> fetchProfile() async {
    emit(ProfileLoading());
    try {
      final response = await Network.getData(url: Urls.profile);
      final data = response.data['data'];
      final userProfile = UserProfile.fromJson(data);
      emit(ProfileLoaded(userProfile));
    } on DioException catch (e) {
      emit(ProfileError(e.message ?? 'Failed to load profile.'));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
