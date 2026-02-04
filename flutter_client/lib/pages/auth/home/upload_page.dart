import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_client/cubits/upload_video/upload_video_cubit.dart';
import 'package:flutter_client/utils.dart';

class UploadPage extends StatefulWidget {
  static route() => MaterialPageRoute(builder: (context) => const UploadPage());

  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String visibility = "PRIVATE";
  File? imageFile;
  File? videoFile;
  void selectImage() async {
    final _imageFile = await pickImage();

    setState(() {
      imageFile = _imageFile;
    });
  }

  void selectVideo() async {
    final _videoFile = await pickVideo();

    setState(() {
      videoFile = _videoFile;
    });
  }

  void uploadVideo() async {
    if (titleController.text.isNotEmpty &&
        descriptionController.text.isNotEmpty &&
        imageFile != null &&
        videoFile != null) {
      context.read<UploadVideoCubit>().uploadVideo(
        videoFile: videoFile!,
        thumbnailFile: imageFile!,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        visibility: visibility,
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Page')),
      body: BlocConsumer<UploadVideoCubit, UploadVideoState>(
        listener: (context, state) {
          // TODO: implement listener
           if (state is UploadVideoSuccess) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
              Navigator.pop(
                context
               
              );
            } else if (state is UploadVideoError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
        },
        builder: (context, state) {
          if(state is UploadVideoLoading){
            return Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: selectImage,
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: imageFile != null
                          ? Image.file(imageFile!, fit: BoxFit.cover)
                          : DottedBorder(
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload,
                                      size: 40,
                                      color: Colors.grey[400],
                                    ),
                                    Text(
                                      'upload thumbnail',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: selectVideo,
                    child: videoFile != null
                        ? Text('Video is selected')
                        : DottedBorder(
                            child: SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.video_file_outlined,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  Text(
                                    'upload Video',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 30),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(hintText: 'Title'),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    maxLines: null,
                    controller: descriptionController,
                    decoration: InputDecoration(hintText: 'Description'),
                  ),

                  DropdownButton<String>(
                    hint: Text(visibility),
                    items: <String>['PUBLIC', 'PRIVATE', 'UNLISTED'].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        visibility = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(onPressed: uploadVideo, child: Text('Upload')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
