import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class MediaUploadScreen extends StatefulWidget {
  const MediaUploadScreen({super.key});

  @override
  State<MediaUploadScreen> createState() => _MediaUploadScreenState();
}

class _MediaUploadScreenState extends State<MediaUploadScreen> {
  XFile? _pickedFile;
  String _mediaType = 'photo';
  String _title = '';
  String _description = '';
  int? _eventId;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
    if (file != null) {
      setState(() {
        _pickedFile = file;
        _mediaType = 'photo';
        _error = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (file != null) {
      setState(() {
        _pickedFile = file;
        _mediaType = 'video';
        _error = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1920, imageQuality: 85);
    if (file != null) {
      setState(() {
        _pickedFile = file;
        _mediaType = 'photo';
        _error = null;
      });
    }
  }

  /// Extract file extension from the XFile.
  /// On web, XFile.path is a blob URL, so we use XFile.name instead.
  String _fileExtension(XFile file) {
    // Prefer .name (works on both mobile and web)
    final name = file.name;
    if (name.contains('.')) {
      final ext = name.split('.').last.toLowerCase();
      if (ext.length <= 5 && !ext.contains('/')) return ext;
    }
    // Fallback based on MIME type from the file
    final mimeType = file.mimeType ?? '';
    if (mimeType.contains('jpeg') || mimeType.contains('jpg')) return 'jpg';
    if (mimeType.contains('png')) return 'png';
    if (mimeType.contains('gif')) return 'gif';
    if (mimeType.contains('webp')) return 'webp';
    if (mimeType.contains('mp4')) return 'mp4';
    if (mimeType.contains('quicktime') || mimeType.contains('mov')) return 'mov';
    // Ultimate fallback based on media type
    return _mediaType == 'photo' ? 'jpg' : _mediaType == 'video' ? 'mp4' : 'mp3';
  }

  String _mimeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) return;

    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final ext = _fileExtension(_pickedFile!);
      final mime = _mimeFromExt(ext);
      final fileBytes = await _pickedFile!.readAsBytes();
      final fileSize = fileBytes.length;
      final uploaded = await _uploadViaPresigned(fileBytes, fileSize, ext, mime);
      if (!uploaded) {
        debugPrint('Upload path: presigned failed, falling back to proxy /api/media/upload');
        final proxyUploaded = await _uploadViaProxy(fileBytes, ext, mime);
        if (!proxyUploaded) {
          setState(() {
            _error = 'Upload failed';
            _uploading = false;
          });
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploaded via fallback proxy path'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint('Upload path: presigned S3 + /api/media finalize');
      }

      setState(() => _progress = 1.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Memory shared successfully!'),
            backgroundColor: SanskarTheme.lotusGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _uploading = false;
      });
    }
  }

  Future<bool> _uploadViaPresigned(List<int> fileBytes, int fileSize, String ext, String mime) async {
    final token = await ApiService.getToken();
    if (token == null) return false;

    setState(() => _progress = 0.2);

    final presignResp = await http.post(
      Uri.parse(ApiConfig.mediaPresign),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'file_ext': ext,
        'content_type': mime,
        'prefix': _mediaType == 'video'
            ? 'videos'
            : _mediaType == 'audio'
                ? 'audio'
                : 'photos',
      }),
    );

    if (presignResp.statusCode != 200) return false;

    final presignBody = jsonDecode(presignResp.body) as Map<String, dynamic>;
    if (presignBody['success'] != true || presignBody['upload_url'] == null || presignBody['public_url'] == null) {
      debugPrint('Presign response invalid: ${presignResp.body}');
      return false;
    }

    final uploadUrl = presignBody['upload_url'] as String;
    final publicUrl = presignBody['public_url'] as String;

    setState(() => _progress = 0.5);

