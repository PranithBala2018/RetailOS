import 'package:dio/dio.dart';

import '../../domain/entities/barcode_type.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/csv_import_summary.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_barcode.dart';
import '../../domain/entities/product_gender.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_with_variants.dart';
import '../../domain/entities/unit_of_measure.dart';
import '../../domain/repositories/products_catalog_repository.dart';

/// Raw API calls only — parses the `{"success", "message", "data"}`
/// envelope (API.md) directly into domain entities, matching the pattern
/// set in features/auth and features/dashboard.
class ProductsCatalogRemoteDataSource {
  ProductsCatalogRemoteDataSource(this._dio);

  final Dio _dio;

  // --- Categories ---

  Future<List<Category>> listCategories() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/categories');
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_categoryFromJson).toList();
  }

  Future<Category> createCategory(CategoryCreateParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/categories',
      data: {
        'name': params.name,
        'parent_category_id': params.parentCategoryId,
        'description': params.description,
        'image_url': params.imageUrl,
        'display_order': params.displayOrder,
      },
    );
    return _categoryFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<Category> updateCategory(
    String categoryId,
    CategoryUpdateParams params,
    int expectedVersion,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/categories/$categoryId',
      queryParameters: {'expected_version': expectedVersion},
      data: {
        'name': params.name,
        'parent_category_id': params.parentCategoryId,
        'description': params.description,
        'image_url': params.imageUrl,
        'display_order': params.displayOrder,
        'is_active': params.isActive,
      },
    );
    return _categoryFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Category _categoryFromJson(Map<String, dynamic> data) => Category(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    name: data['name'] as String,
    parentCategoryId: data['parent_category_id'] as String?,
    description: data['description'] as String?,
    imageUrl: data['image_url'] as String?,
    displayOrder: data['display_order'] as int,
    isActive: data['is_active'] as bool,
    version: data['version'] as int,
  );

  // --- Brands ---

  Future<List<Brand>> listBrands() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/brands');
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_brandFromJson).toList();
  }

  Future<Brand> createBrand(BrandCreateParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/brands',
      data: {
        'name': params.name,
        'logo_url': params.logoUrl,
        'description': params.description,
      },
    );
    return _brandFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<Brand> updateBrand(
    String brandId,
    BrandUpdateParams params,
    int expectedVersion,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/brands/$brandId',
      queryParameters: {'expected_version': expectedVersion},
      data: {
        'name': params.name,
        'logo_url': params.logoUrl,
        'description': params.description,
        'is_active': params.isActive,
      },
    );
    return _brandFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Brand _brandFromJson(Map<String, dynamic> data) => Brand(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    name: data['name'] as String,
    logoUrl: data['logo_url'] as String?,
    description: data['description'] as String?,
    isActive: data['is_active'] as bool,
    version: data['version'] as int,
  );

  // --- Units ---

  Future<List<UnitOfMeasure>> listUnits() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/units');
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_unitFromJson).toList();
  }

  Future<UnitOfMeasure> createUnit(UnitCreateParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/units',
      data: {'name': params.name, 'abbreviation': params.abbreviation},
    );
    return _unitFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  UnitOfMeasure _unitFromJson(Map<String, dynamic> data) => UnitOfMeasure(
    id: data['id'] as String,
    companyId: data['company_id'] as String?,
    name: data['name'] as String,
    abbreviation: data['abbreviation'] as String,
    isSystem: data['is_system'] as bool,
  );

  // --- Products ---

  Future<List<Product>> listProducts({
    String? search,
    String? categoryId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'category_id': ?categoryId,
      },
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_productFromJson).toList();
  }

  Future<ProductWithVariants> createProduct(ProductCreateParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/products',
      data: {
        'sku': params.sku,
        'name': params.name,
        'description': params.description,
        'category_id': params.categoryId,
        'brand_id': params.brandId,
        'base_unit_id': params.baseUnitId,
        'gender': params.gender?.wireValue,
        'season': params.season,
        'age_group': params.ageGroup,
        'hsn_code': params.hsnCode,
        'tax_percent': params.taxPercent,
        'track_inventory': params.trackInventory,
        'allow_negative_stock': params.allowNegativeStock,
        'low_stock_threshold': params.lowStockThreshold,
        'has_variants': params.hasVariants,
        'purchase_price': params.purchasePrice,
        'selling_price': params.sellingPrice,
        'mrp': params.mrp,
        'variants': params.variants.map(_variantInputToJson).toList(),
      },
    );
    return _productWithVariantsFromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<ProductWithVariants> getProduct(String productId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products/$productId',
    );
    return _productWithVariantsFromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  }

  Future<Product> updateProduct(
    String productId,
    ProductUpdateParams params,
    int expectedVersion,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/products/$productId',
      queryParameters: {'expected_version': expectedVersion},
      data: {
        'name': params.name,
        'description': params.description,
        'category_id': params.categoryId,
        'brand_id': params.brandId,
        'gender': params.gender?.wireValue,
        'season': params.season,
        'age_group': params.ageGroup,
        'hsn_code': params.hsnCode,
        'tax_percent': params.taxPercent,
        'track_inventory': params.trackInventory,
        'allow_negative_stock': params.allowNegativeStock,
        'low_stock_threshold': params.lowStockThreshold,
        'is_active': params.isActive,
      },
    );
    return _productFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> disableProduct(String productId, int expectedVersion) async {
    await _dio.delete<void>(
      '/api/v1/products/$productId',
      queryParameters: {'expected_version': expectedVersion},
    );
  }

  Product _productFromJson(Map<String, dynamic> data) => Product(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    sku: data['sku'] as String,
    name: data['name'] as String,
    description: data['description'] as String?,
    categoryId: data['category_id'] as String?,
    brandId: data['brand_id'] as String?,
    baseUnitId: data['base_unit_id'] as String,
    gender: ProductGender.fromWireOrNull(data['gender'] as String?),
    season: data['season'] as String?,
    ageGroup: data['age_group'] as String?,
    hsnCode: data['hsn_code'] as String?,
    taxPercent: data['tax_percent'] as String?,
    hasVariants: data['has_variants'] as bool,
    trackInventory: data['track_inventory'] as bool,
    allowNegativeStock: data['allow_negative_stock'] as bool,
    lowStockThreshold: data['low_stock_threshold'] as int?,
    isActive: data['is_active'] as bool,
    version: data['version'] as int,
  );

  ProductWithVariants _productWithVariantsFromJson(Map<String, dynamic> data) =>
      ProductWithVariants(
        product: _productFromJson(data['product'] as Map<String, dynamic>),
        variants: (data['variants'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_variantFromJson)
            .toList(),
      );

  // --- Product Variants ---

  Future<List<ProductVariant>> listVariants(String productId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products/$productId/variants',
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_variantFromJson).toList();
  }

  Future<ProductVariant> addVariant(
    String productId,
    ProductVariantInputParams params,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/products/$productId/variants',
      data: _variantInputToJson(params),
    );
    return _variantFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<ProductVariant> updateVariant(
    String variantId,
    ProductVariantUpdateParams params,
    int expectedVersion,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/product-variants/$variantId',
      queryParameters: {'expected_version': expectedVersion},
      data: {
        'size': params.size,
        'color': params.color,
        'purchase_price': params.purchasePrice,
        'selling_price': params.sellingPrice,
        'mrp': params.mrp,
        'is_active': params.isActive,
      },
    );
    return _variantFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _variantInputToJson(ProductVariantInputParams params) =>
      {
        'sku': params.sku,
        'size': params.size,
        'color': params.color,
        'purchase_price': params.purchasePrice,
        'selling_price': params.sellingPrice,
        'mrp': params.mrp,
      };

  ProductVariant _variantFromJson(Map<String, dynamic> data) => ProductVariant(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    productId: data['product_id'] as String,
    sku: data['sku'] as String,
    size: data['size'] as String?,
    color: data['color'] as String?,
    variantName: data['variant_name'] as String?,
    purchasePrice: data['purchase_price'] as String,
    sellingPrice: data['selling_price'] as String,
    mrp: data['mrp'] as String?,
    isActive: data['is_active'] as bool,
    version: data['version'] as int,
  );

  // --- Product Barcodes ---

  Future<List<ProductBarcode>> listBarcodes(String variantId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/product-variants/$variantId/barcodes',
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_barcodeFromJson).toList();
  }

  Future<ProductBarcode> addBarcode(
    String variantId,
    ProductBarcodeCreateParams params,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/product-variants/$variantId/barcodes',
      data: {
        'barcode': params.barcode,
        'barcode_type': params.barcodeType.wireValue,
        'is_primary': params.isPrimary,
      },
    );
    return _barcodeFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  ProductBarcode _barcodeFromJson(Map<String, dynamic> data) => ProductBarcode(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    productVariantId: data['product_variant_id'] as String,
    barcode: data['barcode'] as String,
    barcodeType: BarcodeType.fromWire(data['barcode_type'] as String),
    isPrimary: data['is_primary'] as bool,
  );

  // --- Product Images ---

  Future<List<ProductImage>> listImages(String productId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/products/$productId/images',
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_imageFromJson).toList();
  }

  Future<ProductImage> addImage(
    String productId,
    ProductImageCreateParams params,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/products/$productId/images',
      data: {
        'image_url': params.imageUrl,
        'display_order': params.displayOrder,
        'is_primary': params.isPrimary,
      },
    );
    return _imageFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  ProductImage _imageFromJson(Map<String, dynamic> data) => ProductImage(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    productId: data['product_id'] as String,
    imageUrl: data['image_url'] as String,
    displayOrder: data['display_order'] as int,
    isPrimary: data['is_primary'] as bool,
  );

  // --- CSV import/export ---

  Future<String> exportProductsCsv() async {
    final response = await _dio.get<String>(
      '/api/v1/products/export',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data!;
  }

  Future<CsvImportSummary> importProductsCsv({
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/products/import',
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (r) => CsvImportRowResult(
            sku: r['sku'] as String,
            status: CsvImportRowStatus.fromWire(r['status'] as String),
            message: r['message'] as String?,
          ),
        )
        .toList();
    return CsvImportSummary(
      created: data['created'] as int,
      skipped: data['skipped'] as int,
      errors: data['errors'] as int,
      results: results,
    );
  }
}
