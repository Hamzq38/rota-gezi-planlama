import 'package:flutter/material.dart';

class RotamEkrani extends StatelessWidget {
  final List<Map<String, dynamic>> rotamListesi;
  final Function(Map<String, dynamic>) rotayaEkleCikar;
  final Function(int, int) rotayiYenidenSirala;
  final bool isOptimized;
  final Function(bool) onToggleOptimize;

  const RotamEkrani({
    super.key,
    required this.rotamListesi,
    required this.rotayaEkleCikar,
    required this.rotayiYenidenSirala,
    required this.isOptimized,
    required this.onToggleOptimize,
  });

  void _showInfoDialog(BuildContext context) {
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
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showInfoDialog(context),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Oto",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Switch(
                value: isOptimized,
                activeColor: Colors.amberAccent,
                onChanged: onToggleOptimize,
              ),
            ],
          ),
        ],
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
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: rotamListesi.length,
              onReorder: (oldIndex, newIndex) =>
                  rotayiYenidenSirala(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) => Material(
                elevation: 12,
                color: Colors.transparent,
                child: child,
              ),
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
                                        mekan['kategoriler']?['kategori_adi'] ??
                                            'Genel',
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
