import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class HaritaEkrani extends StatefulWidget {
  final List<Map<String, dynamic>> rotamListesi;
  final Function(Map<String, dynamic>) rotayaEkleCikar;
  final bool isOptimized;
  final Function(bool) onToggleOptimize;

  const HaritaEkrani({
    super.key,
    required this.rotamListesi,
    required this.rotayaEkleCikar,
    required this.isOptimized,
    required this.onToggleOptimize,
  });
  @override
  State<HaritaEkrani> createState() => _HaritaEkraniState();
}

class _HaritaEkraniState extends State<HaritaEkrani> {
  List<Map<String, dynamic>> _tumMekanlar = [];
  List<List<LatLng>> _routeSegments = [];
  bool _loading = true;

  bool _sadeceRotamiGoster = false;
  final List<int> _seciliKategoriler = [];

  final List<Color> _segmentColors = [
    const Color(0xFF2196F3),
    const Color(0xFF9C27B0),
    const Color(0xFFFF9800),
    const Color(0xFF00BCD4),
    const Color(0xFFE91E63),
    const Color(0xFF4CAF50),
    const Color(0xFFF44336),
  ];

  @override
  void initState() {
    super.initState();
    _fetchMekanlar();
    _fetchGercelRota();
  }

  @override
  void didUpdateWidget(covariant HaritaEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotamListesi != widget.rotamListesi ||
        oldWidget.isOptimized != widget.isOptimized) {
      _fetchGercelRota();
    }
  }

  List<LatLng> _calculateSmoothOffset(
    List<LatLng> points,
    double offsetMeters,
  ) {
    if (points.length < 2) return points;
    List<LatLng> result = [];
    const Distance dist = Distance();

    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        double b = dist.bearing(points[0], points[1]);
        result.add(dist.offset(points[0], offsetMeters, (b + 90) % 360));
      } else if (i == points.length - 1) {
        double b = dist.bearing(points[i - 1], points[i]);
        result.add(dist.offset(points[i], offsetMeters, (b + 90) % 360));
      } else {
        double b1 = (dist.bearing(points[i - 1], points[i]) + 360) % 360;
        double b2 = (dist.bearing(points[i], points[i + 1]) + 360) % 360;

        double angleDiff = (b2 - b1);
        if (angleDiff < -180) angleDiff += 360;
        if (angleDiff > 180) angleDiff -= 360;

        if (angleDiff.abs() > 90) {
          result.add(dist.offset(points[i], offsetMeters, (b1 + 90) % 360));
          result.add(dist.offset(points[i], offsetMeters, (b2 + 90) % 360));
          continue;
        }

        double bisector = (b1 + angleDiff / 2 + 90) % 360;
        double miterMult = 1 / math.cos((angleDiff / 2) * math.pi / 180);

        if (miterMult.abs() > 2.0) miterMult = 2.0 * miterMult.sign;

        result.add(
          dist.offset(points[i], offsetMeters * miterMult.abs(), bisector),
        );
      }
    }
    return result;
  }

  Future<void> _fetchGercelRota() async {
    if (widget.rotamListesi.length < 2) {
      setState(() {
        _routeSegments = [];
      });
      return;
    }

    final String coordinatesString = widget.rotamListesi
        .map((m) => "${m['boylam']},${m['enlem']}")
        .join(";");
    String unrestrictedStr = List.filled(
      widget.rotamListesi.length,
      "unrestricted",
    ).join(";");

    String mode = widget.isOptimized ? "trip" : "route";
    String params = widget.isOptimized
        ? "roundtrip=false&source=first&steps=true&geometries=geojson&overview=false&approaches=$unrestrictedStr"
        : "steps=true&geometries=geojson&overview=false&continue_straight=false&approaches=$unrestrictedStr";

    final url = Uri.parse(
      'https://router.project-osrm.org/$mode/v1/foot/$coordinatesString?$params',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = widget.isOptimized ? data['trips'] : data['routes'];
        final legs = items[0]['legs'] as List;

        List<List<LatLng>> allSegments = [];

        for (var leg in legs) {
          List<LatLng> segPoints = [];
          final steps = leg['steps'] as List;
          for (var step in steps) {
            final geometry = step['geometry'];
            if (geometry != null && geometry['coordinates'] != null) {
              for (var coord in geometry['coordinates']) {
                segPoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
              }
            }
          }

          if (segPoints.length > 1) {
            double dynamicOffset = 0.8 + ((allSegments.length % 4) * 0.5);
            List<LatLng> shiftedSegment = _calculateSmoothOffset(
              segPoints,
              dynamicOffset,
            );
            allSegments.add(shiftedSegment);
          }
        }

        setState(() {
          _routeSegments = allSegments;
        });
      }
    } catch (e) {
      print("OSRM API Bağlantı Hatası: $e");
    }
  }

  Future<void> _fetchMekanlar() async {
    try {
      final data = await Supabase.instance.client
          .from('mekanlar')
          .select('*, kategoriler(kategori_adi, ikon_kodu)');

      setState(() {
        _tumMekanlar = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Marker> _buildDirectionalArrows() {
    List<Marker> arrows = [];
    final Distance distanceTool = const Distance();

    for (int s = 0; s < _routeSegments.length; s++) {
      var segmentPoints = _routeSegments[s];
      if (segmentPoints.length < 2) continue;

      int step = 8;

      for (int i = 0; i < segmentPoints.length - 1; i += step) {
        LatLng p1 = segmentPoints[i];
        int nextIndex = (i + 2 < segmentPoints.length)
            ? i + 2
            : segmentPoints.length - 1;
        if (nextIndex == i) break;

        LatLng p2 = segmentPoints[nextIndex];

        double bearingDeg = distanceTool.bearing(p1, p2);
        double bearingRads = bearingDeg * math.pi / 180;

        arrows.add(
          Marker(
            point: p1,
            width: 24,
            height: 24,
            alignment: Alignment.center,
            child: Transform.rotate(
              angle: bearingRads,
              child: const Icon(
                Icons.keyboard_double_arrow_up_rounded,
                color: Colors.white,
                size: 18,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 5,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return arrows;
  }

  Widget _buildPin(
    String code,
    bool isSelected,
    int stepNumber,
    int totalSelected,
    bool hasCategoryFilter,
  ) {
    IconData icon;
    Color catColor;
    switch (code) {
      case 'mosque':
        icon = Icons.mosque_outlined;
        catColor = const Color(0xFF008080);
        break;
      case 'museum':
        icon = Icons.museum_outlined;
        catColor = const Color(0xFF8B4513);
        break;
      case 'park':
        icon = Icons.park_outlined;
        catColor = const Color(0xFF228B22);
        break;
      case 'water':
        icon = Icons.water_drop_outlined;
        catColor = Colors.blue[700]!;
        break;
      case 'school':
        icon = Icons.school_outlined;
        catColor = Colors.indigo[800]!;
        break;
      default:
        icon = Icons.location_on_outlined;
        catColor = Colors.red[700]!;
    }

    if (!isSelected) {
      return Container(
        decoration: BoxDecoration(
          color: catColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 18)),
      );
    } else {
      if (hasCategoryFilter) {
        return Container(
          decoration: BoxDecoration(
            color: catColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amberAccent, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ),
        );
      } else {
        Color prevColor;
        Color nextColor;

        if (stepNumber == 1) {
          prevColor = _segmentColors[0];
          nextColor = _segmentColors[0];
        } else if (stepNumber == totalSelected) {
          int segIndex = (stepNumber - 2) % _segmentColors.length;
          prevColor = _segmentColors[segIndex];
          nextColor = _segmentColors[segIndex];
        } else {
          int prevSegIndex = (stepNumber - 2) % _segmentColors.length;
          int nextSegIndex = (stepNumber - 1) % _segmentColors.length;
          prevColor = _segmentColors[prevSegIndex];
          nextColor = _segmentColors[nextSegIndex];
        }

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [prevColor, nextColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ),
        );
      }
    }
  }

  List<Marker> _getDynamicMarkers() {
    List<Marker> markers = [];
    int totalSelected = widget.rotamListesi.length;
    bool hasCategoryFilter = _seciliKategoriler.isNotEmpty;

    for (var m in _tumMekanlar) {
      if (m['enlem'] == null || m['boylam'] == null) continue;

      int routeIndex = widget.rotamListesi.indexWhere(
        (item) => item['id'] == m['id'],
      );
      bool isSelected = routeIndex != -1;
      int stepNumber = routeIndex + 1;

      if (_sadeceRotamiGoster && !isSelected) continue;
      if (hasCategoryFilter && !_seciliKategoriler.contains(m['kategori_id'])) {
        continue;
      }

      String code = m['kategoriler']?['ikon_kodu'] ?? 'location';

      markers.add(
        Marker(
          point: LatLng(m['enlem'], m['boylam']),
          width: isSelected ? 44 : 38,
          height: isSelected ? 44 : 38,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showSheet(m),
              child: _buildPin(
                code,
                isSelected,
                stepNumber,
                totalSelected,
                hasCategoryFilter,
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _showSheet(Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) {
          bool isAdded = widget.rotamListesi.any(
            (item) => item['id'] == m['id'],
          );
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    m['resim_url'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  m['isim'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  m['kategoriler']?['kategori_adi'] ?? 'Genel',
                  style: TextStyle(
                    color: Colors.indigo[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(m['aciklama'] ?? ''),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.rotayaEkleCikar(m);
                      setS(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded
                          ? Colors.green
                          : Colors.indigo[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(isAdded ? 'Rotadan Çıkar' : 'Rotama Ekle'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleKategori(int id) {
    setState(() {
      if (_seciliKategoriler.contains(id)) {
        _seciliKategoriler.remove(id);
      } else {
        _seciliKategoriler.add(id);
      }
    });
  }

  Widget _buildPremiumChip(
    String label,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.indigo[900],
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.indigo[800]),
            const SizedBox(width: 10),
            const Text(
              "Akıllı Rota",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "Oto mod kapalıyken rotayı 'Rotam' sekmesinden kendi istediğiniz sıraya göre dizebilirsiniz.\n\nOto mod açıkken sistem yürüme mesafesini baz alarak en verimli güzergahı otomatik olarak hesaplar ve sıralar.",
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Anladım",
              style: TextStyle(
                color: Colors.indigo[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(41.0082, 28.9784),
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://cartodb-basemaps-{s}.global.ssl.fastly.net/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    PolylineLayer(
                      polylines: List.generate(_routeSegments.length, (index) {
                        return Polyline(
                          points: _routeSegments[index],
                          color: _segmentColors[index % _segmentColors.length]
                              .withOpacity(0.95),
                          strokeWidth: 6.5,
                          strokeCap: StrokeCap.round,
                          strokeJoin: StrokeJoin.round,
                        );
                      }),
                    ),
                    MarkerLayer(markers: _buildDirectionalArrows()),
                    MarkerLayer(markers: _getDynamicMarkers()),
                  ],
                ),
                Positioned(
                  top: 25,
                  left: 15,
                  right: 15,
                  child: SafeArea(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                _buildPremiumChip(
                                  '📍 Sadece Rotam',
                                  _sadeceRotamiGoster,
                                  Colors.indigo[800]!,
                                  () => setState(
                                    () => _sadeceRotamiGoster =
                                        !_sadeceRotamiGoster,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '🌍 Tümü',
                                  _seciliKategoriler.isEmpty,
                                  Colors.grey[800]!,
                                  () => setState(
                                    () => _seciliKategoriler.clear(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '🕌 İbadethane',
                                  _seciliKategoriler.contains(1),
                                  const Color(0xFF008080),
                                  () => _toggleKategori(1),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '🏛️ Tarihi Eser',
                                  _seciliKategoriler.contains(2),
                                  const Color(0xFF8B4513),
                                  () => _toggleKategori(2),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '🌳 Doğa & Park',
                                  _seciliKategoriler.contains(3),
                                  const Color(0xFF228B22),
                                  () => _toggleKategori(3),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '💧 Su Yapısı',
                                  _seciliKategoriler.contains(4),
                                  Colors.blue[700]!,
                                  () => _toggleKategori(4),
                                ),
                                const SizedBox(width: 8),
                                _buildPremiumChip(
                                  '🎓 Eğitim',
                                  _seciliKategoriler.contains(5),
                                  Colors.indigo[800]!,
                                  () => _toggleKategori(5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  right: 15,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 6,
                        top: 4,
                        bottom: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showInfoDialog,
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.indigo[400],
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Oto",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.indigo[900],
                            ),
                          ),
                          Switch(
                            value: widget.isOptimized,
                            onChanged: widget.onToggleOptimize,
                            activeThumbColor: Colors.amberAccent,
                            activeTrackColor: Colors.indigo[700],
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
