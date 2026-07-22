import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../providers/products_catalog_providers.dart';

enum _ProductSortField { sku, name }

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _categoryId;
  _ProductSortField _sortField = _ProductSortField.name;
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  int _page = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _page = 0);
      ref
          .read(productListProvider.notifier)
          .applyFilter(
            search: value.trim().isEmpty ? null : value.trim(),
            categoryId: _categoryId,
          );
    });
  }

  void _onCategoryChanged(String? categoryId) {
    setState(() {
      _categoryId = categoryId;
      _page = 0;
    });
    ref
        .read(productListProvider.notifier)
        .applyFilter(
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          categoryId: categoryId,
        );
  }

  List<Product> _sorted(List<Product> products) {
    final sorted = [...products];
    sorted.sort((a, b) {
      final result = switch (_sortField) {
        _ProductSortField.sku => a.sku.compareTo(b.sku),
        _ProductSortField.name => a.name.compareTo(b.name),
      };
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);
    final categories = ref
        .watch(categoriesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Category>[]);
    final categoryNames = {for (final c in categories) c.id: c.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (route) => context.push(route),
            itemBuilder: (context) => const [
              PopupMenuItem(value: '/categories', child: Text('Categories')),
              PopupMenuItem(value: '/brands', child: Text('Brands')),
              PopupMenuItem(value: '/units', child: Text('Units of measure')),
              PopupMenuItem(
                value: '/products/import-export',
                child: Text('Import / Export CSV'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        permission: 'products.create',
        child: FloatingActionButton.extended(
          onPressed: () async {
            final createdId = await context.push<String>('/products/new');
            if (createdId != null && context.mounted) {
              await context.push('/products/$createdId');
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('New product'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search by name or SKU',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: _onCategoryChanged,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(productListProvider.notifier).refresh(),
              child: AsyncValueView(
                value: productsAsync,
                onRetry: () => ref.read(productListProvider.notifier).refresh(),
                errorPrefix: 'Could not load products',
                data: (context, products) {
                  if (products.isEmpty) {
                    return ListView(
                      children: [
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products found',
                          message:
                              _searchController.text.isEmpty &&
                                  _categoryId == null
                              ? 'Create your first product to get started.'
                              : 'Try a different search or filter.',
                        ),
                      ],
                    );
                  }
                  final sorted = _sorted(products);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      return isWide
                          ? _ProductDataTable(
                              products: sorted,
                              categoryNames: categoryNames,
                              sortField: _sortField,
                              sortAscending: _sortAscending,
                              rowsPerPage: _rowsPerPage,
                              page: _page,
                              onSort: (field, ascending) => setState(() {
                                _sortField = field;
                                _sortAscending = ascending;
                              }),
                              onPageChanged: (page) =>
                                  setState(() => _page = page),
                              onRowsPerPageChanged: (rows) => setState(() {
                                _rowsPerPage = rows;
                                _page = 0;
                              }),
                              onTap: (product) =>
                                  context.push('/products/${product.id}'),
                            )
                          : _ProductListView(
                              products: sorted,
                              categoryNames: categoryNames,
                              page: _page,
                              rowsPerPage: _rowsPerPage,
                              onPageChanged: (page) =>
                                  setState(() => _page = page),
                              onTap: (product) =>
                                  context.push('/products/${product.id}'),
                            );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDataTable extends StatelessWidget {
  const _ProductDataTable({
    required this.products,
    required this.categoryNames,
    required this.sortField,
    required this.sortAscending,
    required this.rowsPerPage,
    required this.page,
    required this.onSort,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
    required this.onTap,
  });

  final List<Product> products;
  final Map<String, String> categoryNames;
  final _ProductSortField sortField;
  final bool sortAscending;
  final int rowsPerPage;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onRowsPerPageChanged;
  final void Function(_ProductSortField field, bool ascending) onSort;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PaginatedDataTable(
        header: Text('${products.length} product(s)'),
        rowsPerPage: rowsPerPage,
        availableRowsPerPage: const [10, 20, 50],
        onRowsPerPageChanged: (value) => onRowsPerPageChanged(value ?? 10),
        initialFirstRowIndex: page * rowsPerPage,
        onPageChanged: (firstRowIndex) =>
            onPageChanged((firstRowIndex / rowsPerPage).floor()),
        sortColumnIndex: sortField == _ProductSortField.sku ? 0 : 1,
        sortAscending: sortAscending,
        columns: [
          DataColumn(
            label: const Text('SKU'),
            onSort: (columnIndex, ascending) =>
                onSort(_ProductSortField.sku, ascending),
          ),
          DataColumn(
            label: const Text('Name'),
            onSort: (columnIndex, ascending) =>
                onSort(_ProductSortField.name, ascending),
          ),
          const DataColumn(label: Text('Category')),
          const DataColumn(label: Text('Variants')),
          const DataColumn(label: Text('Status')),
        ],
        source: _ProductDataSource(
          products: products,
          categoryNames: categoryNames,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ProductDataSource extends DataTableSource {
  _ProductDataSource({
    required this.products,
    required this.categoryNames,
    required this.onTap,
  });

  final List<Product> products;
  final Map<String, String> categoryNames;
  final ValueChanged<Product> onTap;

  @override
  DataRow getRow(int index) {
    final product = products[index];
    return DataRow(
      onSelectChanged: (_) => onTap(product),
      cells: [
        DataCell(Text(product.sku)),
        DataCell(Text(product.name)),
        DataCell(
          Text(
            product.categoryId != null
                ? (categoryNames[product.categoryId] ?? '—')
                : '—',
          ),
        ),
        DataCell(Text(product.hasVariants ? 'Multiple' : 'Single')),
        DataCell(
          Chip(
            label: Text(product.isActive ? 'Active' : 'Inactive'),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}

class _ProductListView extends StatelessWidget {
  const _ProductListView({
    required this.products,
    required this.categoryNames,
    required this.page,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<Product> products;
  final Map<String, String> categoryNames;
  final int page;
  final int rowsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    final pageCount = (products.length / rowsPerPage).ceil().clamp(1, 1 << 30);
    final currentPage = page.clamp(0, pageCount - 1);
    final start = currentPage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, products.length);
    final pageItems = products.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: pageItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = pageItems[index];
              final categoryName = product.categoryId != null
                  ? categoryNames[product.categoryId]
                  : null;
              return ListTile(
                title: Text(product.name),
                subtitle: Text(
                  [
                    product.sku,
                    ?categoryName,
                    if (!product.isActive) 'Inactive',
                  ].join(' · '),
                ),
                trailing: Icon(
                  product.hasVariants
                      ? Icons.style_outlined
                      : Icons.inventory_2_outlined,
                ),
                onTap: () => onTap(product),
              );
            },
          ),
        ),
        if (pageCount > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentPage > 0
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                ),
                Text('Page ${currentPage + 1} of $pageCount'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentPage < pageCount - 1
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
