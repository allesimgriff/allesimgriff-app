import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';
import '../widgets/eintrag_card.dart';
import '../widgets/eingabe_card.dart';

import '../main.dart' show myposterAffiliateLink;

class Startseite extends StatefulWidget {
  const Startseite({super.key});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  final TextEditingController _controllerTitel = TextEditingController();
  final TextEditingController _controllerBeschreibung = TextEditingController();

  List<Map<String, dynamic>> _eintraege = [];
  List<Map<String, dynamic>> _sammlungen = [];
  Set<int> _ausgewaehlteBilder = {};

  bool _isLoading = true;
  bool _busy = false;

  String? _ausgewaehltesBildName;
  Uint8List? _ausgewaehltesBildBytes;
  String? _ausgewaehltesBildExtension;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _ladeEintraege(),
      _ladeSammlungen(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _ladeEintraege() async {
    try {
      final response = await SupabaseService.instance.ladeEintraege();
      if (!mounted) return;
      setState(() {
        _eintraege = response;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Laden der Einträge: $e')),
      );
    }
  }

  Future<void> _ladeSammlungen() async {
    try {
      final response = await SupabaseService.instance.ladeSammlungen();
      if (!mounted) return;
      setState(() {
        _sammlungen = response;
      });
    } catch (_) {
      // nicht kritisch
    }
  }

  Future<void> _bildAuswaehlen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'heic' || ext == 'heif') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('HEIC nicht unterstützt. Bitte JPG/PNG/WebP verwenden.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datei konnte nicht geladen werden.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _ausgewaehltesBildName = file.name;
      _ausgewaehltesBildBytes = file.bytes!;
      _ausgewaehltesBildExtension = ext.isEmpty ? 'jpg' : ext;
    });
  }

  void _bildReset() {
    setState(() {
      _ausgewaehltesBildName = null;
      _ausgewaehltesBildBytes = null;
      _ausgewaehltesBildExtension = null;
    });
  }

  Future<void> _speichern() async {
    final titel = _controllerTitel.text.trim();
    final beschreibung = _controllerBeschreibung.text.trim();

    if (titel.isEmpty &&
        beschreibung.isEmpty &&
        _ausgewaehltesBildBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte Titel/Beschreibung eingeben oder ein Bild auswählen.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await SupabaseService.instance.speichereEintrag(
        titel: titel,
        beschreibung: beschreibung,
        bildBytes: _ausgewaehltesBildBytes,
        bildExtension: _ausgewaehltesBildExtension,
      );

      _bildReset();

      _controllerTitel.clear();
      _controllerBeschreibung.clear();

      await _ladeEintraege();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loeschen(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Löschen?'),
        content: const Text('Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await SupabaseService.instance
          .loescheEintrag(_eintraege[index]['id'] as int);
      await _ladeEintraege();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $e')),
      );
    }
  }

  Future<void> _eintragBearbeiten(Map<String, dynamic> eintrag) async {
    final titelCtrl =
        TextEditingController(text: (eintrag['text'] ?? '').toString());
    final beschrCtrl =
        TextEditingController(text: (eintrag['beschreibung'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eintrag bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titelCtrl,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: beschrCtrl,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final neuerTitel = titelCtrl.text.trim();
    final neueBeschreibung = beschrCtrl.text.trim();

    try {
      await SupabaseService.instance.updateEintrag(
        eintrag['id'] as int,
        neuerTitel,
        neueBeschreibung,
      );
      await _ladeEintraege();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Aktualisieren: $e')),
      );
    }
  }

  void _bildAuswaehlenToggle(int id) {
    setState(() {
      if (_ausgewaehlteBilder.contains(id)) {
        _ausgewaehlteBilder.remove(id);
      } else {
        _ausgewaehlteBilder.add(id);
      }
    });
  }

  void _alleAuswaehlen() {
    setState(() {
      if (_ausgewaehlteBilder.length == _eintraege.length) {
        _ausgewaehlteBilder.clear();
      } else {
        _ausgewaehlteBilder = _eintraege.map((e) => e['id'] as int).toSet();
      }
    });
  }

  Future<void> _neueSammlungErstellen() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neue Sammlung'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty) return;

    try {
      await SupabaseService.instance.neueSammlungErstellen(name);
      await _ladeSammlungen();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sammlung erstellt!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _neueSammlungMitBilder() async {
    if (_ausgewaehlteBilder.isEmpty) return;

    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sammlung mit Bildern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_ausgewaehlteBilder.length} ausgewählt'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty) return;

    try {
      await SupabaseService.instance
          .neueSammlungMitBilder(name, _ausgewaehlteBilder);

      setState(() => _ausgewaehlteBilder.clear());
      await _ladeSammlungen();
      await _ladeEintraege();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sammlung erstellt!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _zuSammlungHinzufuegen() async {
    if (_ausgewaehlteBilder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Bilder auswählen')),
      );
      return;
    }

    await _ladeSammlungen();

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Zur Sammlung hinzufügen'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_ausgewaehlteBilder.length} ausgewählt'),
              const SizedBox(height: 12),
              const Text('Bestehende Sammlungen:'),
              const SizedBox(height: 8),
              if (_sammlungen.isEmpty) const Text('Keine Sammlungen vorhanden'),
              ..._sammlungen.map(
                (s) => ListTile(
                  title: Text((s['name'] ?? '').toString()),
                  subtitle:
                      Text(_formatDatum((s['created_at'] ?? '').toString())),
                  onTap: () =>
                      Navigator.pop(context, {'type': 'exist', 'id': s['id']}),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text(
                  'Neue Sammlung...',
                  style: TextStyle(color: Colors.green),
                ),
                onTap: () => Navigator.pop(context, {'type': 'new'}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result['type'] == 'new') {
      await _neueSammlungMitBilder();
      return;
    }

    final sid = result['id'] as int;

    try {
      await SupabaseService.instance
          .bilderZuSammlungHinzufuegen(sid, _ausgewaehlteBilder);

      setState(() => _ausgewaehlteBilder.clear());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hinzugefügt!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void _sammlungenAnzeigen() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 900,
          height: 650,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sammlungen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _neueSammlungErstellen,
                          icon: const Icon(Icons.add),
                          label: const Text('Neu'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _sammlungen.isEmpty
                    ? const Center(child: Text('Keine Sammlungen'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _sammlungen.length,
                        itemBuilder: (c, i) {
                          final s = _sammlungen[i];
                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _sammlungOeffnen(s),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.photo_album, size: 64),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      (s['name'] ?? '').toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDatum(
                                      (s['created_at'] ?? '').toString(),
                                    ),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sammlungOeffnen(Map<String, dynamic> sammlung) async {
    try {
      final bilder = await SupabaseService.instance
          .ladeSammlungBilder(sammlung['id'] as int);

      if (!mounted) return;

      final bildListe = bilder
          .map((e) => (e['foto_url'] ?? '').toString().trim())
          .where((u) => u.isNotEmpty)
          .map((u) => {'url': u})
          .toList();

      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: SizedBox(
            width: 1000,
            height: 720,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (sammlung['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: bildListe.isEmpty
                                ? null
                                : () => _fotobuchBestellen(bildListe),
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Bestellen'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bilder.isEmpty
                      ? const Center(child: Text('Keine Bilder'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: bilder.length,
                          itemBuilder: (c, i) {
                            final e = bilder[i];
                            final titel =
                                (e['text'] ?? 'Ohne Titel').toString();
                            final url = (e['foto_url'] ?? '').toString().trim();
                            final hat = url.isNotEmpty;

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: InkWell(
                                onTap: hat
                                    ? () => _bildAnzeigen(url, titel)
                                    : null,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (hat)
                                      Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (c, child, lp) =>
                                            lp == null
                                                ? child
                                                : const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                          child: Icon(Icons.broken_image),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(
                                            Icons.description,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black54,
                                        padding: const EdgeInsets.all(6),
                                        child: Text(
                                          titel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void _fotobuchBestellen(List<Map<String, dynamic>> bilder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fotobuch bestellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${bilder.length} Bilder'),
            const SizedBox(height: 12),
            const Text(
              '1. Auf "Zu MYPOSTER" klicken\n'
              '2. Bilder hochladen\n'
              '3. Format wählen\n'
              '4. Bestellen',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse(myposterAffiliateLink);
              await launchUrl(url, mode: LaunchMode.externalApplication);
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Zu MYPOSTER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _bildAnzeigen(String url, String titel, [String? beschreibung]) {
    final cleanUrl = url.trim();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: SizedBox(
          width: 900,
          height: 650,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.network(
                          cleanUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, lp) => lp == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                      ),
                      if (beschreibung != null &&
                          beschreibung.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              child: Text(
                                beschreibung,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _textEintragAnzeigen(String titel, String beschreibung) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titel),
        content: beschreibung.trim().isEmpty
            ? const Text('Keine Beschreibung vorhanden.')
            : SingleChildScrollView(child: Text(beschreibung)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  String _formatDatum(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day}.${d.month}.${d.year}';
    } catch (_) {
      return 'Unbekannt';
    }
  }

  int _crossAxisCountForWidth(double width) {
    if (width >= 1400) return 5;
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 520) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _eintraege.isNotEmpty &&
        _ausgewaehlteBilder.length == _eintraege.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Familien Tagebuch'),
        actions: [
          IconButton(
            tooltip: 'Sammlungen',
            icon: const Icon(Icons.photo_album),
            onPressed: _sammlungenAnzeigen,
          ),
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAll,
          ),
        ],
      ),
      body: Column(
        children: [
          EingabeCard(
            titelController: _controllerTitel,
            beschreibungController: _controllerBeschreibung,
            busy: _busy,
            ausgewaehltesBildName: _ausgewaehltesBildName,
            ausgewaehltesBildExtension: _ausgewaehltesBildExtension,
            onBildAuswaehlen: _bildAuswaehlen,
            onBildReset: _bildReset,
            onSpeichern: _speichern,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged:
                      _eintraege.isEmpty ? null : (_) => _alleAuswaehlen(),
                ),
                const Text('Alle'),
                const SizedBox(width: 12),
                if (_ausgewaehlteBilder.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _zuSammlungHinzufuegen,
                    icon: const Icon(Icons.add_to_photos),
                    label: Text('Sammlung (${_ausgewaehlteBilder.length})'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _eintraege.isEmpty
                    ? const Center(
                        child: Text(
                          'Noch keine Einträge',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final count =
                              _crossAxisCountForWidth(constraints.maxWidth);

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: count,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.15,
                            ),
                            itemCount: _eintraege.length,
                            itemBuilder: (c, i) {
                              final e = _eintraege[i];
                              final id = (e['id'] ?? 0) as int;

                              final titel =
                                  (e['text'] ?? 'Ohne Titel').toString();
                              final url =
                                  (e['foto_url'] ?? '').toString().trim();
                              final beschreibung =
                                  (e['beschreibung'] ?? '').toString();
                              final sel = _ausgewaehlteBilder.contains(id);

                              return EintragCard(
                                titel: titel,
                                fotoUrl: url,
                                istAusgewaehlt: sel,
                                onAuswahlGeaendert: () =>
                                    _bildAuswaehlenToggle(id),
                                onLoeschen: () => _loeschen(i),
                                onBearbeiten: () => _eintragBearbeiten(e),
                                onBildAnzeigen: () => url.isEmpty
                                    ? _textEintragAnzeigen(titel, beschreibung)
                                    : _bildAnzeigen(url, titel, beschreibung),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllerTitel.dispose();
    _controllerBeschreibung.dispose();
    super.dispose();
  }
}

