import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_model.dart';
import 'collections_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _clientNameController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'نقدي';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _amountController.dispose();
    _receiptNumberController.dispose();
    _invoiceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدخال تحصيل جديد',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'محصل'), Tab(text: 'غير محصل')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollectionsPage()),
                ),
            tooltip: 'عرض القوائم',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade700, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildInputForm(context, true),
            _buildInputForm(context, false),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm(BuildContext context, bool isCollected) {
    final provider = Provider.of<CollectionProvider>(context, listen: false);

    void _clearFields() {
      _clientNameController.clear();
      _clientPhoneController.clear();
      _amountController.clear();
      _receiptNumberController.clear();
      _invoiceNumberController.clear();
      _notesController.clear();
      setState(() {
        _paymentMethod = 'نقدي';
      });
    }

    Future<void> _saveCollection() async {
      if (_clientNameController.text.isEmpty ||
          _clientPhoneController.text.isEmpty ||
          _amountController.text.isEmpty ||
          _receiptNumberController.text.isEmpty ||
          _invoiceNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى ملء جميع الحقول الإلزامية')),
        );
        return;
      }

      if (!(_clientPhoneController.text.startsWith("+962") &&
              _clientPhoneController.text.length == 13) &&
          !(_clientPhoneController.text.startsWith("07") &&
              _clientPhoneController.text.length == 10)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'رقم الهاتف يجب أن يكون بصيغة +962XXXXXXXXX أو 07XXXXXXXX',
            ),
          ),
        );
        return;
      }

      if (double.tryParse(_amountController.text) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المبلغ يجب أن يكون رقمًا صحيحًا')),
        );
        return;
      }

      final receiptExists =
          await FirebaseFirestore.instance
              .collection('collections')
              .where(
                'receiptNumber',
                isEqualTo: _receiptNumberController.text.trim(),
              )
              .get();

      if (receiptExists.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم السند موجود مسبقًا، يرجى اختيار رقم آخر'),
          ),
        );
        return;
      }

      final now = DateTime.now().toString();
      final collection = CollectionData(
        id: '',
        clientName: _clientNameController.text,
        clientPhone: _clientPhoneController.text,
        amount: double.parse(_amountController.text),
        paymentMethod: _paymentMethod,
        receiptNumber: _receiptNumberController.text,
        invoiceNumber: _invoiceNumberController.text,
        date: now,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isCollected: isCollected,
        lastModified: now,
        modificationHistory: [
          {
            'action': 'إنشاء',
            'timestamp': now,
            'user': FirebaseAuth.instance.currentUser?.email ?? 'غير معروف',
          },
        ],
      );

      await provider.addCollection(collection);
      _clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ التحصيل ${isCollected ? 'المحصل' : 'غير المحصل'} بنجاح',
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTextField(_clientNameController, 'اسم العميل', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(
              _clientPhoneController,
              'رقم الهاتف',
              Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _amountController,
              'المبلغ (دينار)',
              Icons.money,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _receiptNumberController,
              'رقم السند',
              Icons.receipt,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _invoiceNumberController,
              'رقم الفاتورة',
              Icons.description,
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder:
                  (context, setState) => DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    items:
                        ['نقدي', 'زين كاش', 'كليك']
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => _paymentMethod = value!),
                    decoration: InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.payment),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            _buildTextField(_notesController, 'ملاحظات (اختياري)', Icons.note),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveCollection,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCollected ? Colors.green : Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(
                'حفظ التحصيل ${isCollected ? 'المحصل' : 'غير المحصل'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
