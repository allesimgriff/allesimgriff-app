import 'package:flutter/material.dart';

class EintragCard extends StatelessWidget {
  const EintragCard({
    super.key,
    required this.titel,
    required this.fotoUrl,
    required this.istAusgewaehlt,
    required this.onAuswahlGeaendert,
    required this.onLoeschen,
    required this.onBearbeiten,
    this.onBildAnzeigen,
  });

  final String titel;
  final String fotoUrl;
  final bool istAusgewaehlt;
  final VoidCallback onAuswahlGeaendert;
  final VoidCallback onLoeschen;
  final VoidCallback onBearbeiten;
  final VoidCallback? onBildAnzeigen;

  @override
  Widget build(BuildContext context) {
    final bool hatBild = fotoUrl.trim().isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          InkWell(
            onTap: hatBild && onBildAnzeigen != null ? onBildAnzeigen : null,
            child: Container(
              color: hatBild ? Colors.grey[200] : Colors.blue[50],
              child: hatBild
                  ? Image.network(
                      fotoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, lp) =>
                          lp == null ? child : const Center(
                            child: CircularProgressIndicator(),
                          ),
                      errorBuilder: (_, __, ___) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Bild nicht ladbar',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 44,
                          color: Colors.blue[300],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nur Text',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Checkbox(
              value: istAusgewaehlt,
              onChanged: (_) => onAuswahlGeaendert(),
              shape: const CircleBorder(),
              side: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onBearbeiten,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: onLoeschen,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
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
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

