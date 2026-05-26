import 'dart:convert';
import 'dart:ui'; // Buzlu cam efekti için eklendi
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const RotaApp());
}

class RotaApp extends StatelessWidget {
  const RotaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AnaEkran(),
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});
  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _seciliSayfa = 0;
  List<Map<String, dynamic>> _rotamListesi = [];

  void _rotayaEkleCikar(Map<String, dynamic> mekan) {
    setState(() {
      bool varMi = _rotamListesi.any((m) => m['id'] == mekan['id']);
      if (varMi) {
        _rotamListesi.removeWhere((m) => m['id'] == mekan['id']);
      } else {
        _rotamListesi.add(mekan);
      }
      _rotamListesi = List.from(_rotamListesi);
    });
  }

  void _rotayiYenidenSirala(int eskiSira, int yeniSira) {
    setState(() {
      if (eskiSira < yeniSira) {
        yeniSira -= 1;
      }
      final mekan = _rotamListesi.removeAt(eskiSira);
      _rotamListesi.insert(yeniSira, mekan);
      _rotamListesi = List.from(_rotamListesi);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: [
        HaritaEkrani(
          rotamListesi: _rotamListesi,
          rotayaEkleCikar: _rotayaEkleCikar,
        ),
        RotamEkrani(
          rotamListesi: _rotamListesi,
          rotayaEkleCikar: _rotayaEkleCikar,
          rotayiYenidenSirala: _rotayiYenidenSirala,
        ),
      ][_seciliSayfa],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _seciliSayfa,
        onTap: (index) => setState(() => _seciliSayfa = index),
        selectedItemColor: Colors.indigo[700],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Keşfet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Rotam',
          ),
        ],
      ),
    );
  }
}

// --- HARİTA EKRANI ---
class HaritaEkrani extends StatefulWidget {
  final List<Map<String, dynamic>> rotamListesi;
  final Function(Map<String, dynamic>) rotayaEkleCikar;
  const HaritaEkrani({
    super.key,
    required this.rotamListesi,
    required this.rotayaEkleCikar,
  });
  @override
  State<HaritaEkrani> createState() => _HaritaEkraniState();
}

class _HaritaEkraniState extends State<HaritaEkrani> {
  List<Map<String, dynamic>> _tumMekanlar = [];
  List<LatLng> _routePoints = [];
  bool _loading = true;

  bool _sadeceRotamiGoster = false;
  List<int> _seciliKategoriler = [];

  @override
  void initState() {
    super.initState();
    _fetchMekanlar();
    _fetchGercelRota();
  }

