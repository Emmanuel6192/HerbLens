import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessor {
  /// Read image file as bytes
  static Future<Uint8List> loadImageBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }

  /// Crop image to center square (improves model accuracy)
  static Uint8List centerCropSquare(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;

    final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);
    return Uint8List.fromList(img.encodeJpg(cropped));
  }

  /// Validate image is usable
  static bool isValidImage(String path) {
    final ext = path.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp', 'bmp'].contains(ext);
  }
}
