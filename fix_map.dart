import 'dart:io';

void main() {
  final file = File('lib/widgets/map_location_modal.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
    'CircularProgressIndicator(color: context.ac.fg.withOpacity(0.54))', 
    'CircularProgressIndicator(color: ctx.ac.fg.withOpacity(0.54))'
  );
  
  content = content.replaceAll(
    '_mapFallbackWidget(lat, lng, height)', 
    '_mapFallbackWidget(ctx, lat, lng, height)'
  );
  
  content = content.replaceAll(
    '_mapFallbackWidget(String lat, String lng, double height)', 
    '_mapFallbackWidget(BuildContext context, String lat, String lng, double height)'
  );
  
  file.writeAsStringSync(content);
}
