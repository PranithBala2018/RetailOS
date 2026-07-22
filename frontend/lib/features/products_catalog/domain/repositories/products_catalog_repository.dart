import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/barcode_type.dart';
import '../entities/brand.dart';
import '../entities/category.dart';
import '../entities/csv_import_summary.dart';
import '../entities/product.dart';
import '../entities/product_barcode.dart';
import '../entities/product_gender.dart';
import '../entities/product_image.dart';
import '../entities/product_variant.dart';
import '../entities/product_with_variants.dart';
import '../entities/unit_of_measure.dart';

class CategoryCreateParams {
  const CategoryCreateParams({
    required this.name,
    this.parentCategoryId,
    this.description,
    this.imageUrl,
    this.displayOrder = 0,
  });

  final String name;
  final String? parentCategoryId;
  final String? description;
  final String? imageUrl;
  final int displayOrder;
}

class CategoryUpdateParams {
  const CategoryUpdateParams({
    required this.name,
    this.parentCategoryId,
    this.description,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  final String name;
  final String? parentCategoryId;
  final String? description;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
}

class BrandCreateParams {
  const BrandCreateParams({required this.name, this.logoUrl, this.description});

  final String name;
  final String? logoUrl;
  final String? description;
}

class BrandUpdateParams {
  const BrandUpdateParams({
    required this.name,
    this.logoUrl,
    this.description,
    required this.isActive,
  });

  final String name;
  final String? logoUrl;
  final String? description;
  final bool isActive;
}

class UnitCreateParams {
  const UnitCreateParams({required this.name, required this.abbreviation});

  final String name;
  final String abbreviation;
}

/// One variant row — used both nested inside [ProductCreateParams] (for
/// `hasVariants=true` products) and standalone via `addVariant`.
class ProductVariantInputParams {
  const ProductVariantInputParams({
    required this.sku,
    this.size,
    this.color,
    required this.purchasePrice,
    required this.sellingPrice,
    this.mrp,
  });

  final String sku;
  final String? size;
  final String? color;
  final String purchasePrice;
  final String sellingPrice;
  final String? mrp;
}

class ProductVariantUpdateParams {
  const ProductVariantUpdateParams({
    this.size,
    this.color,
    required this.purchasePrice,
    required this.sellingPrice,
    this.mrp,
    required this.isActive,
  });

  final String? size;
  final String? color;
  final String purchasePrice;
  final String sellingPrice;
  final String? mrp;
  final bool isActive;
}

class ProductCreateParams {
  const ProductCreateParams({
    required this.sku,
    required this.name,
    this.description,
    this.categoryId,
    this.brandId,
    required this.baseUnitId,
    this.gender,
    this.season,
    this.ageGroup,
    this.hsnCode,
    this.taxPercent,
    this.trackInventory = true,
    this.allowNegativeStock = false,
    this.lowStockThreshold,
    this.hasVariants = false,
    this.purchasePrice = '0',
    this.sellingPrice = '0',
    this.mrp,
    this.variants = const [],
  });

  final String sku;
  final String name;
  final String? description;
  final String? categoryId;
  final String? brandId;
  final String baseUnitId;
  final ProductGender? gender;
  final String? season;
  final String? ageGroup;
  final String? hsnCode;
  final String? taxPercent;
  final bool trackInventory;
  final bool allowNegativeStock;
  final int? lowStockThreshold;
  final bool hasVariants;
  final String purchasePrice;
  final String sellingPrice;
  final String? mrp;
  final List<ProductVariantInputParams> variants;
}

class ProductUpdateParams {
  const ProductUpdateParams({
    required this.name,
    this.description,
    this.categoryId,
    this.brandId,
    this.gender,
    this.season,
    this.ageGroup,
    this.hsnCode,
    this.taxPercent,
    required this.trackInventory,
    required this.allowNegativeStock,
    this.lowStockThreshold,
    required this.isActive,
  });

  final String name;
  final String? description;
  final String? categoryId;
  final String? brandId;
  final ProductGender? gender;
  final String? season;
  final String? ageGroup;
  final String? hsnCode;
  final String? taxPercent;
  final bool trackInventory;
  final bool allowNegativeStock;
  final int? lowStockThreshold;
  final bool isActive;
}

class ProductBarcodeCreateParams {
  const ProductBarcodeCreateParams({
    required this.barcode,
    this.barcodeType = BarcodeType.internal,
    this.isPrimary = false,
  });

  final String barcode;
  final BarcodeType barcodeType;
  final bool isPrimary;
}

class ProductImageCreateParams {
  const ProductImageCreateParams({
    required this.imageUrl,
    this.displayOrder = 0,
    this.isPrimary = false,
  });

  final String imageUrl;
  final int displayOrder;
  final bool isPrimary;
}

/// Client for the Products & Catalog backend module (Categories, Brands,
/// Units, Products, Variants, Barcodes, Images, CSV import/export) — see
/// backend/app/modules/products_catalog/api.py for the exact wire
/// contract this mirrors.
abstract interface class ProductsCatalogRepository {
  Future<Either<Failure, List<Category>>> listCategories();
  Future<Either<Failure, Category>> createCategory(CategoryCreateParams params);
  Future<Either<Failure, Category>> updateCategory(
    String categoryId,
    CategoryUpdateParams params,
    int expectedVersion,
  );

  Future<Either<Failure, List<Brand>>> listBrands();
  Future<Either<Failure, Brand>> createBrand(BrandCreateParams params);
  Future<Either<Failure, Brand>> updateBrand(
    String brandId,
    BrandUpdateParams params,
    int expectedVersion,
  );

  Future<Either<Failure, List<UnitOfMeasure>>> listUnits();
  Future<Either<Failure, UnitOfMeasure>> createUnit(UnitCreateParams params);

  Future<Either<Failure, List<Product>>> listProducts({
    String? search,
    String? categoryId,
  });
  Future<Either<Failure, ProductWithVariants>> createProduct(
    ProductCreateParams params,
  );
  Future<Either<Failure, ProductWithVariants>> getProduct(String productId);
  Future<Either<Failure, Product>> updateProduct(
    String productId,
    ProductUpdateParams params,
    int expectedVersion,
  );
  Future<Either<Failure, Unit>> disableProduct(
    String productId,
    int expectedVersion,
  );

  Future<Either<Failure, List<ProductVariant>>> listVariants(String productId);
  Future<Either<Failure, ProductVariant>> addVariant(
    String productId,
    ProductVariantInputParams params,
  );
  Future<Either<Failure, ProductVariant>> updateVariant(
    String variantId,
    ProductVariantUpdateParams params,
    int expectedVersion,
  );

  Future<Either<Failure, List<ProductBarcode>>> listBarcodes(String variantId);
  Future<Either<Failure, ProductBarcode>> addBarcode(
    String variantId,
    ProductBarcodeCreateParams params,
  );

  Future<Either<Failure, List<ProductImage>>> listImages(String productId);
  Future<Either<Failure, ProductImage>> addImage(
    String productId,
    ProductImageCreateParams params,
  );

  /// Raw CSV text (see backend csv_io.py for the column format).
  Future<Either<Failure, String>> exportProductsCsv();

  Future<Either<Failure, CsvImportSummary>> importProductsCsv({
    required List<int> bytes,
    required String filename,
  });
}
