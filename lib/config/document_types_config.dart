import 'package:flutter/material.dart';

class DocumentTypes {
  static final Map<String, Map<String, dynamic>> driverDocuments = {
    'Drivers License': _doc(
      Icons.drive_eta,
      'Valid driving license',
      Colors.orange,
      'personal',
      'driver',
    ),
    'Aadhaar Card': _doc(
      Icons.credit_card,
      'Government identity card',
      Colors.indigo,
      'personal',
      'driver',
    ),
    'PAN Card': _doc(
      Icons.account_balance_wallet,
      'PAN card for tax identification',
      Colors.purple,
      'personal',
      'driver',
    ),
    'Profile Photo': _doc(
      Icons.person,
      'Driver profile photograph',
      Colors.teal,
      'personal',
      'driver',
      isRequired: false,
    ),
  };

  static final Map<String, Map<String, dynamic>> vehicleDocuments = {
    'Vehicle Registration': _doc(
      Icons.directions_car,
      'Vehicle registration certificate',
      Colors.blue,
      'vehicle',
      'truck_owner',
    ),
    'Vehicle Insurance': _doc(
      Icons.security,
      'Vehicle insurance certificate',
      Colors.green,
      'vehicle',
      'truck_owner',
    ),
    'Vehicle Permit': _doc(
      Icons.local_shipping,
      'Commercial vehicle permit',
      Colors.deepOrange,
      'vehicle',
      'truck_owner',
    ),
    'Pollution Certificate': _doc(
      Icons.eco,
      'Pollution under control certificate',
      Colors.lightGreen,
      'vehicle',
      'truck_owner',
    ),
    'Fitness Certificate': _doc(
      Icons.verified,
      'Vehicle fitness certificate',
      Colors.cyan,
      'vehicle',
      'truck_owner',
    ),
  };

  static final Map<String, Map<String, dynamic>> allDocuments = {
    ...driverDocuments,
    ...vehicleDocuments,
  };

  /// Helper factory to avoid repeating structure
  static Map<String, dynamic> _doc(
    IconData icon,
    String description,
    Color color,
    String category,
    String uploadedBy, {
    bool isRequired = true,
  }) => {
    'icon': icon,
    'description': description,
    'color': color,
    'isRequired': isRequired,
    'category': category,
    'uploadedBy': uploadedBy,
  };

  static Map<String, Map<String, dynamic>> getDocumentsByRole(String role) {
    return role.toLowerCase() == 'driver'
        ? driverDocuments
        : role.toLowerCase() == 'truck_owner'
        ? vehicleDocuments
        : allDocuments;
  }

  static Map<String, Map<String, dynamic>> getDocumentsByCategory(
    String category,
  ) {
    return Map.fromEntries(
      allDocuments.entries.where((e) => e.value['category'] == category),
    );
  }

  static List<String> getRequiredTypesByRole(String role) => getDocumentsByRole(
    role,
  ).entries.where((e) => e.value['isRequired']).map((e) => e.key).toList();

  static List<String> getAllTypesByRole(String role) =>
      getDocumentsByRole(role).keys.toList();

  static Map<String, dynamic>? getDocumentInfo(String type) =>
      allDocuments[type];

  static bool canUploadDocument(String type, String userRole) =>
      allDocuments[type]?['uploadedBy'] == userRole;

  static final Map<String, Map<String, dynamic>> requiredDocuments =
      allDocuments;

  static List<String> get requiredTypes => allDocuments.entries
      .where((e) => e.value['isRequired'])
      .map((e) => e.key)
      .toList();

  static List<String> get allTypes => allDocuments.keys.toList();
}
