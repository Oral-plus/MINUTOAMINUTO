import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/constants.dart';

class MapLocationModal extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? contactName;

  const MapLocationModal({
    super.key,
    required this.latitude,
    required this.longitude,
    this.contactName,
  });

  static Future<void> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? contactName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapLocationModal(
        latitude: latitude,
        longitude: longitude,
        contactName: contactName,
      ),
    );
  }

  /// Mini mapa estático siempre visible para las grillas/listas (usa OpenStreetMap para evitar la clave revocada).
  static Widget miniMap({
    required double latitude,
    required double longitude,
    double width = 400,
    double height = 160,
  }) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    final w = width.toInt().clamp(100, 640);
    final h = height.toInt().clamp(80, 640);

    final url = 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng&zoom=15&size=${w}x$h'
        '&markers=$lat,$lng,ol-marker';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            color: const Color(0xFF1A2A3A),
            child: const Center(child: CircularProgressIndicator(color: Colors.white54)),
          );
        },
        errorBuilder: (ctx, err, _) => _mapFallbackWidget(lat, lng, height),
      ),
    );
  }

  static Widget _mapFallbackWidget(String lat, String lng, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFF4ADE80), size: 24),
            const SizedBox(height: 4),
            Text('$lat, $lng', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

// _staticMapsKey y fallback removidos a favor del widget real de GoogleMap.

  @override
  State<MapLocationModal> createState() => _MapLocationModalState();
}

class _MapLocationModalState extends State<MapLocationModal> {
  static const String _mapsApiKey = 'AIzaSyAkQv8RTOs510d2ag3Kkk0eIYjLj2DbfPQ';

  String _address = 'Obteniendo dirección...';
  bool _loadingAddress = true;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    if (_mapsApiKey.isEmpty) {
      setState(() {
        _address =
            '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}';
        _loadingAddress = false;
      });
      return;
    }

    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${widget.latitude},${widget.longitude}'
          '&key=$_mapsApiKey'
          '&language=es';

      final r = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final formatted = results[0]['formatted_address'] as String?;
          if (formatted != null && formatted.isNotEmpty) {
            if (mounted) {
              setState(() {
                _address = formatted;
                _loadingAddress = false;
              });
            }
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _address =
            '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}';
        _loadingAddress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppConstants.azulCorporativo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppConstants.azulCorporativo,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contactName != null
                            ? 'Ubicación de llamada'
                            : 'Ubicación',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (widget.contactName != null)
                        Text(
                          widget.contactName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(0),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(widget.latitude, widget.longitude),
                  initialZoom: 16.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.minutoaminuto.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(widget.latitude, widget.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: const Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _loadingAddress
                      ? const Text(
                          'Obteniendo dirección...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          _address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
