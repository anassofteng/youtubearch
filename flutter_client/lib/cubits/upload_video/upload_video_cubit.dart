import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_client/services/uploadvideo_service.dart';

import 'package:path/path.dart' show dirname;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
part 'upload_video_state.dart';

class UploadVideoCubit extends Cubit<UploadVideoState> {
  UploadVideoCubit() : super(UploadVideoInitial());
  final uploadVideoService = UploadvideoService();

  Future<void> uploadVideo({
    required File videoFile,
    required File thumbnailFile,
    required String title,
    required String description,
    required String visibility,
  }) async {
    emit(UploadVideoLoading());
    try {
      final videoData = await uploadVideoService.getPresignedUrlForVideo();
      final thumbnailData = await uploadVideoService
          .getPresignedUrlForThumbnail(videoData['video_id']);

      final appDir = await getApplicationDocumentsDirectory();
      if (!appDir.existsSync()) {
        appDir.createSync(recursive: true);
      }

      final newThumbnailPath =
          "${appDir.path}/${thumbnailData['thumbnail_id']}";
      final newVideoPath = "${appDir.path}/${videoData['video_id']}";

      final thumbnailDir = Directory(dirname(newThumbnailPath));
      final videoDir = Directory(dirname(newVideoPath));

      if (!thumbnailDir.existsSync()) {
        thumbnailDir.createSync(recursive: true);
      }

      if (!videoDir.existsSync()) {
        videoDir.createSync(recursive: true);
      }

      File newThumbnailFile = await thumbnailFile.copy(newThumbnailPath);
      File newVideoFile = await videoFile.copy(newVideoPath);

      final isThumbnailUploaded = await uploadVideoService.uploadFileToS3(
        presignedUrl: thumbnailData['url'],
        file: newThumbnailFile,
        isVideo: false,
      );

      final isVideoUploaded = await uploadVideoService.uploadFileToS3(
        presignedUrl: videoData['url'],
        file: newVideoFile,
        isVideo: true,
      );

      if (isThumbnailUploaded && isVideoUploaded) {
        final isMetadataUploaded = await uploadVideoService.uploadMetadata(
          title: title,
          description: description,
          visibility: visibility,
          s3_key: videoData['video_id'],
        );

        if (isMetadataUploaded) {
          emit(UploadVideoSuccess("Video uploaded successfully!"));
        } else {
          emit(UploadVideoError('Metadata not uploaded to backend!'));
        }
      } else {
        emit(UploadVideoError('Files not uploaded to S3!'));
      }

      try {
        if (newThumbnailFile.existsSync()) {
          await newThumbnailFile.delete();
        }
        if (newVideoFile.existsSync()) {
          await newVideoFile.delete();
        }
      } catch (e) {
        debugPrint('Error cleaning up temp files: $e');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      emit(UploadVideoError(e.toString()));
    }
  }
}