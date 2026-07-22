import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/products_catalog/data/datasources/products_catalog_remote_data_source.dart';
import 'package:retailos/features/products_catalog/domain/entities/barcode_type.dart';
import 'package:retailos/features/products_catalog/domain/entities/product_gender.dart';
import 'package:retailos/features/products_catalog/domain/repositories/products_catalog_repository.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late ProductsCatalogRemoteDataSource dataSource;
  Uri? lastRequestUri;
  Map<String, dynamic>? lastRequestBody;
  String? lastRequestBodyRaw;

  Future<void> respond(
    HttpRequest request,
    Object body, {
    String contentType = 'application/json',
  }) async {
    lastRequestUri = request.uri;
    if (request.method != 'GET') {
      final raw = await utf8.decoder.bind(request).join();
      lastRequestBodyRaw = raw;
      if (contentType == 'application/json' && raw.isNotEmpty) {
        try {
          lastRequestBody = jsonDecode(raw) as Map<String, dynamic>;
        } on FormatException {
          lastRequestBody = null;
        }
      }
    }
    request.response.headers.contentType = ContentType.parse(contentType);
    if (body is String) {
      request.response.write(body);
    } else {
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(
      BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'),
    );
    dataSource = ProductsCatalogRemoteDataSource(dio);
    lastRequestUri = null;
    lastRequestBody = null;
    lastRequestBodyRaw = null;
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('listCategories parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'cat-1',
            'company_id': 'company-1',
            'name': 'T-Shirts',
            'parent_category_id': null,
            'description': 'Casual tees',
            'image_url': null,
            'display_order': 1,
            'is_active': true,
            'version': 1,
          },
        ],
      }),
    );

    final categories = await dataSource.listCategories();

    expect(categories, hasLength(1));
    expect(categories.single.name, 'T-Shirts');
    expect(categories.single.displayOrder, 1);
  });

  test('createCategory posts the expected body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Category created',
        'data': {
          'id': 'cat-1',
          'company_id': 'company-1',
          'name': 'Shoes',
          'parent_category_id': null,
          'description': null,
          'image_url': null,
          'display_order': 0,
          'is_active': true,
          'version': 1,
        },
      }),
    );

    final category = await dataSource.createCategory(
      const CategoryCreateParams(name: 'Shoes'),
    );

    expect(category.name, 'Shoes');
    expect(lastRequestBody!['name'], 'Shoes');
    expect(lastRequestBody!['display_order'], 0);
  });

  test(
    'listProducts sends search and category_id as query parameters',
    () async {
      server.listen(
        (request) => respond(request, {
          'success': true,
          'message': 'ok',
          'data': <dynamic>[],
        }),
      );

      await dataSource.listProducts(search: 'tea', categoryId: 'cat-1');

      expect(lastRequestUri!.queryParameters['search'], 'tea');
      expect(lastRequestUri!.queryParameters['category_id'], 'cat-1');
    },
  );

  test(
    'createProduct sends variants and gender using their wire values',
    () async {
      server.listen(
        (request) => respond(request, {
          'success': true,
          'message': 'Product created',
          'data': {
            'product': {
              'id': 'prod-1',
              'company_id': 'company-1',
              'sku': 'KID-001',
              'name': 'Kids Shirt',
              'description': null,
              'category_id': null,
              'brand_id': null,
              'base_unit_id': 'unit-1',
              'gender': 'kids',
              'season': null,
              'age_group': null,
              'hsn_code': null,
              'tax_percent': null,
              'has_variants': true,
              'track_inventory': true,
              'allow_negative_stock': false,
              'low_stock_threshold': null,
              'is_active': true,
              'version': 1,
            },
            'variants': [
              {
                'id': 'var-1',
                'company_id': 'company-1',
                'product_id': 'prod-1',
                'sku': 'KID-001-S',
                'size': 'S',
                'color': 'Red',
                'variant_name': 'Red / S',
                'purchase_price': '100.00',
                'selling_price': '200.00',
                'mrp': null,
                'is_active': true,
                'version': 1,
              },
            ],
          },
        }),
      );

      final result = await dataSource.createProduct(
        const ProductCreateParams(
          sku: 'KID-001',
          name: 'Kids Shirt',
          baseUnitId: 'unit-1',
          gender: ProductGender.kids,
          hasVariants: true,
          variants: [
            ProductVariantInputParams(
              sku: 'KID-001-S',
              size: 'S',
              color: 'Red',
              purchasePrice: '100.00',
              sellingPrice: '200.00',
            ),
          ],
        ),
      );

      expect(lastRequestBody!['gender'], 'kids');
      expect(lastRequestBody!['variants'], hasLength(1));
      final firstVariant =
          (lastRequestBody!['variants'] as List).first as Map<String, dynamic>;
      expect(firstVariant['sku'], 'KID-001-S');
      expect(result.product.gender, ProductGender.kids);
      expect(result.variants.single.variantName, 'Red / S');
    },
  );

  test('addBarcode sends the barcode type wire value', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Barcode added',
        'data': {
          'id': 'barcode-1',
          'company_id': 'company-1',
          'product_variant_id': 'var-1',
          'barcode': '8901234567890',
          'barcode_type': 'ean13',
          'is_primary': true,
        },
      }),
    );

    final barcode = await dataSource.addBarcode(
      'var-1',
      const ProductBarcodeCreateParams(
        barcode: '8901234567890',
        barcodeType: BarcodeType.ean13,
        isPrimary: true,
      ),
    );

    expect(lastRequestBody!['barcode_type'], 'ean13');
    expect(barcode.barcodeType, BarcodeType.ean13);
    expect(barcode.isPrimary, isTrue);
  });

  test('exportProductsCsv returns the raw CSV body', () async {
    const csvBody = 'sku,name\nTEA-001,Masala Tea\n';
    server.listen(
      (request) => respond(request, csvBody, contentType: 'text/csv'),
    );

    final csv = await dataSource.exportProductsCsv();

    expect(csv, csvBody);
  });

  test(
    'updateCategory sends expected_version as a query parameter and the full body',
    () async {
      server.listen(
        (request) => respond(request, {
          'success': true,
          'message': 'Category updated',
          'data': {
            'id': 'cat-1',
            'company_id': 'company-1',
            'name': 'Shoes',
            'parent_category_id': null,
            'description': null,
            'image_url': null,
            'display_order': 2,
            'is_active': false,
            'version': 2,
          },
        }),
      );

      final category = await dataSource.updateCategory(
        'cat-1',
        const CategoryUpdateParams(
          name: 'Shoes',
          displayOrder: 2,
          isActive: false,
        ),
        1,
      );

      expect(lastRequestUri!.queryParameters['expected_version'], '1');
      expect(lastRequestBody!['is_active'], false);
      expect(category.version, 2);
    },
  );

  test('listBrands parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'brand-1',
            'company_id': 'company-1',
            'name': 'Acme',
            'logo_url': null,
            'description': null,
            'is_active': true,
            'version': 1,
          },
        ],
      }),
    );

    final brands = await dataSource.listBrands();

    expect(brands.single.name, 'Acme');
  });

  test('createBrand posts the expected body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Brand created',
        'data': {
          'id': 'brand-1',
          'company_id': 'company-1',
          'name': 'Acme',
          'logo_url': null,
          'description': null,
          'is_active': true,
          'version': 1,
        },
      }),
    );

    final brand = await dataSource.createBrand(
      const BrandCreateParams(name: 'Acme'),
    );

    expect(lastRequestBody!['name'], 'Acme');
    expect(brand.name, 'Acme');
  });

  test('updateBrand sends expected_version and the full body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Brand updated',
        'data': {
          'id': 'brand-1',
          'company_id': 'company-1',
          'name': 'Acme',
          'logo_url': null,
          'description': 'In-house label',
          'is_active': true,
          'version': 2,
        },
      }),
    );

    final brand = await dataSource.updateBrand(
      'brand-1',
      const BrandUpdateParams(
        name: 'Acme',
        description: 'In-house label',
        isActive: true,
      ),
      1,
    );

    expect(lastRequestUri!.queryParameters['expected_version'], '1');
    expect(brand.description, 'In-house label');
  });

  test('listUnits parses a nullable company_id', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'unit-1',
            'company_id': null,
            'name': 'Pieces',
            'abbreviation': 'pcs',
            'is_system': true,
          },
        ],
      }),
    );

    final units = await dataSource.listUnits();

    expect(units.single.companyId, isNull);
    expect(units.single.isSystem, isTrue);
  });

  test('createUnit posts the expected body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Unit created',
        'data': {
          'id': 'unit-2',
          'company_id': 'company-1',
          'name': 'Carton',
          'abbreviation': 'ctn',
          'is_system': false,
        },
      }),
    );

    final unit = await dataSource.createUnit(
      const UnitCreateParams(name: 'Carton', abbreviation: 'ctn'),
    );

    expect(lastRequestBody!['abbreviation'], 'ctn');
    expect(unit.isSystem, isFalse);
  });

  test('getProduct parses the product-with-variants envelope', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': {
          'product': {
            'id': 'prod-1',
            'company_id': 'company-1',
            'sku': 'TEA-001',
            'name': 'Masala Tea',
            'description': null,
            'category_id': null,
            'brand_id': null,
            'base_unit_id': 'unit-1',
            'gender': null,
            'season': null,
            'age_group': null,
            'hsn_code': null,
            'tax_percent': null,
            'has_variants': false,
            'track_inventory': true,
            'allow_negative_stock': false,
            'low_stock_threshold': null,
            'is_active': true,
            'version': 1,
          },
          'variants': [
            {
              'id': 'var-1',
              'company_id': 'company-1',
              'product_id': 'prod-1',
              'sku': 'TEA-001',
              'size': null,
              'color': null,
              'variant_name': null,
              'purchase_price': '90.00',
              'selling_price': '120.00',
              'mrp': null,
              'is_active': true,
              'version': 1,
            },
          ],
        },
      }),
    );

    final result = await dataSource.getProduct('prod-1');

    expect(result.product.sku, 'TEA-001');
    expect(result.variants.single.sellingPrice, '120.00');
  });

  test('updateProduct sends expected_version and the mutable fields', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Product updated',
        'data': {
          'id': 'prod-1',
          'company_id': 'company-1',
          'sku': 'TEA-001',
          'name': 'Masala Tea Deluxe',
          'description': null,
          'category_id': null,
          'brand_id': null,
          'base_unit_id': 'unit-1',
          'gender': null,
          'season': null,
          'age_group': null,
          'hsn_code': null,
          'tax_percent': null,
          'has_variants': false,
          'track_inventory': true,
          'allow_negative_stock': false,
          'low_stock_threshold': null,
          'is_active': true,
          'version': 2,
        },
      }),
    );

    final product = await dataSource.updateProduct(
      'prod-1',
      const ProductUpdateParams(
        name: 'Masala Tea Deluxe',
        trackInventory: true,
        allowNegativeStock: false,
        isActive: true,
      ),
      1,
    );

    expect(lastRequestUri!.queryParameters['expected_version'], '1');
    expect(product.name, 'Masala Tea Deluxe');
  });

  test('disableProduct sends expected_version as a query parameter', () async {
    server.listen(
      (request) =>
          respond(request, {'success': true, 'message': 'ok', 'data': null}),
    );

    await dataSource.disableProduct('prod-1', 3);

    expect(lastRequestUri!.queryParameters['expected_version'], '3');
  });

  test('listVariants parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'var-1',
            'company_id': 'company-1',
            'product_id': 'prod-1',
            'sku': 'TEA-001',
            'size': null,
            'color': null,
            'variant_name': null,
            'purchase_price': '90.00',
            'selling_price': '120.00',
            'mrp': null,
            'is_active': true,
            'version': 1,
          },
        ],
      }),
    );

    final variants = await dataSource.listVariants('prod-1');

    expect(variants.single.sku, 'TEA-001');
  });

  test('updateVariant sends expected_version and the full body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Variant updated',
        'data': {
          'id': 'var-1',
          'company_id': 'company-1',
          'product_id': 'prod-1',
          'sku': 'TEA-001',
          'size': null,
          'color': null,
          'variant_name': null,
          'purchase_price': '90.00',
          'selling_price': '130.00',
          'mrp': null,
          'is_active': true,
          'version': 2,
        },
      }),
    );

    final variant = await dataSource.updateVariant(
      'var-1',
      const ProductVariantUpdateParams(
        purchasePrice: '90.00',
        sellingPrice: '130.00',
        isActive: true,
      ),
      1,
    );

    expect(lastRequestUri!.queryParameters['expected_version'], '1');
    expect(variant.sellingPrice, '130.00');
  });

  test('listBarcodes parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'barcode-1',
            'company_id': 'company-1',
            'product_variant_id': 'var-1',
            'barcode': '8901234567890',
            'barcode_type': 'ean13',
            'is_primary': true,
          },
        ],
      }),
    );

    final barcodes = await dataSource.listBarcodes('var-1');

    expect(barcodes.single.barcodeType, BarcodeType.ean13);
  });

  test('listImages parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'img-1',
            'company_id': 'company-1',
            'product_id': 'prod-1',
            'image_url': 'https://example.com/a.jpg',
            'display_order': 0,
            'is_primary': true,
          },
        ],
      }),
    );

    final images = await dataSource.listImages('prod-1');

    expect(images.single.imageUrl, 'https://example.com/a.jpg');
  });

  test('addImage posts the expected body', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Image added',
        'data': {
          'id': 'img-1',
          'company_id': 'company-1',
          'product_id': 'prod-1',
          'image_url': 'https://example.com/a.jpg',
          'display_order': 0,
          'is_primary': true,
        },
      }),
    );

    final image = await dataSource.addImage(
      'prod-1',
      const ProductImageCreateParams(
        imageUrl: 'https://example.com/a.jpg',
        isPrimary: true,
      ),
    );

    expect(lastRequestBody!['image_url'], 'https://example.com/a.jpg');
    expect(image.isPrimary, isTrue);
  });

  test(
    'importProductsCsv uploads the file as multipart and parses the summary',
    () async {
      server.listen(
        (request) => respond(request, {
          'success': true,
          'message': 'Import complete: 1 created, 0 skipped, 0 errors',
          'data': {
            'created': 1,
            'skipped': 0,
            'errors': 0,
            'results': [
              {'sku': 'TEA-001', 'status': 'created', 'message': null},
            ],
          },
        }),
      );

      final summary = await dataSource.importProductsCsv(
        bytes: utf8.encode('sku,name\nTEA-001,Masala Tea\n'),
        filename: 'products.csv',
      );

      expect(summary.created, 1);
      expect(summary.results.single.sku, 'TEA-001');
      expect(lastRequestBodyRaw, contains('TEA-001'));
    },
  );
}
