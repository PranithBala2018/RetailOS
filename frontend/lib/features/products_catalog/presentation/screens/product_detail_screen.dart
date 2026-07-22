import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_with_variants.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';
import '../widgets/barcode_form_dialog.dart';
import '../widgets/image_form_dialog.dart';
import '../widgets/product_edit_dialog.dart';
import '../widgets/variant_form_dialog.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          PermissionGate(
            permission: 'products.update',
            child: detailAsync.maybeWhen(
              data: (detail) => IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit product',
                onPressed: () => _openEditDialog(context, ref, detail.product),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          PermissionGate(
            permission: 'products.delete',
            child: detailAsync.maybeWhen(
              data: (detail) => IconButton(
                icon: const Icon(Icons.block),
                tooltip: 'Disable product',
                onPressed: detail.product.isActive
                    ? () => _disableProduct(context, ref, detail.product)
                    : null,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(productDetailProvider(productId)),
        child: AsyncValueView(
          value: detailAsync,
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
          errorPrefix: 'Could not load this product',
          data: (context, detail) =>
              _ProductDetailBody(productId: productId, detail: detail),
        ),
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final saved = await showProductEditDialog(context, product: product);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product updated')));
    }
  }

  Future<void> _disableProduct(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Disable product?',
      message:
          '"${product.name}" will no longer be sellable until re-activated.',
      confirmLabel: 'Disable',
      isDestructive: true,
    );
    if (!confirmed) return;

    final result = await ref
        .read(productDetailProvider(productId).notifier)
        .updateProduct(_asDisableParams(product), product.version);
    if (!context.mounted) return;
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
      (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product disabled'))),
    );
  }
}

/// A `ProductUpdateParams` built from the current product's fields with
/// `isActive: false` is the only "disable" operation the backend exposes
/// for products (see api.py's `disable_product`) — there is no separate
/// disable endpoint/params type to call instead.
ProductUpdateParams _asDisableParams(Product product) => ProductUpdateParams(
  name: product.name,
  description: product.description,
  categoryId: product.categoryId,
  brandId: product.brandId,
  gender: product.gender,
  season: product.season,
  ageGroup: product.ageGroup,
  hsnCode: product.hsnCode,
  taxPercent: product.taxPercent,
  trackInventory: product.trackInventory,
  allowNegativeStock: product.allowNegativeStock,
  lowStockThreshold: product.lowStockThreshold,
  isActive: false,
);

class _ProductDetailBody extends ConsumerWidget {
  const _ProductDetailBody({required this.productId, required this.detail});

  final String productId;
  final ProductWithVariants detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = detail.product;
    final imagesAsync = ref.watch(productImagesProvider(productId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (!product.isActive)
                      Chip(
                        label: const Text('Inactive'),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                      ),
                  ],
                ),
                Text(
                  'SKU: ${product.sku}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (product.description != null) ...[
                  const SizedBox(height: 8),
                  Text(product.description!),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (product.gender != null)
                      Chip(label: Text(product.gender!.label)),
                    if (product.season != null)
                      Chip(label: Text(product.season!)),
                    if (product.ageGroup != null)
                      Chip(label: Text(product.ageGroup!)),
                    if (product.hsnCode != null)
                      Chip(label: Text('HSN ${product.hsnCode}')),
                    if (product.taxPercent != null)
                      Chip(label: Text('Tax ${product.taxPercent}%')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Variants',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            PermissionGate(
              permission: 'products.update',
              child: OutlinedButton.icon(
                onPressed: () => _openAddVariantDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add variant'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final variant in detail.variants)
          _VariantCard(productId: productId, variant: variant),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Images',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            PermissionGate(
              permission: 'products.update',
              child: OutlinedButton.icon(
                onPressed: () => _openAddImageDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add image'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        imagesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Text('Could not load images: $error'),
          data: (images) {
            if (images.isEmpty) {
              return const EmptyState(
                icon: Icons.image_outlined,
                title: 'No images yet',
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images
                  .map(
                    (image) => Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image.imageUrl,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 96,
                                  height: 96,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                          ),
                        ),
                        if (image.isPrimary)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Primary',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _openAddVariantDialog(BuildContext context) async {
    final added = await showVariantFormDialog(context, productId: productId);
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Variant added')));
    }
  }

  Future<void> _openAddImageDialog(BuildContext context) async {
    final added = await showImageFormDialog(context, productId: productId);
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image added')));
    }
  }
}

class _VariantCard extends ConsumerWidget {
  const _VariantCard({required this.productId, required this.variant});

  final String productId;
  final ProductVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barcodesAsync = ref.watch(variantBarcodesProvider(variant.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(variant.variantName ?? variant.sku),
        subtitle: Text(
          'SKU ${variant.sku} · ${MoneyFormat.display(variant.sellingPrice)}'
          '${variant.isActive ? '' : ' · Inactive'}',
        ),
        trailing: PermissionGate(
          permission: 'products.update',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit variant',
            onPressed: () => _openEditVariantDialog(context),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  children: [
                    Text(
                      'Purchase: ${MoneyFormat.display(variant.purchasePrice)}',
                    ),
                    Text(
                      'Selling: ${MoneyFormat.display(variant.sellingPrice)}',
                    ),
                    if (variant.mrp != null)
                      Text('MRP: ${MoneyFormat.display(variant.mrp)}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Barcodes',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    PermissionGate(
                      permission: 'products.update',
                      child: TextButton.icon(
                        onPressed: () => _openAddBarcodeDialog(context, ref),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ),
                  ],
                ),
                barcodesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Could not load barcodes: $error'),
                  data: (barcodes) {
                    if (barcodes.isEmpty) {
                      return const Text('No barcodes yet');
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: barcodes
                          .map(
                            (b) => Chip(
                              label: Text(
                                '${b.barcode} (${b.barcodeType.label})',
                              ),
                              avatar: b.isPrimary
                                  ? const Icon(Icons.star, size: 16)
                                  : null,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditVariantDialog(BuildContext context) async {
    final saved = await showVariantFormDialog(
      context,
      productId: productId,
      existing: variant,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Variant updated')));
    }
  }

  Future<void> _openAddBarcodeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final added = await showBarcodeFormDialog(context, variantId: variant.id);
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Barcode added')));
    }
  }
}
