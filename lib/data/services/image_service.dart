import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart'
    as cached_img;

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

class ImageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickFromGallery() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return img != null ? File(img.path) : null;
    } catch (e) {
      debugPrint('ImageService.pickFromGallery error: $e');
      return null;
    }
  }

  Future<File?> pickFromCamera() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return img != null ? File(img.path) : null;
    } catch (e) {
      debugPrint('ImageService.pickFromCamera error: $e');
      return null;
    }
  }

  Future<String?> uploadToSupabase(
    File file,
    String bucket,
    String fileName,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final path = 'uploads/$fileName';
      await _supabase.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('ImageService.uploadToSupabase error: $e');
      return null;
    }
  }

  Future<bool> deleteFromSupabase(String bucket, String fileName) async {
    try {
      await _supabase.storage.from(bucket).remove(['uploads/$fileName']);
      return true;
    } catch (e) {
      debugPrint('ImageService.deleteFromSupabase error: $e');
      return false;
    }
  }
}

// ── Cached Network Image Widget ───────────────────────────────────────────────

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return cached_img.CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.white.withValues(alpha: 0.1),
            child: const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Colors.white.withValues(alpha: 0.08),
            child: const Icon(Icons.broken_image_outlined,
                color: Colors.white38),
          ),
    );
  }
}

// ── Image Picker Dialog ───────────────────────────────────────────────────────

class ImagePickerDialog extends ConsumerWidget {
  const ImagePickerDialog({super.key, required this.onSelected});
  final void Function(File?) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(imageServiceProvider);
    return AlertDialog(
      title: const Text('Select Image'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () async {
              Navigator.pop(context);
              onSelected(await service.pickFromCamera());
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              onSelected(await service.pickFromGallery());
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onSelected(null);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
