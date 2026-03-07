import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Kapselt alle Supabase-Datenbank- und Storagezugriffe.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  /// Singleton-Instanz für die App.
  static final SupabaseService instance =
      SupabaseService(Supabase.instance.client);

  // --- Einträge ---

  Future<List<Map<String, dynamic>>> ladeEintraege() async {
    final response = await _client
        .from('eintrage')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> loescheEintrag(int id) async {
    await _client.from('eintrage').delete().eq('id', id);
  }

  Future<void> updateEintrag(
    int id,
    String titel,
    String beschreibung,
  ) async {
    await _client.from('eintrage').update({
      'text': titel.isEmpty ? 'Ohne Titel' : titel,
      'beschreibung': beschreibung,
    }).eq('id', id);
  }

  Future<void> speichereEintrag({
    required String titel,
    required String beschreibung,
    Uint8List? bildBytes,
    String? bildExtension,
  }) async {
    final inserted = await _client.from('eintrage').insert({
      'text': titel.isEmpty ? 'Ohne Titel' : titel,
      'beschreibung': beschreibung,
      'datum': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    final eintragId = inserted[0]['id'].toString();

    if (bildBytes != null) {
      final ext = (bildExtension ?? 'jpg').toLowerCase();
      final fileName =
          '${eintragId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final url = await _uploadBytesToStorage(
        fileName: fileName,
        bytes: bildBytes,
        ext: ext,
      );

      await _client
          .from('eintrage')
          .update({'foto_url': url}).eq('id', int.parse(eintragId));
    }
  }

  // --- Sammlungen ---

  Future<List<Map<String, dynamic>>> ladeSammlungen() async {
    final response = await _client
        .from('sammlungen')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> neueSammlungErstellen(String name) async {
    await _client
        .from('sammlungen')
        .insert({'name': name, 'status': 'draft'});
  }

  Future<void> neueSammlungMitBilder(
    String name,
    Iterable<int> eintragIds,
  ) async {
    final res = await _client
        .from('sammlungen')
        .insert({'name': name, 'status': 'draft'}).select();
    final sid = res[0]['id'] as int;

    int order = 1;
    for (final eid in eintragIds) {
      try {
        await _client.from('sammlung_bilder').insert({
          'sammlung_id': sid,
          'eintrag_id': eid,
          'reihenfolge': order,
        });
        order++;
      } catch (_) {
        // einzelne Fehler beim Verknüpfen ignorieren
      }
    }
  }

  Future<void> bilderZuSammlungHinzufuegen(
    int sammlungId,
    Iterable<int> eintragIds,
  ) async {
    final existing = await _client
        .from('sammlung_bilder')
        .select('reihenfolge')
        .eq('sammlung_id', sammlungId) as List;

    int orderStart = 1;
    if (existing.isNotEmpty) {
      final maxOrder = existing
          .map((e) => (e['reihenfolge'] ?? 0) as int)
          .fold<int>(0, (a, b) => a > b ? a : b);
      orderStart = maxOrder + 1;
    }

    int order = orderStart;
    for (final eid in eintragIds) {
      try {
        await _client.from('sammlung_bilder').insert({
          'sammlung_id': sammlungId,
          'eintrag_id': eid,
          'reihenfolge': order,
        });
        order++;
      } catch (_) {
        // einzelne Fehler beim Verknüpfen ignorieren
      }
    }
  }

  Future<List<Map<String, dynamic>>> ladeSammlungBilder(
    int sammlungId,
  ) async {
    final res = await _client
        .from('sammlung_bilder')
        .select('reihenfolge, eintrage(*)')
        .eq('sammlung_id', sammlungId)
        .order('reihenfolge');

    final bilder = (res as List)
        .map((r) => (r['eintrage'] as Map<String, dynamic>))
        .toList();
    return bilder;
  }

  Future<void> removeImageFromCollection(
    int sammlungId,
    int eintragId,
  ) async {
    await _client
        .from('sammlung_bilder')
        .delete()
        .eq('sammlung_id', sammlungId)
        .eq('eintrag_id', eintragId);
  }

  // --- Storage ---

  Future<String> _uploadBytesToStorage({
    required String fileName,
    required Uint8List bytes,
    required String ext,
  }) async {
    await _client.storage.from('fotos').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeForExt(ext),
          ),
        );

    return _client.storage.from('fotos').getPublicUrl(fileName).trim();
  }

  String _contentTypeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

