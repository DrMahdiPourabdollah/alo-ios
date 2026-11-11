import 'package:flutter/material.dart';
import '../domain/entry.dart';
import 'theme.dart';

class CalculationCard extends StatelessWidget {
  const CalculationCard({super.key, required this.entry});
  final Entry entry;
  @override
  Widget build(BuildContext context) {
    final total = entry.calculationResult ?? entry.calculatedTotal?.toDouble();
    if (total == null) return const SizedBox.shrink();
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF134B51), Color(0xFF092C3A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF29727A)),
        boxShadow: [
          BoxShadow(
            color: pine.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_rounded, color: Color(0xFF9BE3DA)),
              SizedBox(width: 10),
              Text(
                'نتیجهٔ محاسبه',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              entry.calculationExpression ??
                  '${money(entry.quantity!)} × ${money(entry.unitPrice!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC3DDD9),
                fontSize: 18,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            key: ValueKey(total),
            tween: Tween(begin: reduced ? total : 0, end: total),
            duration: Duration(milliseconds: reduced ? 0 : 650),
            curve: Curves.easeOutCubic,
            builder:
                (context, value, child) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatNumeric(
                      value == total ? total : value.roundToDouble(),
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
          ),
          if (entry.calculationResult == null)
            const Text(
              'تومان · تعداد × قیمت واحد',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFBFDAD5), fontSize: 14),
            ),
        ],
      ),
    );
  }
}
