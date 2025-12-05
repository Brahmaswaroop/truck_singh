import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import 'models/bilty_model.dart';
import 'preview_page.dart';

class TransportBiltyPreview extends StatefulWidget {
  final String biltyNo;
  final String shipmentId;
  final String senderName;
  final String senderAddress;
  final String senderGSTIN;
  final String senderPhone;
  final String recipientName;
  final String recipientAddress;
  final String recipientGSTIN;
  final String recipientPhone;
  final String truckOwnerName;
  final String driverName;
  final String chassisNo;
  final String engineNo;
  final String truckNo;
  final String fromWhere;
  final String tillWhere;
  final DateTime? biltyDate;
  final DateTime? pickupDate;
  final List<GoodsItem> goods;
  final String basicFare;
  final String otherCharges;
  final String gst;
  final String totalAmount;
  final String paymentStatus;
  final Map<String, bool> extraCharges;
  final String bankName;
  final String accountName;
  final String accountNo;
  final String ifscCode;
  final String remarks;
  final String? driverLicense;
  final String? driverPhone;
  final String? vehicleType;
  final String? transporterName;
  final String? transporterGSTIN;
  final DateTime? deliveryDate;
  // Additional optional details
  final String? biltyType;
  final String? transporterCode;
  final String? branchCode;
  final String? senderEmail;
  final String? senderPAN;
  final String? recipientEmail;
  final String? recipientPAN;
  final String? truckOwnerPhone;
  final String? driverAddress;
  final String? senderSignature;
  final String? driverSignature;
  final String? clerkSignature;
  final String? companyName;
  final String? companyAddress;
  final String? companyCity;
  final String? companyState;
  final String? companyPincode;
  final bool generatePdf;

  const TransportBiltyPreview({
    Key? key,
    required this.biltyNo,
    required this.shipmentId,
    required this.senderName,
    required this.senderAddress,
    required this.senderGSTIN,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientAddress,
    required this.recipientGSTIN,
    required this.recipientPhone,
    required this.truckOwnerName,
    required this.driverName,
    required this.chassisNo,
    required this.engineNo,
    required this.truckNo,
    required this.fromWhere,
    required this.tillWhere,
    required this.biltyDate,
    required this.pickupDate,
    required this.goods,
    required this.basicFare,
    required this.otherCharges,
    required this.gst,
    required this.totalAmount,
    required this.paymentStatus,
    required this.extraCharges,
    required this.bankName,
    required this.accountName,
    required this.accountNo,
    required this.ifscCode,
    required this.remarks,
    this.driverLicense,
    this.driverPhone,
    this.vehicleType,
    this.transporterName,
    this.transporterGSTIN,
    this.deliveryDate,
    this.biltyType,
    this.transporterCode,
    this.branchCode,
    this.senderEmail,
    this.senderPAN,
    this.recipientEmail,
    this.recipientPAN,
    this.truckOwnerPhone,
    this.driverAddress,
    this.senderSignature,
    this.driverSignature,
    this.clerkSignature,
    this.companyName,
    this.companyAddress,
    this.companyCity,
    this.companyState,
    this.companyPincode,
    this.generatePdf = false,
  }) : super(key: key);

  @override
  State<TransportBiltyPreview> createState() => _TransportBiltyPreviewState();
}