  @override
  void didUpdateWidget(covariant HaritaEkrani oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotamListesi != widget.rotamListesi) {
      _fetchGercelRota();
    }
  }

  Future<void> _fetchGercelRota() async {
    if (widget.rotamListesi.length < 2) {
      setState(() {
        _routePoints = [];
      });
      return;
    }

    final String coordinatesString = widget.rotamListesi
        .map((m) => "${m['boylam']},${m['enlem']}")
        .join(";");

    Uri url;
    bool isSimpleRoute = widget.rotamListesi.length == 2;

    if (isSimpleRoute) {
      url = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/$coordinatesString?overview=full&geometries=geojson',
      );
    } else {
      url = Uri.parse(
        'https://router.project-osrm.org/trip/v1/foot/$coordinatesString?roundtrip=false&source=first&destination=last&overview=full&geometries=geojson',
      );
    }

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rawCoordinates;

        if (isSimpleRoute) {
          rawCoordinates = data['routes'][0]['geometry']['coordinates'];
        } else {
          rawCoordinates = data['trips'][0]['geometry']['coordinates'];
        }

        List<LatLng> points = rawCoordinates
            .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
            .toList();

        setState(() {
          _routePoints = points;
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

  Widget _buildPin(String code, bool isSelected, int stepNumber) {
    IconData icon;
    Color color;
    switch (code) {
      case 'mosque':
        icon = Icons.mosque_outlined;
        color = const Color(0xFF008080);
        break;
      case 'museum':
        icon = Icons.museum_outlined;
        color = const Color(0xFF8B4513);
        break;
      case 'park':
        icon = Icons.park_outlined;
        color = const Color(0xFF228B22);
        break;
      case 'water':
        icon = Icons.water_drop_outlined;
        color = Colors.blue[700]!;
        break;
      case 'school':
        icon = Icons.school_outlined;
        color = Colors.indigo[800]!;
        break;
      default:
        icon = Icons.location_on_outlined;
        color = Colors.red[700]!;
    }

    if (isSelected) {
      return Container(
        decoration: BoxDecoration(
          color: color,
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
            ),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: color,
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
    }
  }

  List<Marker> _getDynamicMarkers() {
    List<Marker> markers = [];
    for (var m in _tumMekanlar) {
      if (m['enlem'] == null || m['boylam'] == null) continue;

      int routeIndex = widget.rotamListesi.indexWhere(
        (item) => item['id'] == m['id'],
      );
      bool isSelected = routeIndex != -1;
      int stepNumber = routeIndex + 1;

      if (_sadeceRotamiGoster && !isSelected) continue;
      if (_seciliKategoriler.isNotEmpty &&
          !_seciliKategoriler.contains(m['kategori_id']))
        continue;

      String code = m['kategoriler']?['ikon_kodu'] ?? 'location';
      m['kategori_adi'] = m['kategoriler']?['kategori_adi'] ?? 'Genel';

      markers.add(
        Marker(
          point: LatLng(m['enlem'], m['boylam']),
          width: isSelected ? 48 : 38,
          height: isSelected ? 48 : 38,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showSheet(m),
              child: _buildPin(code, isSelected, stepNumber),
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
                  m['kategori_adi'],
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

  // --- PREMIUM TASARIM DOKUNUŞU: ŞIK BUTON OLUŞTURUCU ---
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
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          color: Colors.indigo[600]!.withOpacity(0.8),
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                    MarkerLayer(markers: _getDynamicMarkers()),
                  ],
                ),

                // --- PREMIUM GLASSMORPHISM (BUZLU CAM) MENÜ PANelİ ---
                Positioned(
                  top: 15,
                  left: 15,
                  right: 15, // Haritadan hafif kopuk, havada süzülen panel
                  child: SafeArea(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 12,
                          sigmaY: 12,
                        ), // Güçlü Apple stili bulanıklık
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.45), // Şeffaf cam
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
              ],
            ),
    );
  }
}

// --- PREMIUM ROTAM EKRANI ---
class RotamEkrani extends StatelessWidget {
  final List<Map<String, dynamic>> rotamListesi;
  final Function(Map<String, dynamic>) rotayaEkleCikar;
  final Function(int, int) rotayiYenidenSirala;

  const RotamEkrani({
    super.key,
    required this.rotamListesi,
    required this.rotayaEkleCikar,
    required this.rotayiYenidenSirala,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Benim Rotam',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.indigo[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: rotamListesi.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text(
                    "Rotan şu an bomboş.",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Keşfet sekmesinden yeni yerler ekleyebilirsin.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          // İŞTE YENİ ZIRH: ReorderableDragStartListener ile kartın neresinden tutarsan tut anında havaya kalkar!
          : ReorderableListView.builder(
              buildDefaultDragHandles:
                  false, // Tarayıcıdaki bozuk varsayılan sistemi tamamen iptal ettik
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: rotamListesi.length,
              onReorder: (oldIndex, newIndex) =>
                  rotayiYenidenSirala(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) => Material(
                elevation: 12,
                color: Colors.transparent,
                child: child,
              ), // Sürüklerken Premium Gölge
              itemBuilder: (context, i) {
                final mekan = rotamListesi[i];
                int stepNumber = i + 1;

                return ReorderableDragStartListener(
                  key: ValueKey("mekan_${mekan['id']}"),
                  index: i,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Dismissible(
                      key: ValueKey("dismiss_${mekan['id']}"),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => rotayaEkleCikar(mekan),
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 25),
                        child: const Icon(
                          Icons.delete_sweep,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                  ),
                                  child: Image.network(
                                    mekan['resim_url'] ?? "",
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  left: 5,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.amberAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$stepNumber',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mekan['isim'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.indigo[900],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        mekan['kategori_adi'] ?? 'Genel',
                                        style: TextStyle(
                                          color: Colors.indigo[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Geri dönen şık çöp kutusu (Sürükleme yeteneğiyle çakışmaz)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => rotayaEkleCikar(mekan),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
