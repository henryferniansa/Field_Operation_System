import 'package:flutter/material.dart';

class PetaPickerPage extends StatefulWidget {
  const PetaPickerPage({super.key});
  @override
  State<PetaPickerPage> createState() => _PetaPickerPageState();
}

class _PetaPickerPageState extends State<PetaPickerPage> {
  double? _tapX;
  double? _tapY;
  double _imgWidth = 0;
  double _imgHeight = 0;

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _tapX = details.localPosition.dx / _imgWidth;
      _tapY = details.localPosition.dy / _imgHeight;
    });
  }

  void _simpanLokasi() {
    if (_tapX != null && _tapY != null) Navigator.pop(context, {'x': _tapX, 'y': _tapY});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pilih Titik Lokasi"), actions: [IconButton(onPressed: _tapX == null ? null : _simpanLokasi, icon: const Icon(Icons.check))]),
      body: LayoutBuilder(builder: (context, constraints) {
        return InteractiveViewer(minScale: 1.0, maxScale: 4.0, child: Center(child: Builder(builder: (context) {
          return Stack(children: [
            GestureDetector(onTapUp: _handleTapUp, child: Image.asset('assets/peta_proyek.jpeg', fit: BoxFit.contain, frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) { if(context.mounted) { final RenderBox? box = context.findRenderObject() as RenderBox?; if (box != null && box.hasSize) { if (_imgWidth != box.size.width || _imgHeight != box.size.height) { setState(() { _imgWidth = box.size.width; _imgHeight = box.size.height; }); } } } });
              } return child;
            })),
            if (_tapX != null && _tapY != null && _imgWidth > 0) Positioned(left: (_tapX! * _imgWidth) - 20, top: (_tapY! * _imgHeight) - 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40, shadows: [Shadow(blurRadius: 5, color: Colors.black45, offset: Offset(1, 1))])),
          ]);
        })));
      }),
      bottomNavigationBar: Container(padding: const EdgeInsets.all(16), color: Colors.white, child: Text(_tapX == null ? "Geser & Zoom, lalu KLIK pada peta." : "Titik terpilih. Tekan Ceklis di pojok kanan atas.", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }
}