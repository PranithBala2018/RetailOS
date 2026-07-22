import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
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
import '../datasources/products_catalog_remote_data_source.dart';

class ProductsCatalogRepositoryImpl implements ProductsCatalogRepository {
  ProductsCatalogRepositoryImpl(this._remoteDataSource);

  final ProductsCatalogRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Category>>> listCategories() =>
      _guard(_remoteDataSource.listCategories);

  @override
  Future<Either<Failure, Category>> createCategory(
    CategoryCreateParams params,
  ) => _guard(() => _remoteDataSource.createCategory(params));

  @override
  Future<Either<Failure, Category>> updateCategory(
    String categoryId,
    CategoryUpdateParams params,
    int expectedVersion,
  ) => _guard(
    () => _remoteDataSource.updateCategory(categoryId, params, expectedVersion),
  );

  @override
  Future<Either<Failure, List<Brand>>> listBrands() =>
      _guard(_remoteDataSource.listBrands);

  @override
  Future<Either<Failure, Brand>> createBrand(BrandCreateParams params) =>
      _guard(() => _remoteDataSource.createBrand(params));

  @override
  Future<Either<Failure, Brand>> updateBrand(
    String brandId,
    BrandUpdateParams params,
    int expectedVersion,
  ) => _guard(
    () => _remoteDataSource.updateBrand(brandId, params, expectedVersion),
  );

  @override
  Future<Either<Failure, List<UnitOfMeasure>>> listUnits() =>
      _guard(_remoteDataSource.listUnits);

  @override
  Future<Either<Failure, UnitOfMeasure>> createUnit(UnitCreateParams params) =>
      _guard(() => _remoteDataSource.createUnit(params));

  @override
  Future<Either<Failure, List<Product>>> listProducts({
    String? search,
    String? categoryId,
  }) => _guard(
    () =>
        _remoteDataSource.listProducts(search: search, categoryId: categoryId),
  );

  @override
  Future<Either<Failure, ProductWithVariants>> createProduct(
    ProductCreateParams params,
  ) => _guard(() => _remoteDataSource.createProduct(params));

  @override
  Future<Either<Failure, ProductWithVariants>> getProduct(String productId) =>
      _guard(() => _remoteDataSource.getProduct(productId));

  @override
  Future<Either<Failure, Product>> updateProduct(
    String productId,
    ProductUpdateParams params,
    int expectedVersion,
  ) => _guard(
    () => _remoteDataSource.updateProduct(productId, params, expectedVersion),
  );

  @override
  Future<Either<Failure, Unit>> disableProduct(
    String productId,
    int expectedVersion,
  ) => _guard(
    () => _remoteDataSource
        .disableProduct(productId, expectedVersion)
        .then((_) => unit),
  );

  @override
  Future<Either<Failure, List<ProductVariant>>> listVariants(
    String productId,
  ) => _guard(() => _remoteDataSource.listVariants(productId));

  @override
  Future<Either<Failure, ProductVariant>> addVariant(
    String productId,
    ProductVariantInputParams params,
  ) => _guard(() => _remoteDataSource.addVariant(productId, params));

  @override
  Future<Either<Failure, ProductVariant>> updateVariant(
    String variantId,
    ProductVariantUpdateParams params,
    int expectedVersion,
  ) => _guard(
    () => _remoteDataSource.updateVariant(variantId, params, expectedVersion),
  );

  @override
  Future<Either<Failure, List<ProductBarcode>>> listBarcodes(
    String variantId,
  ) => _guard(() => _remoteDataSource.listBarcodes(variantId));

  @override
  Future<Either<Failure, ProductBarcode>> addBarcode(
    String variantId,
    ProductBarcodeCreateParams params,
  ) => _guard(() => _remoteDataSource.addBarcode(variantId, params));

  @override
  Future<Either<Failure, List<ProductImage>>> listImages(String productId) =>
      _guard(() => _remoteDataSource.listImages(productId));

  @override
  Future<Either<Failure, ProductImage>> addImage(
    String productId,
    ProductImageCreateParams params,
  ) => _guard(() => _remoteDataSource.addImage(productId, params));

  @override
  Future<Either<Failure, String>> exportProductsCsv() =>
      _guard(_remoteDataSource.exportProductsCsv);

  @override
  Future<Either<Failure, CsvImportSummary>> importProductsCsv({
    required List<int> bytes,
    required String filename,
  }) => _guard(
    () => _remoteDataSource.importProductsCsv(bytes: bytes, filename: filename),
  );
}
