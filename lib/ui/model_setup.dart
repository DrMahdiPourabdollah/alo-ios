import 'package:flutter/material.dart';
import 'theme.dart';

class ModelSetup extends StatelessWidget {
  const ModelSetup({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDCE6E3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.offline_bolt_rounded, color: ink, size: 32),
        const SizedBox(height: 16),
        Text(
          'فارسی، آماده و آفلاین',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'مدل تخصصی تشخیص گفتار فارسی و مدل صدای فارسی داخل همین برنامه هستند. دانلود یا نصب فایل جداگانه لازم نیست.',
          style: TextStyle(color: muted, height: 1.9),
        ),
        const SizedBox(height: 12),
        const Text(
          'در اولین استفاده، مدل‌ها در حافظهٔ خصوصی گوشی آماده می‌شوند. فضای خالی کافی لازم است. پردازش مدل بزرگ‌تر ممکن است کمی زمان ببرد.',
          style: TextStyle(color: muted, fontSize: 14, height: 1.9),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: ink),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'صدا و متن از گوشی خارج نمی‌شوند.',
                style: TextStyle(fontSize: 14, color: ink),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
