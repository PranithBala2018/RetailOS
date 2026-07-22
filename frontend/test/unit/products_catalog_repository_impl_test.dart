import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/products_catalog/data/datasources/products_catalog_remote_data_source.dart';
import 'package:retailos/features/products_catalog/data/repositories/products_catalog_repository_impl.dart';
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

class _MockProductsCatalogRemoteDataSource extends Mock
    implements ProductsCatalogRemoteDataSource {}

void main() {
  late _MockProductsCatalogRemoteDataSource dataSource;
  late ProductsCatalogRepositoryImpl repository;

  const category = Category(
    id: 'cat-1',
    companyId: 'company-1',
    name: 'T-Shirts',
    displayOrder: 0,
    isActive: true,
    version: 1,
  );
  const brand = Brand(
    id: 'brand-1',
    companyId: 'company-1',
    name: 'Acme',
    isActive: true,
    version: 1,
  );
  const unit = UnitOfMeasure(
    id: 'unit-1',
    name: 'Pieces',
    abbreviation: 'pcs',
    isSystem: true,
  );
  const product = Product(
    id: 'prod-1',
    companyId: 'company-1',
    sku: 'TEA-001',
    name: 'Masala Tea',
    baseUnitId: 'unit-1',
    hasVariants: false,
    trackInventory: true,
    allowNegativeStock: false,
    isActive: true,
    version: 1,
  );
  const variant = ProductVariant(
    id: 'var-1',
    companyId: 'company-1',
    productId: 'prod-1',
    sku: 'TEA-001',
    purchasePrice: '90.00',
    sellingPrice: '120.00',
    isActive: true,
    version: 1,
  );
  const barcode = ProductBarcode(
    id: 'barcode-1',
    companyId: 'company-1',
    productVariantId: 'var-1',
    barcode: '8901234567890',
    barcodeType: BarcodeType.ean13,
    isPrimary: true,
  );
  const image = ProductImage(
    id: 'img-1',
    companyId: 'company-1',
    productId: 'prod-1',
    imageUrl: 'https://example.com/a.jpg',
    displayOrder: 0,
    isPrimary: true,
  );

  setUpAll(() {
    registerFallbackValue(const CategoryCreateParams(name: ''));
    registerFallbackValue(
      const CategoryUpdateParams(name: '', displayOrder: 0, isActive: true),
    );
    registerFallbackValue(const BrandCreateParams(name: ''));
    registerFallbackValue(const BrandUpdateParams(name: '', isActive: true));
    registerFallbackValue(const UnitCreateParams(name: '', abbreviation: ''));
    registerFallbackValue(
      const ProductCreateParams(sku: '', name: '', baseUnitId: ''),
    );
    registerFallbackValue(
      const ProductUpdateParams(
        name: '',
        trackInventory: true,
        allowNegativeStock: false,
        isActive: true,
      ),
    );
    registerFallbackValue(
      const ProductVariantInputParams(
        sku: '',
        purchasePrice: '0',
        sellingPrice: '0',
      ),
    );
    registerFallbackValue(
      const ProductVariantUpdateParams(
        purchasePrice: '0',
        sellingPrice: '0',
        isActive: true,
      ),
    );
    registerFallbackValue(const ProductBarcodeCreateParams(barcode: ''));
    registerFallbackValue(const ProductImageCreateParams(imageUrl: ''));
  });

  setUp(() {
    dataSource = _MockProductsCatalogRemoteDataSource();
    repository = ProductsCatalogRepositoryImpl(dataSource);
  });

  test('listCategories returns the data source result on success', () async {
    when(() => dataSource.listCategories()).thenAnswer((_) async => [category]);

    final result = await repository.listCategories();

    expect(result.getRight().toNullable(), [category]);
  });

  test('listCategories maps a connection error to Failure.network', () async {
    when(() => dataSource.listCategories()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/categories'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.listCategories();

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test(
    'listCategories maps any other thrown error to Failure.unexpected',
    () async {
      when(() => dataSource.listCategories()).thenThrow(StateError('boom'));

      final result = await repository.listCategories();

      expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
    },
  );

  test(
    'createCategory maps a 422 (duplicate name) to Failure.validation',
    () async {
      when(() => dataSource.createCategory(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/categories'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/categories'),
            statusCode: 422,
            data: {
              'success': false,
              'message': "Category 'Shoes' already exists",
              'errors': <Object?>[],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.createCategory(
        const CategoryCreateParams(name: 'Shoes'),
      );

      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    },
  );

  test('exportProductsCsv returns the raw CSV text on success', () async {
    when(
      () => dataSource.exportProductsCsv(),
    ).thenAnswer((_) async => 'sku,name\n');

    final result = await repository.exportProductsCsv();

    expect(result.getRight().toNullable(), 'sku,name\n');
  });

  test(
    'disableProduct maps a 409 (stale version) to Failure.conflict',
    () async {
      when(() => dataSource.disableProduct(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/products/prod-1'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/products/prod-1'),
            statusCode: 409,
            data: {
              'success': false,
              'message': 'Product was modified by someone else',
              'errors': <Object?>[],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.disableProduct('prod-1', 1);

      expect(result.getLeft().toNullable(), isA<ConflictFailure>());
    },
  );

  test('updateCategory returns the updated category on success', () async {
    when(
      () => dataSource.updateCategory(any(), any(), any()),
    ).thenAnswer((_) async => category);

    final result = await repository.updateCategory(
      'cat-1',
      const CategoryUpdateParams(
        name: 'T-Shirts',
        displayOrder: 0,
        isActive: true,
      ),
      1,
    );

    expect(result.getRight().toNullable(), category);
  });

  test('listBrands returns the data source result on success', () async {
    when(() => dataSource.listBrands()).thenAnswer((_) async => [brand]);

    final result = await repository.listBrands();

    expect(result.getRight().toNullable(), [brand]);
  });

  test('createBrand returns the created brand on success', () async {
    when(() => dataSource.createBrand(any())).thenAnswer((_) async => brand);

    final result = await repository.createBrand(
      const BrandCreateParams(name: 'Acme'),
    );

    expect(result.getRight().toNullable(), brand);
  });

  test('updateBrand returns the updated brand on success', () async {
    when(
      () => dataSource.updateBrand(any(), any(), any()),
    ).thenAnswer((_) async => brand);

    final result = await repository.updateBrand(
      'brand-1',
      const BrandUpdateParams(name: 'Acme', isActive: true),
      1,
    );

    expect(result.getRight().toNullable(), brand);
  });

  test('listUnits returns the data source result on success', () async {
    when(() => dataSource.listUnits()).thenAnswer((_) async => [unit]);

    final result = await repository.listUnits();

    expect(result.getRight().toNullable(), [unit]);
  });

  test('createUnit returns the created unit on success', () async {
    when(() => dataSource.createUnit(any())).thenAnswer((_) async => unit);

    final result = await repository.createUnit(
      const UnitCreateParams(name: 'Pieces', abbreviation: 'pcs'),
    );

    expect(result.getRight().toNullable(), unit);
  });

  test(
    'listProducts forwards search/categoryId and returns the result',
    () async {
      when(
        () => dataSource.listProducts(
          search: any(named: 'search'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => [product]);

      final result = await repository.listProducts(
        search: 'tea',
        categoryId: 'cat-1',
      );

      expect(result.getRight().toNullable(), [product]);
    },
  );

  test(
    'createProduct returns the product-with-variants result on success',
    () async {
      final withVariants = ProductWithVariants(
        product: product,
        variants: [variant],
      );
      when(
        () => dataSource.createProduct(any()),
      ).thenAnswer((_) async => withVariants);

      final result = await repository.createProduct(
        const ProductCreateParams(
          sku: 'TEA-001',
          name: 'Masala Tea',
          baseUnitId: 'unit-1',
        ),
      );

      expect(result.getRight().toNullable(), withVariants);
    },
  );

  test(
    'getProduct returns the product-with-variants result on success',
    () async {
      final withVariants = ProductWithVariants(
        product: product,
        variants: [variant],
      );
      when(
        () => dataSource.getProduct(any()),
      ).thenAnswer((_) async => withVariants);

      final result = await repository.getProduct('prod-1');

      expect(result.getRight().toNullable(), withVariants);
    },
  );

  test('updateProduct returns the updated product on success', () async {
    when(
      () => dataSource.updateProduct(any(), any(), any()),
    ).thenAnswer((_) async => product);

    final result = await repository.updateProduct(
      'prod-1',
      const ProductUpdateParams(
        name: 'Masala Tea',
        trackInventory: true,
        allowNegativeStock: false,
        isActive: true,
      ),
      1,
    );

    expect(result.getRight().toNullable(), product);
  });

  test('disableProduct returns Right(unit) on success', () async {
    when(
      () => dataSource.disableProduct(any(), any()),
    ).thenAnswer((_) async {});

    final result = await repository.disableProduct('prod-1', 1);

    expect(result.isRight(), isTrue);
  });

  test('listVariants returns the data source result on success', () async {
    when(
      () => dataSource.listVariants(any()),
    ).thenAnswer((_) async => [variant]);

    final result = await repository.listVariants('prod-1');

    expect(result.getRight().toNullable(), [variant]);
  });

  test('addVariant returns the created variant on success', () async {
    when(
      () => dataSource.addVariant(any(), any()),
    ).thenAnswer((_) async => variant);

    final result = await repository.addVariant(
      'prod-1',
      const ProductVariantInputParams(
        sku: 'TEA-001',
        purchasePrice: '90.00',
        sellingPrice: '120.00',
      ),
    );

    expect(result.getRight().toNullable(), variant);
  });

  test('updateVariant returns the updated variant on success', () async {
    when(
      () => dataSource.updateVariant(any(), any(), any()),
    ).thenAnswer((_) async => variant);

    final result = await repository.updateVariant(
      'var-1',
      const ProductVariantUpdateParams(
        purchasePrice: '90.00',
        sellingPrice: '120.00',
        isActive: true,
      ),
      1,
    );

    expect(result.getRight().toNullable(), variant);
  });

  test('listBarcodes returns the data source result on success', () async {
    when(
      () => dataSource.listBarcodes(any()),
    ).thenAnswer((_) async => [barcode]);

    final result = await repository.listBarcodes('var-1');

    expect(result.getRight().toNullable(), [barcode]);
  });

  test('addBarcode returns the created barcode on success', () async {
    when(
      () => dataSource.addBarcode(any(), any()),
    ).thenAnswer((_) async => barcode);

    final result = await repository.addBarcode(
      'var-1',
      const ProductBarcodeCreateParams(
        barcode: '8901234567890',
        barcodeType: BarcodeType.ean13,
      ),
    );

    expect(result.getRight().toNullable(), barcode);
  });

  test('listImages returns the data source result on success', () async {
    when(() => dataSource.listImages(any())).thenAnswer((_) async => [image]);

    final result = await repository.listImages('prod-1');

    expect(result.getRight().toNullable(), [image]);
  });

  test('addImage returns the created image on success', () async {
    when(
      () => dataSource.addImage(any(), any()),
    ).thenAnswer((_) async => image);

    final result = await repository.addImage(
      'prod-1',
      const ProductImageCreateParams(imageUrl: 'https://example.com/a.jpg'),
    );

    expect(result.getRight().toNullable(), image);
  });

  test('importProductsCsv returns the summary on success', () async {
    const summary = CsvImportSummary(
      created: 1,
      skipped: 0,
      errors: 0,
      results: [],
    );
    when(
      () => dataSource.importProductsCsv(
        bytes: any(named: 'bytes'),
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) async => summary);

    final result = await repository.importProductsCsv(
      bytes: [1, 2, 3],
      filename: 'products.csv',
    );

    expect(result.getRight().toNullable(), summary);
  });

  test(
    'importProductsCsv maps any other thrown error to Failure.unexpected',
    () async {
      when(
        () => dataSource.importProductsCsv(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
        ),
      ).thenThrow(StateError('boom'));

      final result = await repository.importProductsCsv(
        bytes: [1, 2, 3],
        filename: 'products.csv',
      );

      expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
    },
  );
}
