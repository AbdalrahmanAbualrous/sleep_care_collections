import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/collection_model.dart';

class EditPage extends StatefulWidget {
  final CollectionData collection;

  const EditPage({super.key, required this.collection});

  @override
  _EditPageState createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController _clientNameController;
  late TextEditingController _clientPhoneController;
  late TextEditingController _amountController;
  late TextEditingController _receiptNumberController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _notesController;
  late String _paymentMethod;
  late bool _isCollected;

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.email == 'admin@sleepcare.com';

  @override
  void initState() {
    super.initState();
    _clientNameController = TextEditingController(
      text: widget.collection.clientPhone,
    );
    _clientPhoneController = TextEditingController(
      text: widget.collection.clientPhone,
    );
    _amountController = TextEditingController(
      text: widget.collection.amount.toString(),
    );
    _receiptNumberController = TextEditingController(
      text: widget.collection.receiptNumber,
    );
    _invoiceNumberController = TextEditingController(
      text: widget.collection.invoiceNumber,
    );
    _notesController = TextEditingController(text: widget.collection.notes);
    _paymentMethod = widget.collection.paymentMethod;
    _isCollected = widget.collection.isCollected;
  }

  @override
  void dispose() {
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
    final provider = Provider.of<CollectionProvider>(context, listen: false);

    Future<void> _saveChanges() async {
      // التحقق من الحقول الإلزامية
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

      // التحقق من تنسيق رقم الهاتف
      final phone = _clientPhoneController.text.trim();
      if (!((phone.startsWith('+962') && phone.length == 12) ||
          (phone.startsWith('07') && phone.length == 10))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'رقم الهاتف يجب أن يكون بصيغة +962 و12 رقم أو يبدأ بـ 07 و10 أرقام',
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

      // التحقق من تكرار رقم السند (مع استثناء السند الحالي)
      if (_receiptNumberController.text != widget.collection.receiptNumber) {
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
      }

      // لو المستخدم عادي وحاول يعدل أي حقل غير الحالة، امنعه
      if (!_isAdmin &&
          (_clientNameController.text != widget.collection.clientName ||
              _clientPhoneController.text != widget.collection.clientPhone ||
              _amountController.text != widget.collection.amount.toString() ||
              _receiptNumberController.text !=
                  widget.collection.receiptNumber ||
              _invoiceNumberController.text !=
                  widget.collection.invoiceNumber ||
              _paymentMethod != widget.collection.paymentMethod ||
              _notesController.text != (widget.collection.notes ?? ''))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('غير مسموح لكِ بتعديل هذه الحقول')),
        );
        return;
      }

      // التحقق من عدد التعديلات على الحالة من "غير محصل" إلى "محصل" للمستخدم العادي
      bool canChangeStatus = _isAdmin;
      if (!_isAdmin && !widget.collection.isCollected && _isCollected) {
        final statusChanges =
            widget.collection.modificationHistory
                ?.where(
                  (entry) =>
                      entry['action'] == 'تعديل الحالة' &&
                      entry['newStatus'] == 'محصل',
                )
                .length ??
            0;
        canChangeStatus = statusChanges < 1;
      } else if (!_isAdmin && widget.collection.isCollected) {
        canChangeStatus = false;
      }

      if (!canChangeStatus && widget.collection.isCollected != _isCollected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'غير مسموح لكِ بتغيير حالة التحصيل أكثر من مرة أو إرجاعها',
            ),
          ),
        );
        return;
      }

      // تحذير نهائي للمستخدم العادي لما يغير من "غير محصل" إلى "محصل"
      if (!_isAdmin && !widget.collection.isCollected && _isCollected) {
        bool? confirmFinal = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('تحذير'),
                content: const Text(
                  'هذا التغيير نهائي، هل أنتِ متأكدة أنه تم التحصيل؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('لا'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('نعم'),
                  ),
                ],
              ),
        );
        if (confirmFinal != true) return;
      }

      // تأكيد عام لتغيير الحالة (للجميع)
      if (widget.collection.isCollected != _isCollected) {
        bool? confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('تأكيد'),
                content: Text(
                  'هل أنتِ متأكدة من تغيير حالة التحصيل من "${widget.collection.isCollected ? 'تم' : 'لم يتم'}" إلى "${_isCollected ? 'تم' : 'لم يتم'}"؟',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('لا'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('نعم'),
                  ),
                ],
              ),
        );
        if (confirm != true) return;
      }

      // إنشاء السجل الجديد للتعديل
      final now = DateTime.now().toString();
      final updatedCollection = CollectionData(
        id: widget.collection.id,
        clientName: _clientNameController.text,
        clientPhone: _clientPhoneController.text,
        amount: double.parse(_amountController.text),
        paymentMethod: _paymentMethod,
        receiptNumber: _receiptNumberController.text,
        invoiceNumber: _invoiceNumberController.text,
        date: widget.collection.date,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isCollected: _isCollected,
        lastModified: now,
        modificationHistory: [
          ...(widget.collection.modificationHistory ?? []),
          if (widget.collection.isCollected != _isCollected)
            {
              'action': 'تعديل الحالة',
              'newStatus': _isCollected ? 'محصل' : 'غير محصل',
              'timestamp': now,
              'user': FirebaseAuth.instance.currentUser?.email ?? 'غير معروف',
            }
          else
            {
              'action': 'تعديل',
              'timestamp': now,
              'user': FirebaseAuth.instance.currentUser?.email ?? 'غير معروف',
            },
        ],
      );

      await provider.updateCollection(widget.collection.id, updatedCollection);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعديل التحصيل بنجاح')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل التحصيل'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _clientNameController,
                enabled: _isAdmin,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _clientPhoneController,
                enabled: _isAdmin,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountController,
                enabled: _isAdmin,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (دينار)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _receiptNumberController,
                enabled: _isAdmin,
                decoration: const InputDecoration(
                  labelText: 'رقم السند',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _invoiceNumberController,
                enabled: _isAdmin,
                decoration: const InputDecoration(
                  labelText: 'رقم الفاتورة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items:
                    ['نقدي', 'كليك', 'زين كاش']
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                onChanged:
                    _isAdmin
                        ? (value) => setState(() => _paymentMethod = value!)
                        : null,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                enabled: _isAdmin,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تم التحصيل؟', style: TextStyle(fontSize: 16)),
                  Switch(
                    value: _isCollected,
                    onChanged: (value) {
                      bool canChange = _isAdmin;
                      if (!_isAdmin &&
                          !widget.collection.isCollected &&
                          value) {
                        final statusChanges =
                            widget.collection.modificationHistory
                                ?.where(
                                  (entry) =>
                                      entry['action'] == 'تعديل الحالة' &&
                                      entry['newStatus'] == 'محصل',
                                )
                                .length ??
                            0;
                        canChange = statusChanges < 1;
                      } else if (!_isAdmin && widget.collection.isCollected) {
                        canChange = false;
                      }

                      if (canChange) {
                        setState(() => _isCollected = value);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'غير مسموح لكِ بتغيير حالة التحصيل أكثر من مرة أو إرجاعها',
                            ),
                          ),
                        );
                      }
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'حفظ التعديل',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
