import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/products_catalog_remote_data_source.dart';
import '../../data/repositories/products_catalog_repository_impl.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/csv_import_summary.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_barcode.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_with_variants.dart';
import '../../domain/entities/unit_of_measure.dart';
import '../../domain/repositories/products_catalog_repository.dart';

part 'products_catalog_providers.g.dart';

@riverpod
ProductsCatalogRepository productsCatalogRepository(Ref ref) {
  return ProductsCatalogRepositoryImpl(
    ProductsCatalogRemoteDataSource(ref.watch(dioProvider)),
  );
}

@riverpod
class CategoriesNotifier extends _$CategoriesNotifier {
  @override
  Future<List<Category>> build() async {
    final result = await ref
        .watch(productsCatalogRepositoryProvider)
        .listCategories();
    return result.match((failure) => throw failure, (categories) => categories);
  }

  Future<Either<Failure, Category>> create(CategoryCreateParams params) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.createCategory(params);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Either<Failure, Category>> updateCategory(
    String categoryId,
    CategoryUpdateParams params,
    int expectedVersion,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.updateCategory(
      categoryId,
      params,
      expectedVersion,
    );
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

@riverpod
class BrandsNotifier extends _$BrandsNotifier {
  @override
  Future<List<Brand>> build() async {
    final result = await ref
        .watch(productsCatalogRepositoryProvider)
        .listBrands();
    return result.match((failure) => throw failure, (brands) => brands);
  }

  Future<Either<Failure, Brand>> create(BrandCreateParams params) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.createBrand(params);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Either<Failure, Brand>> updateBrand(
    String brandId,
    BrandUpdateParams params,
    int expectedVersion,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.updateBrand(
      brandId,
      params,
      expectedVersion,
    );
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

@riverpod
class UnitsNotifier extends _$UnitsNotifier {
  @override
  Future<List<UnitOfMeasure>> build() async {
    final result = await ref
        .watch(productsCatalogRepositoryProvider)
        .listUnits();
    return result.match((failure) => throw failure, (units) => units);
  }

  Future<Either<Failure, UnitOfMeasure>> create(UnitCreateParams params) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.createUnit(params);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

/// Owns both the product list and its active search/category filter, so
/// every mutation can re-fetch with the filter still applied instead of
/// resetting it.
@riverpod
class ProductListNotifier extends _$ProductListNotifier {
  String? _search;
  String? _categoryId;

  @override
  Future<List<Product>> build() async {
    final result = await ref
        .watch(productsCatalogRepositoryProvider)
        .listProducts(search: _search, categoryId: _categoryId);
    return result.match((failure) => throw failure, (products) => products);
  }

  Future<void> applyFilter({String? search, String? categoryId}) async {
    _search = search;
    _categoryId = categoryId;
    ref.invalidateSelf();
    await future;
  }

  Future<Either<Failure, ProductWithVariants>> create(
    ProductCreateParams params,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.createProduct(params);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Either<Failure, Unit>> disable(
    String productId,
    int expectedVersion,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.disableProduct(productId, expectedVersion);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class ProductDetailNotifier extends _$ProductDetailNotifier {
  late String _productId;

  @override
  Future<ProductWithVariants> build(String productId) async {
    _productId = productId;
    final result = await ref
        .watch(productsCatalogRepositoryProvider)
        .getProduct(productId);
    return result.match(
      (failure) => throw failure,
      (productWithVariants) => productWithVariants,
    );
  }

  Future<Either<Failure, Product>> updateProduct(
    ProductUpdateParams params,
    int expectedVersion,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.updateProduct(
      _productId,
      params,
      expectedVersion,
    );
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Either<Failure, ProductVariant>> addVariant(
    ProductVariantInputParams params,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.addVariant(_productId, params);
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }

  Future<Either<Failure, ProductVariant>> updateVariant(
    String variantId,
    ProductVariantUpdateParams params,
    int expectedVersion,
  ) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.updateVariant(
      variantId,
      params,
      expectedVersion,
    );
    if (result.isRight()) {
      ref.invalidateSelf();
      await future;
    }
    return result;
  }
}

@riverpod
Future<List<ProductBarcode>> variantBarcodes(Ref ref, String variantId) async {
  final result = await ref
      .watch(productsCatalogRepositoryProvider)
      .listBarcodes(variantId);
  return result.match((failure) => throw failure, (barcodes) => barcodes);
}

@riverpod
Future<List<ProductImage>> productImages(Ref ref, String productId) async {
  final result = await ref
      .watch(productsCatalogRepositoryProvider)
      .listImages(productId);
  return result.match((failure) => throw failure, (images) => images);
}

/// One-shot CSV export/import actions. `state` doubles as the last import
/// summary so the UI can render a result panel after `importCsv`
/// completes — `null` means "nothing imported yet this session".
@riverpod
class ProductsCsvNotifier extends _$ProductsCsvNotifier {
  @override
  CsvImportSummary? build() => null;

  Future<Either<Failure, String>> exportCsv() {
    return ref.read(productsCatalogRepositoryProvider).exportProductsCsv();
  }

  Future<Either<Failure, CsvImportSummary>> importCsv({
    required List<int> bytes,
    required String filename,
  }) async {
    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.importProductsCsv(
      bytes: bytes,
      filename: filename,
    );
    result.match((failure) {}, (summary) {
      state = summary;
      ref.invalidate(productListProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(brandsProvider);
    });
    return result;
  }

  void clear() => state = null;
}
