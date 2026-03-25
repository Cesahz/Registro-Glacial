-- activar claves foraneas
PRAGMA foreign_keys = ON;

--tabla = customers
CREATE TABLE
    IF NOT EXISTS customers (
        customer_id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE CHECK (email LIKE '%@%'),
        phone TEXT NOT NULL,
        city TEXT NOT NULL,
        segment TEXT NOT NULL CHECK (
            segment IN ('retail', 'wholesale', 'online_only', 'vip')
        ),
        created_at TEXT NOT NULL,
        is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
        deleted_at TEXT
    );

CREATE TABLE
    IF NOT EXISTS products (
        product_id INTEGER PRIMARY KEY,
        sku TEXT NOT NULL UNIQUE,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        brand TEXT NOT NULL,
        unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
        unit_cost NUMERIC NOT NULL CHECK (unit_cost > 0),
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
        CHECK (unit_price > unit_cost)
    );

CREATE TABLE
    IF NOT EXISTS orders (
        order_id INTEGER PRIMARY KEY,
        customer_id INTEGER NOT NULL REFERENCES customers (customer_id),
        order_datetime TEXT NOT NULL,
        channel TEXT NOT NULL CHECK (channel IN ('web', 'mobile', 'phone', 'store')),
        currency TEXT NOT NULL CHECK (currency IN ('PYG', 'USD')),
        current_status TEXT NOT NULL CHECK (
            current_status IN (
                'delivered',
                'paid',
                'shipped',
                'packed',
                'cancelled',
                'created',
                'refunded'
            )
        ),
        is_active INTEGER NOT NULL CHECK (is_active IN (0, 1)),
        deleted_at TEXT,
        order_total NUMERIC NOT NULL CHECK (order_total > 0)
    );

CREATE TABLE
    IF NOT EXISTS order_items (
        order_item_id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL REFERENCES orders (order_id),
        product_id INTEGER NOT NULL REFERENCES products (product_id),
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
        discount_rate NUMERIC NOT NULL CHECK (
            discount_rate >= 0
            AND discount_rate < 1
        ),
        line_total NUMERIC NOT NULL CHECK (line_total > 0)
    );

CREATE TABLE
    IF NOT EXISTS payments (
        payment_id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL REFERENCES orders (order_id),
        payment_datetime TEXT NOT NULL,
        method TEXT NOT NULL CHECK (method IN ('card', 'transfer', 'cash', 'wallet')),
        payment_status TEXT NOT NULL CHECK (
            payment_status IN ('approved', 'pending', 'rejected', 'refunded')
        ),
        amount NUMERIC NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL CHECK (currency IN ('PYG', 'USD'))
    );

CREATE TABLE
    IF NOT EXISTS order_status_history (
        status_history_id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL REFERENCES orders (order_id),
        status TEXT NOT NULL CHECK (
            status IN (
                'delivered',
                'paid',
                'shipped',
                'packed',
                'cancelled',
                'created',
                'refunded'
            )
        ),
        changed_at TEXT NOT NULL,
        changed_by TEXT NOT NULL CHECK (
            changed_by IN (
                'system',
                'support',
                'ops',
                'user',
                'payment_gateway',
                'warehouse'
            )
        ),
        reason TEXT
    );

CREATE TABLE
    IF NOT EXISTS order_audit (
        audit_id INTEGER PRIMARY KEY,
        order_id INTEGER NOT NULL REFERENCES orders (order_id),
        field_name TEXT NOT NULL CHECK (
            field_name IN (
                'current_status',
                'shipping_address',
                'order_total',
                'notes',
                'customer_phone'
            )
        ),
        old_value TEXT NOT NULL,
        new_value TEXT NOT NULL,
        changed_at TEXT NOT NULL,
        changed_by TEXT NOT NULL CHECK (changed_by IN ('system', 'support', 'ops'))
    );

-- indices para claves foraneas (evita escaneos completos al hacer JOINs)
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

CREATE INDEX idx_order_items_order_id ON order_items (order_id);

CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- indice de filtrado frecuente (optimiza la clausula WHERE)
CREATE INDEX idx_orders_current_status ON orders (current_status);

-- indice de ordenamiento y rango (optimiza clausulas ORDER BY y rangos de fechas)
CREATE INDEX idx_orders_datetime ON orders (order_datetime DESC);