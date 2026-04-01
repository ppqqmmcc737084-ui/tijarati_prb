import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  String selectedCurrency = 'ريال يمني';
  final List<String> currencies = ['ريال يمني', 'ريال سعودي', 'دولار أمريكي'];
  
  // ✅ 0: الكل، 1: هذا العام، 2: هذا الشهر
  int selectedTimeFilter = 0; 

  // دالة ذكية للتحقق من تاريخ العملية هل هو ضمن الفلتر المختار؟
  bool _isDateInFilter(String? dateStr) {
    if (selectedTimeFilter == 0) return true; // الكل
    if (dateStr == null || dateStr.isEmpty) return false;

    try {
      DateTime now = DateTime.now();
      String currentYear = now.year.toString();
      String currentMonth = now.month.toString().padLeft(2, '0');

      if (selectedTimeFilter == 1) {
        return dateStr.contains(currentYear); // هذا العام
      } else if (selectedTimeFilter == 2) {
        // هذا الشهر (يحتوي على السنة والشهر معاً)
        return dateStr.contains(currentYear) && (dateStr.contains('-$currentMonth-') || dateStr.contains('/$currentMonth/') || dateStr.contains(currentMonth));
      }
    } catch (e) {
      return true; // إذا كان التاريخ غير معروف اعرضه للضمان
    }
    return true;
  }

  // دالة لجلب الإحصائيات حسب العملة والزمن
  Map<String, double> _calculateStats() {
    double totalDebts = 0; 
    double totalCollected = 0; 
    
    for (var key in box.keys) {
      if (!['user_uid', 'device_id', 'shop_name', 'app_password', 'is_password_enabled', 'is_fingerprint_enabled'].contains(key)) {
        var data = box.get(key);
        if (data is Map && (data['currency'] ?? 'ريال يمني') == selectedCurrency) {
          if (data['trans'] != null) {
            for (var t in data['trans']) {
              // ✅ التحقق من فلتر الزمن قبل حساب العملية
              if (!_isDateInFilter(t['date'])) continue;

              double amt = double.tryParse(t['amt'].toString()) ?? 0;
              if (t['type'] == 'out') {
                totalDebts += amt; // دين جديد (خارج)
              } else {
                totalCollected += amt; // سداد (داخل)
              }
            }
          }
        }
      }
    }
    return {'debts': totalDebts, 'collected': totalCollected};
  }

  @override
  Widget build(BuildContext context) {
    var stats = _calculateStats();
    double debts = stats['debts'] ?? 0;
    double collected = stats['collected'] ?? 0;
    double netBalance = debts - collected; // الصافي المتبقي في السوق

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('الجرود والتقارير', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D256C),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. شريط اختيار العملة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCurrency,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0D256C)),
                  items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) => setState(() => selectedCurrency = val!),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 2. شريط فلترة الزمن الفخم (Toggle Buttons)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  Expanded(child: _buildTimeButton("الكل", 0)),
                  Expanded(child: _buildTimeButton("هذا العام", 1)),
                  Expanded(child: _buildTimeButton("هذا الشهر", 2)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. بطاقات الإحصائيات السريعة
            Row(
              children: [
                Expanded(child: _buildStatCard('إجمالي الديون (خارج)', debts, const Color(0xFFD81B60), Icons.arrow_upward)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCard('إجمالي التحصيل (داخل)', collected, Colors.green, Icons.arrow_downward)),
              ],
            ),
            const SizedBox(height: 15),
            
            // 4. بطاقة الصافي
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D256C), Color(0xFF1565C0)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  const Text('الديون المتبقية في السوق', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text('${intl.NumberFormat("#,##0").format(netBalance)} $selectedCurrency', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 5. الرسم البياني (Bar Chart)
            const Text('المؤشر المالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D256C))),
            const SizedBox(height: 15),
            Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
              child: debts == 0 && collected == 0 
                ? const Center(child: Text('لا توجد عمليات في هذه الفترة', style: TextStyle(color: Colors.grey)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (debts > collected ? debts : collected) * 1.2, // أعلى نقطة في الرسم
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0: return const Text('الديون', style: TextStyle(color: Color(0xFFD81B60), fontWeight: FontWeight.bold));
                            case 1: return const Text('التحصيل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                            default: return const Text('');
                          }
                        })) ,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // إخفاء الأرقام الجانبية للترتيب
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: debts, color: const Color(0xFFD81B60), width: 40, borderRadius: BorderRadius.circular(8))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: collected, color: Colors.green, width: 40, borderRadius: BorderRadius.circular(8))]),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // تصميم أزرار الفلترة الزمنية
  Widget _buildTimeButton(String title, int index) {
    bool isSelected = selectedTimeFilter == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTimeFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D256C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // تصميم كروت الإحصائيات
  Widget _buildStatCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(intl.NumberFormat.compact().format(amount), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}