# RetailOS Database Design

## Database

PostgreSQL

## Design Principles

- Normalize to 3NF where practical
- Use UUIDs for primary keys
- Add created_at and updated_at timestamps
- Support soft delete where required
- Create indexes for search and reporting
- Use foreign keys to maintain integrity

## Core Tables

### Business

- companies
- branches
- users
- roles
- permissions

### Products

- categories
- brands
- products
- product_variants
- product_barcodes
- product_images

### Inventory

- stock
- stock_transactions
- stock_adjustments
- stock_transfers

### Purchases

- suppliers
- purchase_orders
- purchase_order_items
- goods_receipts
- supplier_returns

### Sales

- customers
- invoices
- invoice_items
- payments
- returns

### Finance

- expenses
- expense_categories
- tax_rates

### Reports

- audit_logs
- activity_logs
- dashboard_cache

## Naming Standards

- Table names: plural (products, customers)
- Columns: snake_case
- Primary key: id
- Foreign key: <table>_id

## Performance

- Index barcode
- Index SKU
- Index invoice number
- Index customer phone
- Index supplier code
- Optimize frequently used reports

## Backup Strategy

- Daily backup
- Weekly full backup
- Point-in-time recovery support

## Future Expansion

- Warehouse Management
- Manufacturing
- CRM
- HR & Payroll
- AI Analytics
