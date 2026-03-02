import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

// Supabase Konfiguration
const supabaseUrl = 'https://quptrocxksdqkvcfgzvc.supabase.co';
const supabaseKey = 'sb_publishable_eR8hYowZBrevF0ywKwQLzA_d5xUmOlH';

// MYPOSTER Affiliate Link (wird nach Genehmigung ersetzt)
const myposterAffiliateLink = 'https://www.myposter.de';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const FamilienTagebuchApp());
}

class FamilienTagebuchApp extends StatelessWidget {
  const FamilienTagebuchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Familien Tagebuch',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const Startseite(),
    );
  }
}

class Startseite extends StatefulWidget {
  const Startseite({super.key});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  final TextEditingController _controllerTitel = TextEditingController();
  final TextEditingController _controllerBeschreibung = TextEditingController();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _eintraege = [];
  List<Map<String, dynamic>> _sammlungen = [];
  Set<int> _ausgewaehlteBilder = {};
  bool _isLoading = true;
  String? _ausgewaehltesBildPfad;
  bool _uploadLaeuft = false;

  @override
  void initState() {
    super.initState();
    _ladeEintraege();
    _ladeSammlungen();
  }

  Future<void> _ladeEintraege() async {
    try {
      final response = await supabase
          .from('eintrage')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _eintraege = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
      }
    }
  }

  Future<void> _ladeSammlungen() async {
    try {
      final response = await supabase
          .from('sammlungen')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _sammlungen = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Fehler beim Laden Sammlungen: $e');
    }
  }

  Future<void> _bildAuswaehlen() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _ausgewaehltesBildPfad = result.files.single.path;
      });
    }
  }

  Future<void> _bildHochladen(String eintragId) async {
    if (_ausgewaehltesBildPfad == null) return;
    setState(() => _uploadLaeuft = true);

    try {
      final file = File(_ausgewaehltesBildPfad!);
      final fileName =
          '${eintragId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('fotos')
          .upload(fileName, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('fotos').getPublicUrl(fileName);

      await supabase
          .from('eintrage')
          .update({'foto_url': publicUrl})
          .eq('id', int.parse(eintragId));

      setState(() => _ausgewaehltesBildPfad = null);
      _ladeEintraege();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bild hochgeladen!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Upload: $e')));
      }
    } finally {
      setState(() => _uploadLaeuft = false);
    }
  }

  Future<void> _speichern() async {
    if (_controllerTitel.text.isEmpty) return;
    setState(() => _uploadLaeuft = true);

    try {
      final response = await supabase.from('eintrage').insert({
        'text': _controllerTitel.text,
        'beschreibung': _controllerBeschreibung.text,
        'datum': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      final eintragId = response[0]['id'].toString();
      _controllerTitel.clear();
      _controllerBeschreibung.clear();

      await _bildHochladen(eintragId);
      _ladeEintraege();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Eintrag gespeichert!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      setState(() => _uploadLaeuft = false);
    }
  }

  Future<void> _loeschen(int index) async {
    try {
      final eintrag = _eintraege[index];
      await supabase.from('eintrage').delete().eq('id', eintrag['id']);
      _ladeEintraege();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
      }
    }
  }

  void _bildAuswaehlenToggle(int eintragId) {
    setState(() {
      if (_ausgewaehlteBilder.contains(eintragId)) {
        _ausgewaehlteBilder.remove(eintragId);
      } else {
        _ausgewaehlteBilder.add(eintragId);
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
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Sammlung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Name für die Sammlung:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Sammlungsname',
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

    if (result == true && controller.text.isNotEmpty) {
      try {
        await supabase.from('sammlungen').insert({
          'name': controller.text,
          'status': 'draft',
        });
        _ladeSammlungen();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sammlung erstellt!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  Future<void> _neueSammlungErstellenMitBilder() async {
    if (_ausgewaehlteBilder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst Bilder auswählen!')),
      );
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Sammlung mit Bildern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_ausgewaehlteBilder.length Bilder werden hinzugefügt'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Sammlungsname',
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

    if (result == true && controller.text.isNotEmpty) {
      try {
        final response = await supabase.from('sammlungen').insert({
          'name': controller.text,
          'status': 'draft',
        }).select();

        final sammlungId = response[0]['id'] as int;

        for (final eintragId in _ausgewaehlteBilder) {
          try {
            await supabase.from('sammlung_bilder').insert({
              'sammlung_id': sammlungId,
              'eintrag_id': eintragId,
              'reihenfolge': _ausgewaehlteBilder.length,
            });
          } catch (_) {
            // Bild ist schon in der Sammlung, ignorieren
          }
        }

        setState(() {
          _ausgewaehlteBilder.clear();
        });

        _ladeSammlungen();
        _ladeEintraege();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sammlung mit Bildern erstellt!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  Future<void> _zuSammlungHinzufuegen() async {
    if (_ausgewaehlteBilder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte mindestens 1 Bild auswählen!')),
      );
      return;
    }

    await _ladeSammlungen();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zur Sammlung hinzufügen'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_ausgewaehlteBilder.length Bilder werden hinzugefügt'),
              const SizedBox(height: 16),
              const Text('Bestehende Sammlung:'),
              const SizedBox(height: 8),
              ..._sammlungen.map(
                (s) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(s['name']),
                  subtitle: Text(_formatiereDatum(s['created_at'])),
                  onTap: () => Navigator.pop(context, {
                    'type': 'existing',
                    'sammlung_id': s['id'],
                  }),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text(
                  'Neue Sammlung erstellen...',
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

    if (result != null) {
      if (result['type'] == 'new') {
        await _neueSammlungErstellenMitBilder();
        return;
      }

      final sammlungId = result['sammlung_id'] as int;

      try {
        for (final eintragId in _ausgewaehlteBilder) {
          try {
            await supabase.from('sammlung_bilder').insert({
              'sammlung_id': sammlungId,
              'eintrag_id': eintragId,
              'reihenfolge': _ausgewaehlteBilder.length,
            });
          } catch (_) {
            // Bild ist schon in der Sammlung, ignorieren
          }
        }

        setState(() {
          _ausgewaehlteBilder.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bilder zur Sammlung hinzugefügt!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  void _sammlungenAnzeigen() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 600,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Meine Sammlungen',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _ausgewaehlteBilder.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _neueSammlungErstellenMitBilder();
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Neue Sammlung'),
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
                    ? const Center(child: Text('Noch keine Sammlungen'))
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
                        itemBuilder: (context, index) {
                          final sammlung = _sammlungen[index];
                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _sammlungOeffnen(sammlung),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.photo_album,
                                    size: 60,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      sammlung['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatiereDatum(sammlung['created_at']),
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

  void _sammlungOeffnen(Map<String, dynamic> sammlung) async {
    try {
      final response = await supabase
          .from('sammlung_bilder')
          .select('*, eintrage(*)')
          .eq('sammlung_id', sammlung['id'])
          .order('reihenfolge', ascending: true);

      final bilder = (response as List)
          .map((r) => r['eintrage'] as Map<String, dynamic>)
          .toList();

      if (!mounted) return;

      Navigator.pop(context);

      final bildListe = bilder
          .where(
            (e) => e['foto_url'] != null && e['foto_url'].toString().isNotEmpty,
          )
          .map(
            (e) => {'url': e['foto_url'], 'titel': e['text'] ?? 'Ohne Titel'},
          )
          .toList();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 900,
            height: 700,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        sammlung['name'],
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
                                : () => _fotobuchBestellen(bildListe, context),
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Fotobuch bestellen'),
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
                      ? const Center(
                          child: Text('Noch keine Bilder in dieser Sammlung'),
                        )
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
                          itemBuilder: (context, index) {
                            final eintrag = bilder[index];
                            final fotoUrl = eintrag['foto_url'];
                            final hatFoto =
                                fotoUrl != null &&
                                fotoUrl.toString().isNotEmpty;

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (hatFoto)
                                    Image.network(
                                      fotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) =>
                                          const Icon(Icons.broken_image),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      color: Colors.black54,
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        eintrag['text'] ?? '',
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  void _fotobuchBestellen(
    List<Map<String, dynamic>> bilder,
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotobuch bestellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${bilder.length} Bilder ausgewählt'),
            const SizedBox(height: 16),
            const Text(
              'So geht\'s:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Klicke auf "Zu MYPOSTER"'),
            const Text('2. Lade deine Bilder dort hoch'),
            const Text('3. Wähle Fotobuch-Format und Design'),
            const Text('4. Bestellung abschließen'),
            const SizedBox(height: 16),
            const Text(
              'Tipp: Bilder werden im nächsten Schritt vorbereitet...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              final Uri url = Uri.parse(myposterAffiliateLink);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('MYPOSTER wurde geöffnet!')),
                );
              }
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

  void _bildAnzeigen(String url, String titel) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    titel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (c, o, s) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatiereDatum(String datumString) {
    try {
      final datum = DateTime.parse(datumString);
      return '${datum.day}.${datum.month}.${datum.year}';
    } catch (e) {
      return 'Datum unbekannt';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familien Tagebuch'),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_album),
            onPressed: _sammlungenAnzeigen,
            tooltip: 'Sammlungen',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                TextField(
                  controller: _controllerTitel,
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controllerBeschreibung,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _bildAuswaehlen,
                        icon: const Icon(Icons.image),
                        label: Text(
                          _ausgewaehltesBildPfad == null
                              ? 'Bild auswählen'
                              : 'Bild gewählt',
                        ),
                      ),
                    ),
                    if (_ausgewaehltesBildPfad != null)
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () =>
                            setState(() => _ausgewaehltesBildPfad = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _uploadLaeuft ? null : _speichern,
            child: _uploadLaeuft
                ? const CircularProgressIndicator()
                : const Text('Speichern'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value:
                          _ausgewaehlteBilder.isNotEmpty &&
                          _ausgewaehlteBilder.length == _eintraege.length,
                      onChanged: (_) => _alleAuswaehlen(),
                    ),
                    const Text('Alle'),
                    const SizedBox(width: 16),
                    if (_ausgewaehlteBilder.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _zuSammlungHinzufuegen,
                        icon: const Icon(Icons.add_to_photos),
                        label: Text(
                          'Zur Sammlung (${_ausgewaehlteBilder.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _eintraege.isEmpty
                ? const Center(child: Text('Noch keine Einträge'))
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: _eintraege.length,
                    itemBuilder: (context, index) {
                      final eintrag = _eintraege[index];
                      final eintragId = eintrag['id'] as int;
                      final fotoUrl = eintrag['foto_url'];
                      final hatFoto =
                          fotoUrl != null && fotoUrl.toString().isNotEmpty;
                      final titel = eintrag['text'] ?? 'Ohne Titel';
                      final isSelected = _ausgewaehlteBilder.contains(
                        eintragId,
                      );

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: hatFoto
                                  ? () => _bildAnzeigen(fotoUrl, titel)
                                  : null,
                              child: Container(
                                color: Colors.grey[200],
                                child: hatFoto
                                    ? Image.network(
                                        fotoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, o, s) => const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) =>
                                    _bildAuswaehlenToggle(eintragId),
                                shape: const CircleBorder(),
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  titel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 22,
                                ),
                                onPressed: () => _loeschen(index),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
