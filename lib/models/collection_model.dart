import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionData {
  final String id;
  final String clientName;
  final String clientPhone;
  final double amount;
  final String paymentMethod;
  final String receiptNumber;
  final String invoiceNumber;
  final String date;
  final String? notes;
  final bool isCollected;
  final String lastModified;
  final List<Map<String, dynamic>>?
  modificationHistory; // حقل جديد لسجل التعديلات

  CollectionData({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.amount,
    required this.paymentMethod,
    required this.receiptNumber,
    required this.invoiceNumber,
    required this.date,
    this.notes,
    required this.isCollected,
    required this.lastModified,
    this.modificationHistory,
  });

  factory CollectionData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CollectionData(
      id: doc.id,
      clientName: data['clientName'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? '',
      receiptNumber: data['receiptNumber'] ?? '',
      invoiceNumber: data['invoiceNumber'] ?? '',
      date: data['date'] ?? '',
      notes: data['notes'],
      isCollected: data['isCollected'] ?? false,
      lastModified: data['lastModified'] ?? '',
      modificationHistory:
          data['modificationHistory'] != null
              ? List<Map<String, dynamic>>.from(data['modificationHistory'])
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientName': clientName,
      'clientPhone': clientPhone,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'receiptNumber': receiptNumber,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'notes': notes,
      'isCollected': isCollected,
      'lastModified': lastModified,
      'modificationHistory': modificationHistory,
    };
  }
}

class CollectionProvider with ChangeNotifier {
  final CollectionReference _collections = FirebaseFirestore.instance
      .collection('collections');
  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Stream<List<CollectionData>> getCollections() {
    return _collections
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CollectionData.fromFirestore(doc))
                  .where(
                    (data) => data.clientName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList(),
        );
  }

  Future<void> addCollection(CollectionData data) async {
    await _collections.add(data.toFirestore());
    notifyListeners();
  }

  Future<void> updateCollection(String docId, CollectionData data) async {
    await _collections.doc(docId).update(data.toFirestore());
    notifyListeners();
  }

  Future<void> deleteCollection(String docId) async {
    await _collections.doc(docId).delete();
    notifyListeners();
  }
}
