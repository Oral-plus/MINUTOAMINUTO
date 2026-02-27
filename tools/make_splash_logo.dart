import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = File('assets/images/logo.png');
  final original = img.decodePng(src.readAsBytesSync())!;

  final w = original.width;
  final h = original.height;

  // Recortar el área central donde está el logo (sin el fondo gris de las esquinas)
  // El logo ocupa aproximadamente el 70% central de la imagen
  final padX = (w * 0.08).round();
  final padY = (h * 0.28).round();
  final cropW = w - padX * 2;
  final cropH = h - padY * 2;

  final cropped = img.copyCrop(
    original,
    x: padX,
    y: padY,
    width: cropW,
    height: cropH,
  );

  // Crear imagen cuadrada con fondo blanco puro y el logo centrado
  final size = (w * 0.84).round(); // tamaño final
  final result = img.Image(width: size, height: size);
  img.fill(result, color: img.ColorRgba8(255, 255, 255, 255));

  // Escalar el recorte para que quepa
  final scaled = img.copyResize(cropped, width: size, height: (size * cropH / cropW).round());
  final offsetY = ((size - scaled.height) / 2).round();

  img.compositeImage(result, scaled, dstY: offsetY);

  final out = File('assets/images/logo_splash.png');
  out.writeAsBytesSync(img.encodePng(result));
  print('Guardado: ${out.path} (${size}x${size})');
}
