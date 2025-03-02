import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/collection_model.dart';
import 'edit_page.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  _CollectionsPageState createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage>
    with SingleTickerProviderStateMixin {
  String _sortOption = 'date';
  int _filterOption = 0;
  final TextEditingController _searchController = TextEditingController();
  String? _paymentFilter;
  DateTime? _dateFilter;

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.email == 'admin@sleepcare.com';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade700, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildFilterBar(context),
                    const SizedBox(height: 16),
                    _buildCollectionsList(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.blueAccent,
      title: const Text(
        'قوائم التحصيل',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Consumer<CollectionProvider>(
            builder: (context, provider, child) {
              return StreamBuilder<List<CollectionData>>(
                stream: provider.getCollections(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final totalCollected = snapshot.data!
                      .where((d) => d.isCollected)
                      .fold(0.0, (sum, d) => sum + d.amount);
                  final totalNotCollected = snapshot.data!
                      .where((d) => !d.isCollected)
                      .fold(0.0, (sum, d) => sum + d.amount);
                  return Column(
                    children: [
                      Text(
                        'إجمالي المحصل: $totalCollected دينار',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'إجمالي غير المحصل: $totalNotCollected دينار',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) => setState(() => _sortOption = value),
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'date',
                  child: Text('ترتيب حسب التاريخ'),
                ),
                const PopupMenuItem(
                  value: 'amount',
                  child: Text('ترتيب حسب المبلغ'),
                ),
                const PopupMenuItem(
                  value: 'clientName',
                  child: Text('ترتيب حسب اسم العميل'),
                ),
              ],
          icon: const Icon(Icons.sort, color: Colors.white),
        ),
        if (_isAdmin)
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _exportToCsv(context),
          ),
        IconButton(
          // زر تغيير كلمة المرور متاح للجميع
          icon: const Icon(Icons.security, color: Colors.white),
          onPressed: () => _showChangePasswordDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushReplacementNamed('/login');
          },
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        String? errorMessage;
        final TextEditingController oldPasswordController =
            TextEditingController();
        final TextEditingController newPasswordController =
            TextEditingController();
        final TextEditingController confirmPasswordController =
            TextEditingController();

        return StatefulBuilder(
          builder:
              (dialogContext, setState) => AlertDialog(
                title: const Text('تغيير كلمة المرور'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: oldPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور القديمة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور الجديدة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isLoading ? null : () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              final oldPassword =
                                  oldPasswordController.text.trim();
                              final newPassword =
                                  newPasswordController.text.trim();
                              final confirmPassword =
                                  confirmPasswordController.text.trim();

                              if (oldPassword.isEmpty ||
                                  newPassword.isEmpty ||
                                  confirmPassword.isEmpty) {
                                setState(
                                  () => errorMessage = 'يرجى ملء جميع الحقول',
                                );
                                return;
                              }

                              if (newPassword != confirmPassword) {
                                setState(
                                  () =>
                                      errorMessage =
                                          'كلمتا المرور الجديدة غير متطابقتين',
                                );
                                return;
                              }

                              if (newPassword.length < 6) {
                                setState(
                                  () =>
                                      errorMessage =
                                          'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
                                );
                                return;
                              }

                              setState(() => isLoading = true);

                              try {
                                final user = FirebaseAuth.instance.currentUser!;
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: oldPassword,
                                );
                                await user.reauthenticateWithCredential(
                                  credential,
                                );
                                await user.updatePassword(newPassword);
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تغيير كلمة المرور بنجاح'),
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                setState(() {
                                  errorMessage = _getErrorMessage(e.code);
                                });
                              } finally {
                                setState(() => isLoading = false);
                              }
                            },
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('حفظ'),
                  ),
                ],
              ),
        );
      },
    );
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'كلمة المرور القديمة غير صحيحة';
      case 'too-many-requests':
        return 'تم حظر المحاولات مؤقتًا، حاولي لاحقًا';
      default:
        return 'حدث خطأ، حاولي مرة أخرى';
    }
  }

  Future<void> _exportToCsv(BuildContext context) async {
    final provider = Provider.of<CollectionProvider>(context, listen: false);
    final snapshot = await provider.getCollections().first;
    var collections =
        snapshot
            .where(
              (data) =>
                  _filterOption == 0 ||
                  (_filterOption == 1 && data.isCollected) ||
                  (_filterOption == 2 && !data.isCollected),
            )
            .toList();

    if (_paymentFilter != null)
      collections =
          collections
              .where((data) => data.paymentMethod == _paymentFilter)
              .toList();
    if (_dateFilter != null) {
      collections =
          collections.where((data) {
            final date = DateTime.parse(data.date.substring(0, 10));
            return date.day == _dateFilter!.day &&
                date.month == _dateFilter!.month &&
                date.year == _dateFilter!.year;
          }).toList();
    }

    List<List<dynamic>> rows = [
      [
        'اسم العميل',
        'رقم الهاتف',
        'المبلغ',
        'رقم السند',
        'رقم الفاتورة',
        'طريقة الدفع',
        'التاريخ',
        'ملاحظات',
        'الحالة',
        'آخر تعديل',
      ],
    ];
    for (var data in collections) {
      rows.add([
        data.clientName,
        data.clientPhone,
        data.amount,
        data.receiptNumber,
        data.invoiceNumber,
        data.paymentMethod,
        data.date.substring(0, 10),
        data.notes ?? 'لا يوجد',
        data.isCollected ? 'تم التحصيل' : 'لم يتم التحصيل',
        data.lastModified.substring(0, 10),
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getExternalStorageDirectory();
    final path =
        '${directory!.path}/collections_${DateTime.now().toIso8601String()}.csv';
    final file = File(path);
    await file.writeAsString(csv);

    if (await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم تصدير البيانات إلى $path')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل التصدير: تحتاجين إذن التخزين')),
      );
    }
  }

  Widget _buildFilterBar(BuildContext context) {
    return Column(
      children: [
        ToggleButtons(
          isSelected: [
            _filterOption == 0,
            _filterOption == 1,
            _filterOption == 2,
          ],
          onPressed: (index) => setState(() => _filterOption = index),
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: Colors.blueAccent,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('الكل'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('محصل'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('غير محصل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Consumer<CollectionProvider>(
          builder: (context, provider, child) {
            return TextField(
              controller: _searchController,
              textDirection: _getTextDirection(_searchController.text),
              decoration: InputDecoration(
                labelText: 'ابحث في الاسم، رقم الهاتف، السند أو الفاتورة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color.fromRGBO(255, 255, 255, 0.9),
              ),
              onChanged: (value) {
                setState(() {});
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _paymentFilter,
                hint: const Text('طريقة الدفع'),
                items:
                    [null, 'نقدي', 'زين كاش', 'كليك']
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method ?? 'الكل'),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _paymentFilter = value),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color.fromRGBO(255, 255, 255, 0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                setState(() => _dateFilter = pickedDate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              child: Text(
                _dateFilter != null
                    ? '${_dateFilter!.day}/${_dateFilter!.month}/${_dateFilter!.year}'
                    : 'اختر تاريخ',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextDirection _getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.rtl;
    final firstChar = text[0];
    return (firstChar.codeUnitAt(0) >= 0x0600 &&
            firstChar.codeUnitAt(0) <= 0x06FF)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  Widget _buildCollectionsList(BuildContext context) {
    return Consumer<CollectionProvider>(
      builder: (context, provider, child) {
        return StreamBuilder<List<CollectionData>>(
          stream: provider.getCollections(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var collections =
                snapshot.data!
                    .where(
                      (data) =>
                          _filterOption == 0 ||
                          (_filterOption == 1 && data.isCollected) ||
                          (_filterOption == 2 && !data.isCollected),
                    )
                    .toList();

            if (_paymentFilter != null)
              collections =
                  collections
                      .where((data) => data.paymentMethod == _paymentFilter)
                      .toList();
            if (_dateFilter != null) {
              collections =
                  collections.where((data) {
                    final date = DateTime.parse(data.date.substring(0, 10));
                    return date.day == _dateFilter!.day &&
                        date.month == _dateFilter!.month &&
                        date.year == _dateFilter!.year;
                  }).toList();
            }

            final searchQuery = _searchController.text.trim().toLowerCase();
            if (searchQuery.isNotEmpty) {
              collections =
                  collections.where((data) {
                    return data.clientName.toLowerCase().contains(
                          searchQuery,
                        ) ||
                        data.clientPhone.toLowerCase().contains(searchQuery) ||
                        data.receiptNumber.toLowerCase().contains(
                          searchQuery,
                        ) ||
                        data.invoiceNumber.toLowerCase().contains(searchQuery);
                  }).toList();
            }

            collections.sort((a, b) {
              switch (_sortOption) {
                case 'amount':
                  return b.amount.compareTo(a.amount);
                case 'clientName':
                  return a.clientName.compareTo(b.clientName);
                case 'date':
                default:
                  return b.date.compareTo(a.date);
              }
            });

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final data = collections[index];
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: () => _showDetailsDialog(context, data),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors:
                                data.isCollected
                                    ? [
                                      const Color.fromRGBO(0, 255, 0, 0.2),
                                      const Color.fromRGBO(0, 255, 0, 0.1),
                                    ]
                                    : [
                                      const Color.fromRGBO(255, 0, 0, 0.2),
                                      const Color.fromRGBO(255, 0, 0, 0.1),
                                    ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromRGBO(0, 0, 0, 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        color: Colors.blueAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        data.clientName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed:
                                            () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => EditPage(
                                                      collection: data,
                                                    ),
                                              ),
                                            ),
                                      ),
                                      if (_isAdmin)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => provider.deleteCollection(
                                                data.id,
                                              ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.money,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'المبلغ: ${data.amount} دينار',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.receipt,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'رقم السند: ${data.receiptNumber}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.description,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'رقم الفاتورة: ${data.invoiceNumber}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'التاريخ: ${data.date.substring(0, 10)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data.isCollected
                                        ? 'تم التحصيل'
                                        : 'لم يتم التحصيل',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          data.isCollected
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, CollectionData data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تفاصيل التحصيل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'اسم العميل: ${data.clientName}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text('رقم الهاتف: ${data.clientPhone}'),
                  Text('المبلغ: ${data.amount} دينار'),
                  Text('رقم السند: ${data.receiptNumber}'),
                  Text('رقم الفاتورة: ${data.invoiceNumber}'),
                  Text('طريقة الدفع: ${data.paymentMethod}'),
                  Text('التاريخ: ${data.date.substring(0, 10)}'),
                  Text('ملاحظات: ${data.notes ?? 'لا يوجد'}'),
                  Text(
                    'الحالة: ${data.isCollected ? 'تم التحصيل' : 'لم يتم'}',
                    style: TextStyle(
                      color: data.isCollected ? Colors.green : Colors.red,
                    ),
                  ),
                  Text('آخر تعديل: ${data.lastModified.substring(0, 10)}'),
                  if (_isAdmin && data.modificationHistory != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'سجل التعديلات:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...data.modificationHistory!.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${entry['action']} بواسطة ${entry['user']} في ${entry['timestamp'].substring(0, 19)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
    );
  }
}
