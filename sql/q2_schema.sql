-- Questao 2 - schema.sql (PostgreSQL)
-- Gerado automaticamente por src/q2_generate_schema.py -- NAO EDITAR A MAO.
-- Cada CREATE TABLE foi derivado lendo o CSV correspondente por completo:
--   * tipo de cada coluna inferido por tentativa (BOOLEAN > TIMESTAMP > DATE
--     > INTEGER/BIGINT > NUMERIC(p,s) > VARCHAR(n)/TEXT, nessa ordem);
--   * NOT NULL somente se a coluna nao tiver nenhum valor vazio no CSV;
--   * coluna "id" (quando existe) vira PRIMARY KEY.
-- Limitacao conhecida: deteccao e' puramente estrutural (por arquivo) -- nao
-- infere chaves estrangeiras nem chaves primarias compostas entre tabelas.


DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS attributes CASCADE;
DROP TABLE IF EXISTS brands CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS fiscal_invoices CASCADE;
DROP TABLE IF EXISTS goods_receipt_items CASCADE;
DROP TABLE IF EXISTS goods_receipts CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS product_suppliers CASCADE;
DROP TABLE IF EXISTS product_variants CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS purchase_order_items CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS return_items CASCADE;
DROP TABLE IF EXISTS returns CASCADE;
DROP TABLE IF EXISTS stock_levels CASCADE;
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS variant_attribute_values CASCADE;

CREATE TABLE addresses (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    address_type VARCHAR(20) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    street VARCHAR(40) NOT NULL,
    number INTEGER NOT NULL,
    complement VARCHAR(20),
    district VARCHAR(40) NOT NULL,
    city VARCHAR(40) NOT NULL,
    state VARCHAR(20) NOT NULL,
    country VARCHAR(20) NOT NULL,
    is_primary BOOLEAN NOT NULL
);

CREATE TABLE attributes (
    id INTEGER PRIMARY KEY,
    name VARCHAR(20) NOT NULL,
    data_type VARCHAR(20) NOT NULL
);

