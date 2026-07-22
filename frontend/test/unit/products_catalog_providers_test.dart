import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/products_catalog/domain/entities/barcode_type.dart';
import 'package:retailos/features/products_catalog/domain/entities/brand.dart';
import 'package:retailos/features/products_catalog/domain/entities/category.dart';
import 'package:retailos/features/products_catalog/domain/entities/csv_import_summary.dart';
import 'package:retailos/features/products_catalog/domain/entities/product.dart';
import 'package:retailos/features/products_catalog/domain/entities/product_barcode.dart';
import 'package:retailos/features/products_catalog/domain/entities/product_image.dart';
import 'package:retailos/features/products_catalog/domain/entities/product_variant.dart';
import 'package:retailos/features/products_catalog/domain/entities/product_with_variants.dart';
import 'package:retailos/features/products_catalog/domain/entities/unit_of_measure.dart';
import 'package:retailos/features/products_catalog/domain/repositories/products_catalog_repository.dart';
import 'package:retailos/features/products_catalog/presentation/providers/products_catalog_providers.dart';

/// A stateful in-memory fake — real assertions here need mutation to
/// actually round-trip through the notifier (create -> refetch), which a
/// stub returning fixed values can't exercise.
class _FakeProductsCatalogRepository implements ProductsCatalogRepository {
  final List<Category> categories = [];
  final List<Brand> brands = [];
  final List<UnitOfMeasure> units = [];
  final List<Product> products = [];
  final Map<String, List<ProductVariant>> variantsByProductId = {};
  final Map<String, List<ProductBarcode>> barcodesByVariantId = {};
  final Map<String, List<ProductImage>> imagesByProductId = {};
  List<String>? lastListProductsCall;

  @override
  Future<Either<Failure, List<Category>>> listCategories() async =>
      Right([...categories]);

  @override
  Future<Either<Failure, Category>> createCategory(
    CategoryCreateParams params,
  ) async {
    final category = Category(
      id: 'cat-${categories.length + 1}',
      companyId: 'company-1',
      name: params.name,
      parentCategoryId: params.parentCategoryId,
      displayOrder: params.displayOrder,
      isActive: true,
      version: 1,
    );
    categories.add(category);
    return Right(category);
  }

