import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final Box box = Hive.box('tajarti_royal_v1');
  List expenses = [];

  @override
  void initState() {
    super.initState();
    expenses = box.get('expenses', defaultValue: []);
  }

  void _addExpense() {
    TextEditingController note = TextEditingController();
    TextEditingController amt = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("تسجيل منصرف"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: note, decoration: const InputDecoration(labelText: "البيان")),
        TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ")),
      ]),
      actions: [
        ElevatedButton(onPressed: () {
          if (amt.text.isNotEmpty) {
            setState(() {
              expenses.add({'note': note.text, 'amt': double.parse(amt.text), 'date': DateTime.now().toString()});
              box.put('expenses', expenses);
            });
            Navigator.pop(ctx);
          }
        }, child: const Text("حفظ"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    double total = expenses.fold(0, (sum, item) => sum + (item['amt'] as double));
    return Scaffold(
      appBar: AppBar(title: const Text("المصروفات"), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue[50],
            width: double.infinity,
            child: Column(children: [
              const Text("إجمالي المصروفات"),
              Text(intl.NumberFormat("#,##0").format(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFFC62828)))
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (ctx, i) {
                var e = expenses[expenses.length - 1 - i];
                return ListTile(
                  title: Text(e['note'] ?? "بدون بيان"),
                  subtitle: Text(e['date'].toString().substring(0, 16)),
                  trailing: Text(intl.NumberFormat("#,##0").format(e['amt']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addExpense, backgroundColor: const Color(0xFF1565C0), child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}