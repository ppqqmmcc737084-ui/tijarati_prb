import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class RoyalCard extends StatelessWidget {
  final String currency;
  final bool isBalanceHidden;
  final double netBalance;
  final String shopName;

  const RoyalCard({
    Key? key,
    required this.currency,
    required this.isBalanceHidden,
    required this.netBalance,
    required this.shopName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fmt = intl.NumberFormat("#,##0");
    // تحديد الألوان بناءً على العملة
    List<Color> colors = currency.contains("يمني") 
        ? [const Color(0xFFC2185B), const Color(0xFF880E4F)] 
        : (currency.contains("سعودي") 
            ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)] 
            : [const Color(0xFF37474F), const Color(0xFF212121)]);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.586,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Positioned(right: -20, top: -20, child: Icon(Icons.public, size: 120, color: Colors.white.withOpacity(0.05))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        const Icon(Icons.sim_card, color: Colors.amberAccent, size: 30), 
                        Text(currency, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))
                      ]
                    ), 
                    Center(
                      child: Text(
                        isBalanceHidden ? "****" : fmt.format(netBalance), 
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Courier')
                      )
                    ), 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            const Text("CARD HOLDER", style: TextStyle(color: Colors.white54, fontSize: 8)), 
                            Text(shopName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                          ]
                        ), 
                        const Text("PRO", style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900, fontSize: 18))
                      ]
                    )
                  ]
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}