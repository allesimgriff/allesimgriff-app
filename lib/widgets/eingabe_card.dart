import 'package:flutter/material.dart';

class EingabeCard extends StatelessWidget {
  const EingabeCard({
    super.key,
    required this.titelController,
    required this.beschreibungController,
    required this.busy,
    required this.ausgewaehltesBildName,
    required this.ausgewaehltesBildExtension,
    required this.onBildAuswaehlen,
    required this.onBildReset,
    required this.onSpeichern,
  });

  final TextEditingController titelController;
  final TextEditingController beschreibungController;
  final bool busy;
  final String? ausgewaehltesBildName;
  final String? ausgewaehltesBildExtension;
  final VoidCallback onBildAuswaehlen;
  final VoidCallback onBildReset;
  final VoidCallback onSpeichern;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: titelController,
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: beschreibungController,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : onBildAuswaehlen,
                  icon: const Icon(Icons.image),
                  label: Text(
                    ausgewaehltesBildName == null
                        ? 'Bild auswählen'
                        : 'Bild: ${(ausgewaehltesBildExtension ?? '').toUpperCase()}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (ausgewaehltesBildName != null)
                IconButton(
                  tooltip: 'Bild ausgewählt (entfernen)',
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: busy ? null : onBildReset,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: busy ? null : onSpeichern,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