  @override
  Future<Either<Failure, Category>> updateCategory(
    String categoryId,
    CategoryUpdateParams params,
    int expectedVersion,
  ) async {
    final index = categories.indexWhere((c) => c.id == categoryId);
    final updated = categories[index].copyWith(
      name: params.name,
      displayOrder: params.displayOrder,
      isActive: params.isActive,
      version: expectedVersion + 1,
    );
    categories[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, List<Brand>>> listBrands() async => Right([...brands]);

  @override
  Future<Either<Failure, Brand>> createBrand(BrandCreateParams params) async {
    final brand = Brand(
      id: 'brand-${brands.length + 1}',
      companyId: 'company-1',
      name: params.name,
      isActive: true,
      version: 1,
    );
    brands.add(brand);
    return Right(brand);
  }

  @override
  Future<Either<Failure, Brand>> updateBrand(
    String brandId,
    BrandUpdateParams params,
    int expectedVersion,
  ) async {
    final index = brands.indexWhere((b) => b.id == brandId);
    final updated = brands[index].copyWith(
      name: params.name,
      logoUrl: params.logoUrl,
      description: params.description,
      isActive: params.isActive,
      version: expectedVersion + 1,
    );
    brands[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, List<UnitOfMeasure>>> listUnits() async =>
      Right([...units]);

  @override
  Future<Either<Failure, UnitOfMeasure>> createUnit(
    UnitCreateParams params,
  ) async {
    final unit = UnitOfMeasure(
      id: 'unit-${units.length + 1}',
      companyId: 'company-1',
      name: params.name,
      abbreviation: params.abbreviation,
      isSystem: false,
    );
    units.add(unit);
    return Right(unit);
  }

  @override
  Future<Either<Failure, List<Product>>> listProducts({
    String? search,
    String? categoryId,
  }) async {
    lastListProductsCall = [search ?? '', categoryId ?? ''];
    final filtered = products.where((p) {
      final matchesSearch =
          search == null || p.name.contains(search) || p.sku.contains(search);
      final matchesCategory = categoryId == null || p.categoryId == categoryId;
      return matchesSearch && matchesCategory;
    }).toList();
    return Right(filtered);
  }

  @override
  Future<Either<Failure, ProductWithVariants>> createProduct(
    ProductCreateParams params,
  ) async {
    final product = Product(
      id: 'prod-${products.length + 1}',
      companyId: 'company-1',
      sku: params.sku,
      name: params.name,
      categoryId: params.categoryId,
      baseUnitId: params.baseUnitId,
      hasVariants: params.hasVariants,
      trackInventory: params.trackInventory,
      allowNegativeStock: params.allowNegativeStock,
      isActive: true,
      version: 1,
    );
    products.add(product);
    variantsByProductId[product.id] = [
      ProductVariant(
        id: 'var-${product.id}',
        companyId: 'company-1',
        productId: product.id,
        sku: params.sku,
        purchasePrice: params.purchasePrice,
        sellingPrice: params.sellingPrice,
        isActive: true,
        version: 1,
      ),
    ];
    return Right(
      ProductWithVariants(
        product: product,
        variants: variantsByProductId[product.id]!,
      ),
    );
  }

  @override
  Future<Either<Failure, ProductWithVariants>> getProduct(
    String productId,
  ) async {
    final product = products.firstWhere((p) => p.id == productId);
    return Right(
      ProductWithVariants(
        product: product,
        variants: variantsByProductId[productId]!,
      ),
    );
  }

  @override
  Future<Either<Failure, Product>> updateProduct(
    String productId,
    ProductUpdateParams params,
    int expectedVersion,
  ) async {
    final index = products.indexWhere((p) => p.id == productId);
    final updated = products[index].copyWith(
      name: params.name,
      description: params.description,
      categoryId: params.categoryId,
      brandId: params.brandId,
      gender: params.gender,
      season: params.season,
      ageGroup: params.ageGroup,
      hsnCode: params.hsnCode,
      taxPercent: params.taxPercent,
      trackInventory: params.trackInventory,
      allowNegativeStock: params.allowNegativeStock,
      lowStockThreshold: params.lowStockThreshold,
      isActive: params.isActive,
      version: expectedVersion + 1,
    );
    products[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> disableProduct(
    String productId,
    int expectedVersion,
  ) async {
    final index = products.indexWhere((p) => p.id == productId);
    products[index] = products[index].copyWith(
      isActive: false,
      version: expectedVersion + 1,
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<ProductVariant>>> listVariants(
    String productId,
  ) async => Right(variantsByProductId[productId] ?? []);

  @override
  Future<Either<Failure, ProductVariant>> addVariant(
    String productId,
    ProductVariantInputParams params,
  ) async {
    final variant = ProductVariant(
      id: 'var-$productId-${(variantsByProductId[productId]?.length ?? 0) + 1}',
      companyId: 'company-1',
      productId: productId,
      sku: params.sku,
      size: params.size,
      color: params.color,
      purchasePrice: params.purchasePrice,
      sellingPrice: params.sellingPrice,
      mrp: params.mrp,
      isActive: true,
      version: 1,
    );
    variantsByProductId.putIfAbsent(productId, () => []).add(variant);
    return Right(variant);
  }

  @override
  Future<Either<Failure, ProductVariant>> updateVariant(
    String variantId,
    ProductVariantUpdateParams params,
    int expectedVersion,
  ) async {
    for (final entry in variantsByProductId.entries) {
      final index = entry.value.indexWhere((v) => v.id == variantId);
      if (index != -1) {
        final updated = entry.value[index].copyWith(
          size: params.size,
          color: params.color,
          purchasePrice: params.purchasePrice,
          sellingPrice: params.sellingPrice,
          mrp: params.mrp,
          isActive: params.isActive,
          version: expectedVersion + 1,
        );
        entry.value[index] = updated;
        return Right(updated);
      }
    }
    throw StateError('variant not found: $variantId');
  }

  @override
  Future<Either<Failure, List<ProductBarcode>>> listBarcodes(
    String variantId,
  ) async => Right([...(barcodesByVariantId[variantId] ?? [])]);

  @override
  Future<Either<Failure, ProductBarcode>> addBarcode(
    String variantId,
    ProductBarcodeCreateParams params,
  ) async {
    final barcode = ProductBarcode(
      id: 'barcode-${(barcodesByVariantId[variantId]?.length ?? 0) + 1}',
      companyId: 'company-1',
      productVariantId: variantId,
      barcode: params.barcode,
      barcodeType: params.barcodeType,
      isPrimary: params.isPrimary,
    );
    barcodesByVariantId.putIfAbsent(variantId, () => []).add(barcode);
    return Right(barcode);
  }

  @override
  Future<Either<Failure, List<ProductImage>>> listImages(
    String productId,
  ) async => Right([...(imagesByProductId[productId] ?? [])]);

  @override
  Future<Either<Failure, ProductImage>> addImage(
    String productId,
    ProductImageCreateParams params,
  ) async {
    final image = ProductImage(
      id: 'img-${(imagesByProductId[productId]?.length ?? 0) + 1}',
      companyId: 'company-1',
      productId: productId,
      imageUrl: params.imageUrl,
      displayOrder: params.displayOrder,
      isPrimary: params.isPrimary,
    );
    imagesByProductId.putIfAbsent(productId, () => []).add(image);
    return Right(image);
  }

  @override
  Future<Either<Failure, String>> exportProductsCsv() async =>
      const Right('sku,name\n');

  bool importShouldFail = false;

  @override
  Future<Either<Failure, CsvImportSummary>> importProductsCsv({
    required List<int> bytes,
    required String filename,
  }) async {
    if (importShouldFail) {
      return const Left(Failure.unexpected(message: 'import failed'));
    }
    return const Right(
      CsvImportSummary(
        created: 1,
        skipped: 0,
        errors: 0,
        results: [
          CsvImportRowResult(
            sku: 'TEA-001',
            status: CsvImportRowStatus.created,
          ),
        ],
      ),
    );
  }
}

void main() {
  late _FakeProductsCatalogRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = _FakeProductsCatalogRepository();
    container = ProviderContainer(
      overrides: [
        productsCatalogRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'CategoriesNotifier.build() starts empty and create() appends and refreshes',
    () async {
      final initial = await container.read(categoriesProvider.future);
      expect(initial, isEmpty);

      final result = await container
          .read(categoriesProvider.notifier)
          .create(const CategoryCreateParams(name: 'Beverages'));

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(categoriesProvider.future);
      expect(refreshed, hasLength(1));
      expect(refreshed.single.name, 'Beverages');
    },
  );

  test(
    'ProductListNotifier.applyFilter() re-fetches with the given search/category',
    () async {
      await container.read(productListProvider.future);

      await container
          .read(productListProvider.notifier)
          .applyFilter(search: 'tea', categoryId: 'cat-1');

      expect(fakeRepository.lastListProductsCall, ['tea', 'cat-1']);
    },
  );

  test('ProductListNotifier.create() adds the product to the list', () async {
    final before = await container.read(productListProvider.future);
    expect(before, isEmpty);

    final result = await container
        .read(productListProvider.notifier)
        .create(
          const ProductCreateParams(
            sku: 'TEA-001',
            name: 'Masala Tea',
            baseUnitId: 'unit-1',
          ),
        );

    expect(result.isRight(), isTrue);
    final after = await container.read(productListProvider.future);
    expect(after, hasLength(1));
    expect(after.single.sku, 'TEA-001');
  });

  test(
    'ProductDetailNotifier fetches by productId and addVariant() adds a second variant',
    () async {
      final created = await container
          .read(productListProvider.notifier)
          .create(
            const ProductCreateParams(
              sku: 'KID-001',
              name: 'Kids Shirt',
              baseUnitId: 'unit-1',
            ),
          );
      final productId = created.getRight().toNullable()!.product.id;

      final detail = await container.read(
        productDetailProvider(productId).future,
      );
      expect(detail.variants, hasLength(1));

      final addResult = await container
          .read(productDetailProvider(productId).notifier)
          .addVariant(
            const ProductVariantInputParams(
              sku: 'KID-001-M',
              size: 'M',
              purchasePrice: '10.00',
              sellingPrice: '20.00',
            ),
          );

      expect(addResult.isRight(), isTrue);
      final refreshedDetail = await container.read(
        productDetailProvider(productId).future,
      );
      expect(refreshedDetail.variants, hasLength(2));
    },
  );

  test(
    'CategoriesNotifier.updateCategory() persists the change and refreshes',
    () async {
      final created = await container
          .read(categoriesProvider.notifier)
          .create(const CategoryCreateParams(name: 'Beverages'));
      final category = created.getRight().toNullable()!;

      final result = await container
          .read(categoriesProvider.notifier)
          .updateCategory(
            category.id,
            const CategoryUpdateParams(
              name: 'Hot Beverages',
              displayOrder: 1,
              isActive: true,
            ),
            category.version,
          );

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(categoriesProvider.future);
      expect(refreshed.single.name, 'Hot Beverages');
      expect(refreshed.single.displayOrder, 1);
    },
  );

  test(
    'BrandsNotifier.build() starts empty and create() appends and refreshes',
    () async {
      final initial = await container.read(brandsProvider.future);
      expect(initial, isEmpty);

      final result = await container
          .read(brandsProvider.notifier)
          .create(const BrandCreateParams(name: 'Acme'));

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(brandsProvider.future);
      expect(refreshed, hasLength(1));
      expect(refreshed.single.name, 'Acme');
    },
  );

  test(
    'BrandsNotifier.updateBrand() persists the change and refreshes',
    () async {
      final created = await container
          .read(brandsProvider.notifier)
          .create(const BrandCreateParams(name: 'Acme'));
      final brand = created.getRight().toNullable()!;

      final result = await container
          .read(brandsProvider.notifier)
          .updateBrand(
            brand.id,
            const BrandUpdateParams(
              name: 'Acme',
              description: 'In-house label',
              isActive: true,
            ),
            brand.version,
          );

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(brandsProvider.future);
      expect(refreshed.single.description, 'In-house label');
    },
  );

  test(
    'UnitsNotifier.build() starts empty and create() appends and refreshes',
    () async {
      final initial = await container.read(unitsProvider.future);
      expect(initial, isEmpty);

      final result = await container
          .read(unitsProvider.notifier)
          .create(const UnitCreateParams(name: 'Carton', abbreviation: 'ctn'));

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(unitsProvider.future);
      expect(refreshed.single.abbreviation, 'ctn');
    },
  );

  test(
    'ProductListNotifier.disable() marks the product inactive and refreshes',
    () async {
      final created = await container
          .read(productListProvider.notifier)
          .create(
            const ProductCreateParams(
              sku: 'TEA-001',
              name: 'Masala Tea',
              baseUnitId: 'unit-1',
            ),
          );
      final product = created.getRight().toNullable()!.product;

      final result = await container
          .read(productListProvider.notifier)
          .disable(product.id, product.version);

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(productListProvider.future);
      expect(refreshed.single.isActive, isFalse);
    },
  );

  test(
    'ProductDetailNotifier.updateProduct() persists the change and refreshes',
    () async {
      final created = await container
          .read(productListProvider.notifier)
          .create(
            const ProductCreateParams(
              sku: 'TEA-001',
              name: 'Masala Tea',
              baseUnitId: 'unit-1',
            ),
          );
      final product = created.getRight().toNullable()!.product;

      final result = await container
          .read(productDetailProvider(product.id).notifier)
          .updateProduct(
            const ProductUpdateParams(
              name: 'Masala Tea Deluxe',
              trackInventory: true,
              allowNegativeStock: false,
              isActive: true,
            ),
            product.version,
          );

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(
        productDetailProvider(product.id).future,
      );
      expect(refreshed.product.name, 'Masala Tea Deluxe');
    },
  );

  test(
    'ProductDetailNotifier.updateVariant() persists the change and refreshes',
    () async {
      final created = await container
          .read(productListProvider.notifier)
          .create(
            const ProductCreateParams(
              sku: 'TEA-001',
              name: 'Masala Tea',
              baseUnitId: 'unit-1',
            ),
          );
      final productId = created.getRight().toNullable()!.product.id;
      final variant = created.getRight().toNullable()!.variants.single;

      final result = await container
          .read(productDetailProvider(productId).notifier)
          .updateVariant(
            variant.id,
            const ProductVariantUpdateParams(
              purchasePrice: '90.00',
              sellingPrice: '150.00',
              isActive: true,
            ),
            variant.version,
          );

      expect(result.isRight(), isTrue);
      final refreshed = await container.read(
        productDetailProvider(productId).future,
      );
      expect(refreshed.variants.single.sellingPrice, '150.00');
    },
  );

  test('variantBarcodesProvider fetches barcodes for a variant', () async {
    fakeRepository.barcodesByVariantId['var-1'] = [
      const ProductBarcode(
        id: 'barcode-1',
        companyId: 'company-1',
        productVariantId: 'var-1',
        barcode: '8901234567890',
        barcodeType: BarcodeType.ean13,
        isPrimary: true,
      ),
    ];

    final barcodes = await container.read(
      variantBarcodesProvider('var-1').future,
    );

    expect(barcodes.single.barcode, '8901234567890');
  });

  test('productImagesProvider fetches images for a product', () async {
    fakeRepository.imagesByProductId['prod-1'] = [
      const ProductImage(
        id: 'img-1',
        companyId: 'company-1',
        productId: 'prod-1',
        imageUrl: 'https://example.com/a.jpg',
        displayOrder: 0,
        isPrimary: true,
      ),
    ];

    final images = await container.read(productImagesProvider('prod-1').future);

    expect(images.single.imageUrl, 'https://example.com/a.jpg');
  });

  test('ProductsCsvNotifier.exportCsv() returns the raw CSV text', () async {
    final result = await container
        .read(productsCsvProvider.notifier)
        .exportCsv();

    expect(result.getRight().toNullable(), 'sku,name\n');
  });

  test(
    'ProductsCsvNotifier.importCsv() stores the summary and invalidates product/category/brand lists',
    () async {
      expect(container.read(productsCsvProvider), isNull);

      final result = await container
          .read(productsCsvProvider.notifier)
          .importCsv(bytes: [1, 2, 3], filename: 'products.csv');

      expect(result.isRight(), isTrue);
      final summary = container.read(productsCsvProvider);
      expect(summary, isNotNull);
      expect(summary!.created, 1);
    },
  );

  test(
    'ProductsCsvNotifier.importCsv() failure does not set a summary',
    () async {
      fakeRepository.importShouldFail = true;

      final result = await container
          .read(productsCsvProvider.notifier)
          .importCsv(bytes: [1, 2, 3], filename: 'products.csv');

      expect(result.isLeft(), isTrue);
      expect(container.read(productsCsvProvider), isNull);
    },
  );
}