class _TransportBiltyPreviewState extends State<TransportBiltyPreview> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Bilty Preview'),
        backgroundColor: AppColors.tealBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () => _generateAndShowPDF(),
            tooltip: 'Print/Share PDF',
          ),
          // New Upload Button
          if (!_isUploading)
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _uploadAndSaveBilty,
              tooltip: 'Upload and Save Bilty',
            )
          else
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  //color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  Divider(height: 32, thickness: 1),

                  // Basic Information
                  _buildBasicInfo(),
                  SizedBox(height: 16),

                  // Parties Information
                  _buildPartiesInfo(),
                  SizedBox(height: 16),

                  // Vehicle & Driver Information
                  _buildVehicleDriverInfo(),
                  SizedBox(height: 16),

                  // Route Information
                  _buildRouteInfo(),
                  SizedBox(height: 16),

                  // Goods Table
                  _buildGoodsTable(),
                  SizedBox(height: 16),

                  // Charges Information
                  _buildChargesInfo(),
                  SizedBox(height: 16),

                  // Extra Charges
                  _buildExtraCharges(),
                  SizedBox(height: 16),

                  // Bank Details
                  _buildBankDetails(),
                  SizedBox(height: 16),

                  // Terms and Conditions
                  _buildTermsAndConditions(),
                  SizedBox(height: 20),

                  // Signatures
                  _buildSignatures(),
                  SizedBox(height: 20),

                  // Remarks
                  if (widget.remarks.isNotEmpty) _buildRemarks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Building Widgets (No changes below this line) ---

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo and Company Name Row
        Row(
          children: [
            Image.asset(
              'assets/truck.png',
              height: 60,
              width: 60,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.companyName ?? '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // Address
        if (widget.companyAddress != null && widget.companyAddress!.isNotEmpty)
          Text(
            widget.companyAddress!,
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        if (widget.companyCity != null && widget.companyCity!.isNotEmpty)
          Text(
            widget.companyCity!,
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        SizedBox(height: 12),
        // Document Type Label
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.tealBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Original - Consignor Copy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Responsive layout - stack on mobile, row on larger screens
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      _InfoRow(label: 'Bilty No.', value: widget.biltyNo),
                      if (widget.biltyType != null &&
                          widget.biltyType!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        _InfoRow(label: 'Bilty Type', value: widget.biltyType!),
                      ],
                      SizedBox(height: 8),
                      _InfoRow(
                        label: 'Bilty Date',
                        value: widget.biltyDate != null
                            ? '${widget.biltyDate!.day.toString().padLeft(2, '0')}/${widget.biltyDate!.month.toString().padLeft(2, '0')}/${widget.biltyDate!.year}'
                            : '',
                      ),
                      if (widget.transporterCode != null &&
                          widget.transporterCode!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        _InfoRow(
                          label: 'Transporter Code',
                          value: widget.transporterCode!,
                        ),
                      ],
                      if (widget.branchCode != null &&
                          widget.branchCode!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        _InfoRow(
                          label: 'Branch Code',
                          value: widget.branchCode!,
                        ),
                      ],
                      if (widget.transporterName != null &&
                          widget.transporterName!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        _InfoRow(
                          label: 'Transporter Name',
                          value: widget.transporterName!,
                        ),
                      ],
                      if (widget.transporterGSTIN != null &&
                          widget.transporterGSTIN!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        _InfoRow(
                          label: 'Transporter GSTIN',
                          value: widget.transporterGSTIN!,
                        ),
                      ],
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'Bilty No.',
                              value: widget.biltyNo,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'Bilty Date',
                              value: widget.biltyDate != null
                                  ? '${widget.biltyDate!.day.toString().padLeft(2, '0')}/${widget.biltyDate!.month.toString().padLeft(2, '0')}/${widget.biltyDate!.year}'
                                  : '',
                            ),
                          ),
                        ],
                      ),
                      if (widget.biltyType != null &&
                          widget.biltyType!.isNotEmpty)
                        _InfoRow(label: 'Bilty Type', value: widget.biltyType!),
                      if (widget.transporterCode != null &&
                          widget.transporterCode!.isNotEmpty)
                        _InfoRow(
                          label: 'Transporter Code',
                          value: widget.transporterCode!,
                        ),
                      if (widget.branchCode != null &&
                          widget.branchCode!.isNotEmpty)
                        _InfoRow(
                          label: 'Branch Code',
                          value: widget.branchCode!,
                        ),
                      if (widget.transporterName != null &&
                          widget.transporterName!.isNotEmpty)
                        _InfoRow(
                          label: 'Transporter Name',
                          value: widget.transporterName!,
                        ),
                      if (widget.transporterGSTIN != null &&
                          widget.transporterGSTIN!.isNotEmpty)
                        _InfoRow(
                          label: 'Transporter GSTIN',
                          value: widget.transporterGSTIN!,
                        ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartiesInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parties Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      // Sender Details
                      Text(
                        'Sender Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Name', value: widget.senderName),
                      _InfoRow(label: 'Address', value: widget.senderAddress),
                      if (widget.senderEmail != null &&
                          widget.senderEmail!.isNotEmpty)
                        _InfoRow(label: 'Email', value: widget.senderEmail!),
                      if (widget.senderPAN != null &&
                          widget.senderPAN!.isNotEmpty)
                        _InfoRow(label: 'PAN', value: widget.senderPAN!),
                      if (widget.senderGSTIN.isNotEmpty)
                        _InfoRow(label: 'GSTIN', value: widget.senderGSTIN),
                      if (widget.senderPhone.isNotEmpty)
                        _InfoRow(label: 'Phone', value: widget.senderPhone),

                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),

                      // Recipient Details
                      Text(
                        'Recipient Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Name', value: widget.recipientName),
                      _InfoRow(
                        label: 'Address',
                        value: widget.recipientAddress,
                      ),
                      if (widget.recipientEmail != null &&
                          widget.recipientEmail!.isNotEmpty)
                        _InfoRow(label: 'Email', value: widget.recipientEmail!),
                      if (widget.recipientPAN != null &&
                          widget.recipientPAN!.isNotEmpty)
                        _InfoRow(label: 'PAN', value: widget.recipientPAN!),
                      if (widget.recipientGSTIN.isNotEmpty)
                        _InfoRow(label: 'GSTIN', value: widget.recipientGSTIN),
                      if (widget.recipientPhone.isNotEmpty)
                        _InfoRow(label: 'Phone', value: widget.recipientPhone),
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sender Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            _InfoRow(label: 'Name', value: widget.senderName),
                            _InfoRow(
                              label: 'Address',
                              value: widget.senderAddress,
                            ),
                            if (widget.senderGSTIN.isNotEmpty)
                              _InfoRow(
                                label: 'GSTIN',
                                value: widget.senderGSTIN,
                              ),
                            if (widget.senderPhone.isNotEmpty)
                              _InfoRow(
                                label: 'Phone',
                                value: widget.senderPhone,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recipient Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            _InfoRow(
                              label: 'Name',
                              value: widget.recipientName,
                            ),
                            _InfoRow(
                              label: 'Address',
                              value: widget.recipientAddress,
                            ),
                            if (widget.recipientGSTIN.isNotEmpty)
                              _InfoRow(
                                label: 'GSTIN',
                                value: widget.recipientGSTIN,
                              ),
                            if (widget.recipientPhone.isNotEmpty)
                              _InfoRow(
                                label: 'Phone',
                                value: widget.recipientPhone,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDriverInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle & Driver Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      // Vehicle Details
                      Text(
                        'Vehicle Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Truck Number', value: widget.truckNo),
                      _InfoRow(label: 'Engine Number', value: widget.engineNo),
                      _InfoRow(
                        label: 'Chassis Number',
                        value: widget.chassisNo,
                      ),
                      if (widget.vehicleType != null &&
                          widget.vehicleType!.isNotEmpty)
                        _InfoRow(
                          label: 'Vehicle Type',
                          value: widget.vehicleType!,
                        ),
                      _InfoRow(
                        label: 'Truck Owner',
                        value: widget.truckOwnerName,
                      ),
                      if (widget.truckOwnerPhone != null &&
                          widget.truckOwnerPhone!.isNotEmpty)
                        _InfoRow(
                          label: 'Owner Phone',
                          value: widget.truckOwnerPhone!,
                        ),

                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),

                      // Driver Details
                      Text(
                        'Driver Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Driver Name', value: widget.driverName),
                      if (widget.driverPhone != null &&
                          widget.driverPhone!.isNotEmpty)
                        _InfoRow(
                          label: 'Driver Phone',
                          value: widget.driverPhone!,
                        ),
                      if (widget.driverLicense != null &&
                          widget.driverLicense!.isNotEmpty)
                        _InfoRow(
                          label: 'Driver License',
                          value: widget.driverLicense!,
                        ),
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            _InfoRow(
                              label: 'Truck Number',
                              value: widget.truckNo,
                            ),
                            _InfoRow(
                              label: 'Engine Number',
                              value: widget.engineNo,
                            ),
                            _InfoRow(
                              label: 'Chassis Number',
                              value: widget.chassisNo,
                            ),
                            if (widget.vehicleType != null &&
                                widget.vehicleType!.isNotEmpty)
                              _InfoRow(
                                label: 'Vehicle Type',
                                value: widget.vehicleType!,
                              ),
                            _InfoRow(
                              label: 'Truck Owner',
                              value: widget.truckOwnerName,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Driver Details',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            _InfoRow(
                              label: 'Driver Name',
                              value: widget.driverName,
                            ),
                            if (widget.driverAddress != null &&
                                widget.driverAddress!.isNotEmpty)
                              _InfoRow(
                                label: 'Driver Address',
                                value: widget.driverAddress!,
                              ),
                            if (widget.driverPhone != null &&
                                widget.driverPhone!.isNotEmpty)
                              _InfoRow(
                                label: 'Driver Phone',
                                value: widget.driverPhone!,
                              ),
                            if (widget.driverLicense != null &&
                                widget.driverLicense!.isNotEmpty)
                              _InfoRow(
                                label: 'Driver License',
                                value: widget.driverLicense!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      _InfoRow(label: 'From Where', value: widget.fromWhere),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Till Where', value: widget.tillWhere),
                      if (widget.deliveryDate != null) ...[
                        SizedBox(height: 8),
                        _InfoRow(
                          label: 'Delivery Date',
                          value:
                              '${widget.deliveryDate!.day.toString().padLeft(2, '0')}/${widget.deliveryDate!.month.toString().padLeft(2, '0')}/${widget.deliveryDate!.year}',
                        ),
                      ],
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'From Where',
                              value: widget.fromWhere,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'Till Where',
                              value: widget.tillWhere,
                            ),
                          ),
                        ],
                      ),
                      if (widget.deliveryDate != null)
                        _InfoRow(
                          label: 'Delivery Date',
                          value:
                              '${widget.deliveryDate!.day.toString().padLeft(2, '0')}/${widget.deliveryDate!.month.toString().padLeft(2, '0')}/${widget.deliveryDate!.year}',
                        ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoodsTable() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goods & Charges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - cards instead of table
                  return Column(
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.tealBlue.withAlpha(
                            (0.1 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Description',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Qty',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Rate',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Amount',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Goods items as cards
                      ...widget.goods.map(
                        (item) => Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Qty: ${item.quantity.toString()}',
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Rate: ₹${item.rate.toString()}',
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Amount: ₹${item.amount.toString()}',
                                    ),
                                  ),
                                ],
                              ),
                              ...[
                                SizedBox(height: 4),
                                Text('Weight: ${item.weight} kg'),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Desktop layout - table
                  return Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1),
                      5: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: AppColors.tealBlue.withAlpha(
                            (0.1 * 255).round(),
                          ),
                        ),
                        children: [
                          _tableHeader('Description'),
                          _tableHeader('Weight (kg)'),
                          _tableHeader('Quantity'),
                          _tableHeader('Rate (₹)'),
                          _tableHeader('Amount (₹)'),
                          _tableHeader('Remarks'),
                        ],
                      ),
                      ...widget.goods.map(
                        (item) => TableRow(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(item.description),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(item.weight.toString()),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(item.quantity.toString()),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(item.rate.toString()),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(item.amount.toString()),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(''),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargesInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Charges Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      _InfoRow(
                        label: 'Basic Fare (₹)',
                        value: widget.basicFare,
                      ),
                      SizedBox(height: 8),
                      _InfoRow(
                        label: 'Other Charges (₹)',
                        value: widget.otherCharges,
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'GST (₹)', value: widget.gst),
                      SizedBox(height: 8),
                      _InfoRow(
                        label: 'Payment Status',
                        value: widget.paymentStatus,
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.tealBlue.withAlpha(
                            (0.1 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${widget.totalAmount}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tealBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'Basic Fare (₹)',
                              value: widget.basicFare,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'Other Charges (₹)',
                              value: widget.otherCharges,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'GST (₹)',
                              value: widget.gst,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'Payment Status',
                              value: widget.paymentStatus,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.tealBlue.withAlpha(
                            (0.1 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${widget.totalAmount}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.tealBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraCharges() {
    final selectedCharges = widget.extraCharges.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedCharges.isEmpty) return SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extra Charges',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: selectedCharges
                  .map(
                    (charge) => Chip(
                      label: Text(charge.replaceAll('_', ' ').toUpperCase()),
                      backgroundColor: AppColors.tealBlue.withAlpha(
                        (0.1 * 255).round(),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetails() {
    if (widget.bankName.isEmpty &&
        widget.accountName.isEmpty &&
        widget.accountNo.isEmpty &&
        widget.ifscCode.isEmpty) {
      return SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      _InfoRow(label: 'Bank Name', value: widget.bankName),
                      SizedBox(height: 8),
                      _InfoRow(
                        label: 'Account Name',
                        value: widget.accountName,
                      ),
                      SizedBox(height: 8),
                      _InfoRow(
                        label: 'Account Number',
                        value: widget.accountNo,
                      ),
                      SizedBox(height: 8),
                      _InfoRow(label: 'IFSC Code', value: widget.ifscCode),
                    ],
                  );
                } else {
                  // Desktop layout - side by side
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'Bank Name',
                              value: widget.bankName,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'Account Name',
                              value: widget.accountName,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: 'Account Number',
                              value: widget.accountNo,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _InfoRow(
                              label: 'IFSC Code',
                              value: widget.ifscCode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              '1. The trader should load the goods only after completing all the vehicle documents.\n'
              '2. Insurance of goods more than Rs. 10,000/- is a must.\n'
              '3. Goods will be transported at owner\'s risk.\n'
              '4. Payment should be made as per agreed terms.\n'
              '5. Any dispute will be subject to local jurisdiction.\n'
              '6. E-way bill compliance is mandatory for GST registered businesses.\n'
              '7. Delivery will be made only to the authorized person.\n'
              '8. Detention charges will be applicable for delays beyond control.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatures() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile layout - stacked
          return Column(
            children: [
              _SignatureLine(
                label: 'Sender Signature',
                signatureData: widget.senderSignature,
              ),
              SizedBox(height: 16),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SignatureLine(
                label: 'Sender Signature',
                signatureData: widget.senderSignature,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildRemarks() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Special Instructions / Remarks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(widget.remarks, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
  );

  Future<void> _generateAndShowPDF() async {
    try {
      final pdfFile = await _generatePDF();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(pdfFile: pdfFile),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }

  Future<File> _generatePDF() async {
    final pdf = pw.Document();
    final ttf = await PdfGoogleFonts.notoSansRegular();
    // Load assets
    Uint8List truckImageBytes = await rootBundle
        .load('assets/truck.png')
        .then((data) => data.buffer.asUint8List());
    final truckImage = pw.MemoryImage(truckImageBytes);

    // Dynamic sizing for goods table to help fit on one page
    final int goodsCount = widget.goods.length;
    final double goodsFontSize = goodsCount > 10
        ? 7
        : goodsCount > 6
        ? 7.5
        : 8;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Compact Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 50,
                    height: 50,
                    child: pw.Image(truckImage),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          widget.companyName ?? '',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal,
                          ),
                        ),
                        if (widget.companyAddress != null &&
                            widget.companyAddress!.isNotEmpty)
                          pw.Text(
                            widget.companyAddress!,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        if (widget.companyCity != null &&
                            widget.companyCity!.isNotEmpty)
                          pw.Text(
                            widget.companyCity!,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.teal,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      'CONS. COPY',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                color: PdfColors.teal,
                child: pw.Text(
                  'TRANSPORT BILTY / CONSIGNMENT NOTE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),

              // Two-column compact content layout
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        _buildPDFSection('BASIC INFORMATION', [
                          pw.Row(
                            children: [
                              pw.Expanded(
                                child: _buildPDFInfoRow(
                                  'Bilty No.',
                                  widget.biltyNo,
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Expanded(
                                child: _buildPDFInfoRow(
                                  'Bilty Date',
                                  widget.biltyDate != null
                                      ? '${widget.biltyDate!.day.toString().padLeft(2, '0')}/${widget.biltyDate!.month.toString().padLeft(2, '0')}/${widget.biltyDate!.year}'
                                      : '',
                                ),
                              ),
                            ],
                          ),
                          if (widget.biltyType != null &&
                              widget.biltyType!.isNotEmpty)
                            _buildPDFInfoRow('Bilty Type', widget.biltyType!),
                          if (widget.transporterCode != null &&
                              widget.transporterCode!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Transporter Code',
                              widget.transporterCode!,
                            ),
                          if (widget.branchCode != null &&
                              widget.branchCode!.isNotEmpty)
                            _buildPDFInfoRow('Branch Code', widget.branchCode!),
                        ]),
                        _buildPDFSection('SENDER DETAILS', [
                          _buildPDFInfoRow('Name', widget.senderName),
                          _buildPDFInfoRow('Address', widget.senderAddress),
                          if (widget.senderEmail != null &&
                              widget.senderEmail!.isNotEmpty)
                            _buildPDFInfoRow('Email', widget.senderEmail!),
                          if (widget.senderPAN != null &&
                              widget.senderPAN!.isNotEmpty)
                            _buildPDFInfoRow('PAN', widget.senderPAN!),
                          if (widget.senderGSTIN.isNotEmpty)
                            _buildPDFInfoRow('GSTIN', widget.senderGSTIN),
                          if (widget.senderPhone.isNotEmpty)
                            _buildPDFInfoRow('Phone', widget.senderPhone),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        _buildPDFSection('VEHICLE & DRIVER', [
                          _buildPDFInfoRow('Truck No.', widget.truckNo),
                          _buildPDFInfoRow('Engine No.', widget.engineNo),
                          _buildPDFInfoRow('Chassis No.', widget.chassisNo),
                          if (widget.vehicleType != null &&
                              widget.vehicleType!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Vehicle Type',
                              widget.vehicleType!,
                            ),
                          _buildPDFInfoRow(
                            'Truck Owner',
                            widget.truckOwnerName,
                          ),
                          if (widget.truckOwnerPhone != null &&
                              widget.truckOwnerPhone!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Owner Phone',
                              widget.truckOwnerPhone!,
                            ),
                          _buildPDFInfoRow('Driver Name', widget.driverName),
                          if (widget.driverAddress != null &&
                              widget.driverAddress!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Driver Address',
                              widget.driverAddress!,
                            ),
                          if (widget.driverPhone != null &&
                              widget.driverPhone!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Driver Phone',
                              widget.driverPhone!,
                            ),
                          if (widget.driverLicense != null &&
                              widget.driverLicense!.isNotEmpty)
                            _buildPDFInfoRow(
                              'Driver License',
                              widget.driverLicense!,
                            ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),

              // Goods table compact
              _buildPDFSection('GOODS & CHARGES', [
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.teal, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.teal),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Description',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Weight',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Qty',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Rate',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            'Amount',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...widget.goods.map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              item.description,
                              style: pw.TextStyle(fontSize: goodsFontSize),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              item.weight.toString(),
                              style: pw.TextStyle(fontSize: goodsFontSize),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              item.quantity.toString(),
                              style: pw.TextStyle(fontSize: goodsFontSize),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              item.rate.toString(),
                              style: pw.TextStyle(fontSize: goodsFontSize),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(3),
                            child: pw.Text(
                              item.amount.toString(),
                              style: pw.TextStyle(fontSize: goodsFontSize),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPDFInfoRow(
                        'Basic Fare (₹)',
                        widget.basicFare,
                        ttf,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(
                      child: _buildPDFInfoRow(
                        'Other Charges (₹)',
                        widget.otherCharges,
                        ttf,
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Expanded(child: _buildPDFInfoRow('GST (%)', widget.gst)),
                    pw.SizedBox(width: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'TOTAL: ₹${widget.totalAmount}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          font: ttf,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ]),

              pw.SizedBox(height: 4),

              // Signatures + Bank compact row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey400,
                          width: 0.8,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPDFSignature('SENDER', widget.senderSignature),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  if (widget.bankName.isNotEmpty ||
                      widget.accountName.isNotEmpty ||
                      widget.accountNo.isNotEmpty ||
                      widget.ifscCode.isNotEmpty)
                    pw.Container(
                      width: 200,
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey400,
                          width: 0.8,
                        ),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BANK DETAILS',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          _buildPDFInfoRow('Bank', widget.bankName),
                          _buildPDFInfoRow('Acc. Name', widget.accountName),
                          _buildPDFInfoRow('Acc. No', widget.accountNo),
                          _buildPDFInfoRow('IFSC', widget.ifscCode),
                        ],
                      ),
                    ),
                ],
              ),

              if (widget.remarks.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _buildPDFSection('REMARKS', [
                  pw.Text(
                    widget.remarks,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ]),
              ],

              pw.SizedBox(height: 4),
              _buildPDFSection('TERMS', [
                pw.Text(
                  '1) Goods transported at owner\'s risk. 2) E-way bill as applicable. 3) Payment as per agreed terms. 4) Disputes under local jurisdiction.',
                  style: const pw.TextStyle(fontSize: 7, height: 1.2),
                ),
              ]),

              pw.SizedBox(height: 4),
              pw.Text(
                'This is a computer generated document.',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/transport_bilty.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Helper method to build PDF sections
  pw.Widget _buildPDFSection(String title, List<pw.Widget> children) {
    if (children.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(AppColors.tealBlue.toARGB32()),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build PDF info rows
  pw.Widget _buildPDFInfoRow(String label, String value, [pw.Font? font]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 82,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                font: font,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 7.5),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build PDF signature areas
  pw.Widget _buildPDFSignature(String label, String? signatureData) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: 90,
          height: 35,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 1),
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: signatureData != null && signatureData.isNotEmpty
              ? pw.Image(pw.MemoryImage(base64Decode(signatureData)))
              : null,
        ),
      ],
    );
  }

  /// --- New Upload and Save Logic ---
  Future<void> _uploadAndSaveBilty() async {
    setState(() => _isUploading = true);
    final supabase = Supabase.instance.client;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User is not authenticated.");
      }

      final profileResponse = await supabase
          .from('user_profiles')
          .select('custom_user_id')
          .eq('user_id', userId)
          .single();

      final customUserId = profileResponse['custom_user_id'] as String?;
      if (customUserId == null || customUserId.isEmpty) {
        throw Exception("Custom user ID not found for the user.");
      }

      final biltyData = {
        'user_id': userId,
        'shipment_id': widget.shipmentId,
        'bilty_no': widget.biltyNo,
        'consignor_name': widget.senderName,
        'consignee_name': widget.recipientName,
        'origin': widget.fromWhere,
        'destination': widget.tillWhere,
        'total_fare': double.tryParse(widget.totalAmount) ?? 0.0,
        'metadata': {
          'senderName': widget.senderName,
          'senderAddress': widget.senderAddress,
          'senderGSTIN': widget.senderGSTIN,
          'senderPhone': widget.senderPhone,
          'recipientName': widget.recipientName,
          'recipientAddress': widget.recipientAddress,
          'recipientGSTIN': widget.recipientGSTIN,
          'recipientPhone': widget.recipientPhone,
          'truckOwnerName': widget.truckOwnerName,
          'driverName': widget.driverName,
          'chassisNo': widget.chassisNo,
          'engineNo': widget.engineNo,
          'truckNo': widget.truckNo,
          'biltyDate': widget.biltyDate?.toIso8601String(),
          'goods': widget.goods.map((g) => g.toJson()).toList(),
          'basicFare': widget.basicFare,
          'otherCharges': widget.otherCharges,
          'gst': widget.gst,
          'paymentStatus': widget.paymentStatus,
          'extraCharges': widget.extraCharges,
          'bankName': widget.bankName,
          'accountName': widget.accountName,
          'accountNo': widget.accountNo,
          'ifscCode': widget.ifscCode,
          'remarks': widget.remarks,
        },
      };

      final existingBilty = await supabase
          .from('bilties')
          .select("bilty_no")
          .eq("bilty_no", biltyData['bilty_no']!)
          .maybeSingle();

      final pdfFile = await _generatePDF();

      if (existingBilty == null) {
        await supabase.from('bilties').insert(biltyData);
        final pdfBytes = await pdfFile.readAsBytes();
        final filePath = '$customUserId/${widget.biltyNo}.pdf';
        await supabase.storage
            .from('bilties')
            .uploadBinary(
              filePath,
              pdfBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
                contentType: 'application/pdf',
              ),
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bilty uploaded and saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          text: "Bilty: #$widget.shipmentId",
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SignatureLine extends StatelessWidget {
  final String label;
  final String? signatureData;

  const _SignatureLine({required this.label, this.signatureData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 150,
          height: 80,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
          child: signatureData != null && signatureData!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    base64Decode(signatureData!),
                    fit: BoxFit.contain,
                  ),
                )
              : Container(width: 150, height: 1, color: Theme.of(context).cardColor,),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13)),
      ],
    );
  }
}