CREATE TABLE brands (
    id INTEGER PRIMARY KEY,
    name VARCHAR(20) NOT NULL,
    country VARCHAR(20),
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE categories (
    id INTEGER PRIMARY KEY,
    name VARCHAR(40) NOT NULL,
    slug VARCHAR(40) NOT NULL,
    parent_category_id INTEGER,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE customers (
    id INTEGER PRIMARY KEY,
    person_type VARCHAR(20) NOT NULL,
    legal_name VARCHAR(40) NOT NULL,
    trade_name VARCHAR(40),
    tax_id VARCHAR(20) NOT NULL,
    state_registration VARCHAR(20),
    email VARCHAR(60),
    phone VARCHAR(20),
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    full_name VARCHAR(40) NOT NULL,
    cpf BIGINT NOT NULL,
    email VARCHAR(60) NOT NULL,
    role VARCHAR(20) NOT NULL,
    primary_location_id INTEGER NOT NULL,
    hire_date DATE NOT NULL,
    termination_date DATE,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE fiscal_invoices (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    nfe_number VARCHAR(20) NOT NULL,
    nfe_access_key VARCHAR(60) NOT NULL,
    series VARCHAR(20) NOT NULL,
    issued_at TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    xml_storage_uri VARCHAR(80) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE goods_receipt_items (
    id INTEGER PRIMARY KEY,
    goods_receipt_id INTEGER NOT NULL,
    purchase_order_item_id INTEGER NOT NULL,
    quantity_received NUMERIC(7,3) NOT NULL
);

CREATE TABLE goods_receipts (
    id INTEGER PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL,
    received_by_employee_id INTEGER NOT NULL,
    received_at TIMESTAMP NOT NULL,
    notes VARCHAR(20),
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE locations (
    id INTEGER PRIMARY KEY,
    name VARCHAR(20) NOT NULL,
    location_type VARCHAR(20) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    street VARCHAR(40) NOT NULL,
    number INTEGER NOT NULL,
    complement VARCHAR(20),
    district VARCHAR(40) NOT NULL,
    city VARCHAR(20) NOT NULL,
    state VARCHAR(20) NOT NULL,
    country VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_variant_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(8,2) NOT NULL,
    icms_rate NUMERIC(6,2) NOT NULL,
    ipi_rate NUMERIC(6,2) NOT NULL,
    line_total NUMERIC(9,2) NOT NULL
);

CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    customer_id INTEGER NOT NULL,
    salesperson_id INTEGER,
    location_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL,
    discount_amount NUMERIC(9,2) NOT NULL,
    total NUMERIC(10,2) NOT NULL,
    placed_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    method VARCHAR(20) NOT NULL,
    installments INTEGER NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    paid_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE product_suppliers (
    product_variant_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    supplier_sku VARCHAR(20),
    last_quoted_cost NUMERIC(8,2) NOT NULL,
    lead_time_days INTEGER NOT NULL,
    is_preferred BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE product_variants (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL,
    sku VARCHAR(20) NOT NULL,
    barcode_ean VARCHAR(20),
    sale_price NUMERIC(8,2) NOT NULL,
    cost_price NUMERIC(8,2) NOT NULL,
    weight_kg NUMERIC(7,3) NOT NULL,
    icms_rate NUMERIC(6,2) NOT NULL,
    ipi_rate NUMERIC(6,2) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name VARCHAR(40) NOT NULL,
    description VARCHAR(60),
    brand_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    ncm_code INTEGER NOT NULL,
    unit_of_measure VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE purchase_order_items (
    id INTEGER PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL,
    product_variant_id INTEGER NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    unit_cost NUMERIC(8,2) NOT NULL,
    line_total NUMERIC(10,2) NOT NULL
);

CREATE TABLE purchase_orders (
    id INTEGER PRIMARY KEY,
    po_number VARCHAR(20) NOT NULL,
    supplier_id INTEGER NOT NULL,
    buyer_id INTEGER NOT NULL,
    destination_location_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,
    currency VARCHAR(20) NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL,
    total NUMERIC(10,2) NOT NULL,
    placed_at TIMESTAMP NOT NULL,
    expected_delivery_at DATE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE return_items (
    id INTEGER PRIMARY KEY,
    return_id INTEGER NOT NULL,
    order_item_id INTEGER NOT NULL,
    quantity NUMERIC(7,3) NOT NULL,
    action VARCHAR(20) NOT NULL,
    exchange_variant_id INTEGER,
    unit_refund_amount NUMERIC(8,2) NOT NULL
);

CREATE TABLE returns (
    id INTEGER PRIMARY KEY,
    return_number VARCHAR(20) NOT NULL,
    order_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    received_at_location_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,
    reason VARCHAR(40),
    total_refund_amount NUMERIC(9,2) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE stock_levels (
    product_variant_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    quantity_on_hand NUMERIC(7,3) NOT NULL,
    reorder_point TEXT,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE stock_movements (
    id INTEGER PRIMARY KEY,
    product_variant_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    movement_type VARCHAR(20) NOT NULL,
    quantity NUMERIC(8,3) NOT NULL,
    reference_table VARCHAR(20),
    reference_id INTEGER,
    employee_id INTEGER,
    notes VARCHAR(40),
    occurred_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY,
    legal_name VARCHAR(40) NOT NULL,
    trade_name VARCHAR(20),
    country VARCHAR(20) NOT NULL,
    tax_id VARCHAR(20) NOT NULL,
    tax_id_type VARCHAR(20) NOT NULL,
    email VARCHAR(40) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    contact_name VARCHAR(40) NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE variant_attribute_values (
    product_variant_id INTEGER NOT NULL,
    attribute_id INTEGER NOT NULL,
    value VARCHAR(20) NOT NULL
);
