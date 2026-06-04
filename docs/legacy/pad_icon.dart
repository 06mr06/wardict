import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Original image from artifacts
  ProcessResult pr = Process.runSync('cmd', ['/c', 'copy', 'C:\\Users\\emre.aktas\\.gemini\\antigravity\\brain\\49d8d635-c26f-49a4-aaac-54b5a9b63c60\\media__1773168583999.png', 'temp_icon.png']);
  
  final file = File('temp_icon.png');
  final originalBytes = file.readAsBytesSync();
  final originalImage = img.decodeImage(originalBytes);
  if (originalImage == null) {
    print('Failed to decode');
    return;
  }
  
  final width = originalImage.width;
  final height = originalImage.height;
  
  // Create a new empty image with transparent background (4 channels)
  final newImage = img.Image(width: width, height: height, numChannels: 4);
  img.fill(newImage, color: img.ColorRgba8(0, 0, 0, 0));
  
  // Resize original to 75%
  final newW = (width * 0.75).round();
  final newH = (height * 0.75).round();
  final resized = img.copyResize(originalImage, width: newW, height: newH, interpolation: img.Interpolation.linear);
  
  // Draw it in the center
  final dstX = (width - newW) ~/ 2;
  final dstY = (height - newH) ~/ 2;
  
  img.compositeImage(newImage, resized, dstX: dstX, dstY: dstY);
  
  // Save to assets/images/app_icon.png
  final outBytes = img.encodePng(newImage);
  File('assets/images/app_icon.png').writeAsBytesSync(outBytes);
  print('Done padding icon.');
}