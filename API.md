# RetailOS API Standards

## Overview

The RetailOS backend exposes RESTful APIs for all business modules. APIs should be versioned and documented.

Base URL:
/api/v1

---

## Authentication

POST   /auth/login
POST   /auth/logout
POST   /auth/refresh
POST   /auth/forgot-password
POST   /auth/change-password

Authentication:
Bearer JWT Token

---

## Company

GET    /companies
POST   /companies
PUT    /companies/{id}
DELETE /companies/{id}

---

## Branches

GET    /branches
POST   /branches
PUT    /branches/{id}

---

## Products

GET    /products
POST   /products
PUT    /products/{id}
DELETE /products/{id}

GET    /categories
POST   /categories

Import:
POST /products/import

Export:
GET /products/export

---

## Customers

GET /customers
POST /customers
PUT /customers/{id}

---

## Suppliers

GET /suppliers
POST /suppliers
PUT /suppliers/{id}

---

## Purchases

GET /purchases
POST /purchases

---

## Inventory

GET /inventory
POST /inventory/adjustment
POST /inventory/transfer

---

## POS

POST /sales
GET /sales/{id}
POST /sales/return

---

## Reports

GET /reports/sales
GET /reports/purchases
GET /reports/inventory
GET /reports/profit

---

## Response Format

Success

{
  "success": true,
  "message": "Operation completed",
  "data": {}
}

Error

{
  "success": false,
  "message": "Validation failed",
  "errors": []
}

---

## Security

- JWT Authentication
- HTTPS only
- Role-based authorization
- Audit logging
- Request validation
- Rate limiting

---

## Versioning

/api/v1
/api/v2