    final putResp = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': mime},
      body: fileBytes,
    );

    if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
      debugPrint('Presigned PUT failed: ${putResp.statusCode}');
      return false;
    }

    setState(() => _progress = 0.8);

    final createResp = await http.post(
      Uri.parse(ApiConfig.media),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'event_id': _eventId,
        'media_type': _mediaType,
        'title': _title.isEmpty ? null : _title,
        'description': _description.isEmpty ? null : _description,
        'file_url': publicUrl,
        'thumbnail_url': null,
        'file_size_bytes': fileSize,
        'duration_secs': 0,
        'mime_type': mime,
      }),
    );

    final ok = createResp.statusCode == 201;
    if (!ok) {
      debugPrint('Finalize /api/media failed: ${createResp.statusCode} ${createResp.body}');
    }
    return ok;
  }

  Future<bool> _uploadViaProxy(List<int> fileBytes, String ext, String mime) async {
    setState(() => _progress = 0.4);

    final uri = Uri.parse('${ApiConfig.apiUrl}/media/upload');
    final request = http.MultipartRequest('POST', uri);

    final token = await ApiService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: '${DateTime.now().millisecondsSinceEpoch}.$ext',
      contentType: _parseMediaType(mime),
    ));

    request.fields['media_type'] = _mediaType;
    if (_title.isNotEmpty) request.fields['title'] = _title;
    if (_description.isNotEmpty) request.fields['description'] = _description;
    if (_eventId != null) request.fields['event_id'] = _eventId.toString();

    setState(() => _progress = 0.7);
    final streamedResponse = await request.send();
    await streamedResponse.stream.bytesToString();
    return streamedResponse.statusCode == 201;
  }

  /// Parse a MIME type string into a MediaType for multipart upload.
  MediaType? _parseMediaType(String mime) {
    final parts = mime.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📷 Share Memory')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Picker area
            if (_pickedFile == null) ...[
              const Text(
                'Choose what to share',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _PickerButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: SanskarTheme.saffron,
                    onTap: _takePhoto,
                  ),
                  const SizedBox(width: 12),
                  _PickerButton(
                    icon: Icons.photo_library,
                    label: 'Photos',
                    color: SanskarTheme.deepSaffron,
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 12),
                  _PickerButton(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: SanskarTheme.turmeric,
                    onTap: _pickVideo,
                  ),
                ],
              ),
            ] else ...[
              // Preview
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: SanskarTheme.peach.withAlpha(40),
                  borderRadius: SanskarTheme.radiusMd,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _mediaType == 'photo' ? Icons.photo : Icons.videocam,
                            size: 48,
                            color: SanskarTheme.saffron,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pickedFile!.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: SanskarTheme.darkCharcoal.withAlpha(150),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: SanskarTheme.saffron.withAlpha(15),
                              borderRadius: SanskarTheme.radiusSm,
                            ),
                            child: Text(
                              _mediaType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SanskarTheme.saffron,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _pickedFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.close, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Title
              TextField(
                onChanged: (v) => _title = v,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                onChanged: (v) => _description = v,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 20),

              // Error
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: SanskarTheme.vermillion.withAlpha(15),
                    borderRadius: SanskarTheme.radiusSm,
                    border: Border.all(color: SanskarTheme.vermillion.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: SanskarTheme.vermillion),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 13, color: SanskarTheme.vermillion),
                        ),
                      ),
                    ],
                  ),
                ),

              // Progress
              if (_uploading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: SanskarTheme.peach.withAlpha(40),
                    valueColor: const AlwaysStoppedAnimation(SanskarTheme.saffron),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress < 0.3
                      ? 'Getting upload URL...'
                      : _progress < 0.7
                          ? 'Uploading file...'
                          : _progress < 1.0
                              ? 'Saving record...'
                              : 'Done!',
                  style: TextStyle(fontSize: 12, color: SanskarTheme.darkCharcoal.withAlpha(120)),
                ),
                const SizedBox(height: 16),
              ],

              // Upload button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_uploading ? 'Uploading...' : 'Share Memory 🙏'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SanskarTheme.saffron,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: SanskarTheme.radiusMd),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: color.withAlpha(12),
            borderRadius: SanskarTheme.radiusMd,
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
