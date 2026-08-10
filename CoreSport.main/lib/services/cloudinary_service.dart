import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = 'li2zstvc';
  static const String uploadPreset = 'app_kevin';

  Future<String> uploadImage(XFile imageFile, String imageName) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final bytes = await imageFile.readAsBytes();

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = imageName
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
      ));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Error subiendo imagen: $resBody');
    }

    final data = jsonDecode(resBody);
    return data['secure_url'] as String;
  }
}