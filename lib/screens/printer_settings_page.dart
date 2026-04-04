bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            // ✅ الزر الجديد: طباعة فورية
            Expanded(
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _parsedItems.isEmpty ? null : () async {
                    setState(() => _isCapturing = true);
                    try {
                      final imageBytes = await _screenshotController.capture(delay: const Duration(milliseconds: 50));
                      if (imageBytes != null) {
                        BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
                        bool? isConnected = await bluetooth.isConnected;
                        if (isConnected == true) {
                          await bluetooth.printImageBytes(imageBytes); // طباعة الصورة
                          await bluetooth.printNewLine(); // مسافة سفلية
                          await bluetooth.printNewLine();
                          // حفظ الفاتورة بعد الطباعة
                          _saveAndShareInvoice(); 
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الطابعة غير متصلة! اذهب للإعدادات للاتصال"), backgroundColor: Colors.red));
                        }
                      }
                    } catch (e) { print(e); }
                    setState(() => _isCapturing = false);
                  },
                  icon: const Icon(Icons.print),
                  label: const Text("طباعة سريعة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ✅ زر الحفظ والمشاركة العادي
            Expanded(
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D256C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _parsedItems.isEmpty ? null : () {
                    _saveAndShareInvoice();
                  },
                  icon: const Icon(Icons.save_alt),
                  label: const Text("حفظ ومشاركة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),