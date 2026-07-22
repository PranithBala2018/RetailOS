import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failure_x.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/csv_import_summary.dart';
import '../providers/products_catalog_providers.dart';

/// The CSV column contract mirrors
/// `backend/app/modules/products_catalog/csv_io.py` exactly — one row
/// per variant, category/brand/unit referenced by name. Built from
/// explicit column lists (rather than one hand-typed comma string) so
/// the column count is easy to verify against `EXPORT_COLUMNS`/
/// `_REQUIRED_IMPORT_COLUMNS` in that file.
const List<String> _templateColumns = [
  'sku',
  'name',
  'description',
  'category',
  'brand',
  'unit',
  'gender',
  'season',
  'age_group',
  'hsn_code',
  'tax_percent',
  'track_inventory',
  'allow_negative_stock',
  'low_stock_threshold',
  'variant_sku',
  'size',
  'color',
  'purchase_price',
  'selling_price',
  'mrp',
];

// A simple product (one implicit variant, its own SKU reused as the
// variant SKU) and a variant-bearing product (Kids Wear pilot: gender +
// size/color), so the template demonstrates both shapes.
const List<List<String>> _templateRows = [
  [
    'TEA-001',
    'Masala Tea Powder 250g',
    '',
    'Beverages',
    '',
    'pcs',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'TEA-001',
    '',
    '',
    '90.00',
    '120.00',
    '',
  ],
  [
    'KID-SHIRT-001',
    'Kids Cotton T-Shirt',
    '',
    'Apparel',
    '',
    'pcs',
    'kids',
    'summer',
    '4-6y',
    '',
    '',
    '',
    '',
    '',
    'KID-SHIRT-001-RED-S',
    'S',
    'Red',
    '100.00',
    '200.00',
    '220.00',
  ],
];

String get _templateCsv {
  final buffer = StringBuffer(_templateColumns.join(','));
  buffer.write('\n');
  for (final row in _templateRows) {
    assert(
      row.length == _templateColumns.length,
      'template row/column count mismatch',
    );
    buffer.write(row.join(','));
    buffer.write('\n');
  }
  return buffer.toString();
}

class CsvImportExportScreen extends ConsumerStatefulWidget {
  const CsvImportExportScreen({super.key});

  @override
  ConsumerState<CsvImportExportScreen> createState() =>
      _CsvImportExportScreenState();
}

class _CsvImportExportScreenState extends ConsumerState<CsvImportExportScreen> {
  bool _isExporting = false;
  bool _isDownloadingTemplate = false;
  bool _isImporting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _saveCsvToDownloads(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(content);
    if (!mounted) return;
    setState(() {
      _statusIsError = false;
      _statusMessage = 'Saved to ${file.path}';
    });
  }

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloadingTemplate = true);
    await _saveCsvToDownloads(_templateCsv, 'products_template.csv');
    if (mounted) setState(() => _isDownloadingTemplate = false);
  }

  Future<void> _exportProducts() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });
    final result = await ref.read(productsCsvProvider.notifier).exportCsv();
    if (!mounted) return;
    await result.match(
      (failure) async => setState(() {
        _isExporting = false;
        _statusIsError = true;
        _statusMessage = failure.userMessage;
      }),
      (csvText) async {
        await _saveCsvToDownloads(csvText, 'products_export.csv');
        if (mounted) setState(() => _isExporting = false);
      },
    );
  }

  Future<void> _importProducts() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Could not read the selected file.';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = null;
    });

    final result = await ref
        .read(productsCsvProvider.notifier)
        .importCsv(bytes: bytes, filename: picked.files.single.name);

    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _isImporting = false;
        _statusIsError = true;
        _statusMessage = failure.userMessage;
      }),
      (summary) => setState(() {
        _isImporting = false;
        _statusIsError = summary.errors > 0;
        _statusMessage =
            'Import complete: ${summary.created} created, ${summary.skipped} skipped, '
            '${summary.errors} errors.';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastImport = ref.watch(productsCsvProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import / Export products')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Download the template',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'One row per variant. Category, brand, and unit are matched by name — '
                    'unknown categories/brands are created automatically on import.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isDownloadingTemplate
                        ? null
                        : _downloadTemplate,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download CSV template'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          PermissionGate(
            permission: 'products.import',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Import products',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A SKU that already exists is skipped, not overwritten — re-running the '
                      'same file is always safe.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isImporting ? null : _importProducts,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined),
                      label: Text(
                        _isImporting ? 'Importing…' : 'Choose CSV file',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PermissionGate(
            permission: 'products.export',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Export current catalog',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportProducts,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(
                        _isExporting
                            ? 'Exporting…'
                            : 'Export all products to CSV',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _statusIsError
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_statusMessage!),
              ),
            ),
          ],
          if (lastImport != null && lastImport.results.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Last import details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _ImportResultsTable(summary: lastImport),
          ],
        ],
      ),
    );
  }
}

class _ImportResultsTable extends StatelessWidget {
  const _ImportResultsTable({required this.summary});

  final CsvImportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Message')),
          ],
          rows: summary.results
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.sku)),
                    DataCell(_StatusChip(status: row.status)),
                    DataCell(Text(row.message ?? '')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CsvImportRowStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CsvImportRowStatus.created => ('Created', Colors.green),
      CsvImportRowStatus.skipped => ('Skipped', Colors.orange),
      CsvImportRowStatus.error => (
        'Error',
        Theme.of(context).colorScheme.error,
      ),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
