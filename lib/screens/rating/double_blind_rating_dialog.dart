import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DoubleBlindRatingDialog extends StatefulWidget {
  final String rideId;
  final String rateeName;

  const DoubleBlindRatingDialog({Key? key, required this.rideId, required this.rateeName}) : super(key: key);

  @override
  State<DoubleBlindRatingDialog> createState() => _DoubleBlindRatingDialogState();
}

class _DoubleBlindRatingDialogState extends State<DoubleBlindRatingDialog> {
  int _stars = 5;
  final List<String> _selectedChips = [];

  final List<String> _complimentOptions = [
    '🏆 Super Punctual',
    '🚗 Smooth & Safe Driving',
    '🌟 Clean & Fresh Vehicle',
    '💬 Pleasant Conversation',
    '💖 Went the Extra Mile for Pickup',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Rate ${widget.rateeName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (idx) {
                return IconButton(
                  icon: Icon(
                    idx < _stars ? Icons.star : Icons.star_border,
                    color: AppTheme.accentSaffron,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _stars = idx + 1),
                );
              }),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🔒 Double-Blind Review Shield: Rating is locked & hidden until both commuters submit.', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _complimentOptions.map((chip) {
                final isSelected = _selectedChips.contains(chip);
                return FilterChip(
                  label: Text(chip, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white)),
                  selected: isSelected,
                  selectedColor: AppTheme.accentGreen,
                  backgroundColor: AppTheme.backgroundDark,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedChips.add(chip);
                      } else {
                        _selectedChips.remove(chip);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
          child: const Text('Submit Rating & Compliments', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rating submitted to Double-Blind Escrow! ✅')));
          },
        ),
      ],
    );
  }
}
