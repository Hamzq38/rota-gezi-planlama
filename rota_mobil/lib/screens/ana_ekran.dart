import 'package:flutter/material.dart';
import 'harita_ekrani.dart';
import 'rotam_ekrani.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});
  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _seciliSayfa = 0;
  List<Map<String, dynamic>> _rotamListesi = [];
  bool _isOptimized = false;

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
      if (eskiSira < yeniSira) yeniSira -= 1;
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
          isOptimized: _isOptimized,
          onToggleOptimize: (val) => setState(() => _isOptimized = val),
        ),
        RotamEkrani(
          rotamListesi: _rotamListesi,
          rotayaEkleCikar: _rotayaEkleCikar,
          rotayiYenidenSirala: _rotayiYenidenSirala,
          isOptimized: _isOptimized,
          onToggleOptimize: (val) => setState(() => _isOptimized = val),
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
