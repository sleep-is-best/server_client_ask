import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BannedScreen extends StatelessWidget {
  final String reason;
  final DateTime? expiresAt;

  const BannedScreen({
    super.key,
    required this.reason,
    this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPermanent = expiresAt == null;
    final String dateStr = expiresAt != null 
        ? DateFormat('yyyy/MM/dd HH:mm').format(expiresAt!) 
        : 'إلى الأبد';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block_flipped,
                color: Colors.redAccent,
                size: 100,
              ),
              const SizedBox(height: 30),
              const Text(
                'تم حظر حسابك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'سبب الحظر:',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 30),
                    const Text(
                      'تاريخ انتهاء الحظر:',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermanent ? 'حظر دائم' : dateStr,
                      style: TextStyle(
                        color: isPermanent ? Colors.redAccent : Colors.orangeAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع الإدارة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  // Exit app or logout? Usually logout is better
                  // But for banned, we just want them out.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إغلاق التطبيق', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
