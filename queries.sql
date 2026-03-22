--CONSULTAS
-- 1. Todos los pedidos de un cliente ordenados por fecha
SELECT
    order_id,
    order_datetime,
    current_status,
    order_total
FROM
    orders
WHERE
    customer_id = 1
ORDER BY
    order_datetime;

-- 2. Pedidos con nombre de cliente (JOIN)
SELECT
    o.order_id,
    c.full_name,
    o.current_status
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
WHERE
    o.customer_id = 1
ORDER BY
    o.order_datetime;

-- 3. Productos de un pedido especifico (JOIN triple)
SELECT
    o.order_id,
    p.product_name,
    oi.quantity,
    oi.unit_price
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
WHERE
    o.order_id = 26276;

-- 4. Clientes sin ningun pedido (LEFT JOIN + IS NULL)
SELECT
    c.customer_id,
    c.full_name
FROM
    customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE
    o.order_id IS NULL
ORDER BY
    c.customer_id;

-- 5. Historial completo de estados de un pedido
SELECT
    status_history_id,
    status,
    changed_at,
    changed_by,
    reason
FROM
    order_status_history
WHERE
    order_id = 26276
ORDER BY
    changed_at;

-- 6. Todos los pagos de un pedido
SELECT
    payment_id,
    payment_datetime,
    method,
    payment_status,
    amount,
    currency
FROM
    payments
WHERE
    order_id = 26276
ORDER BY
    payment_datetime;

-- 7. Pedidos entregados con sus pagos aprobados
SELECT
    o.order_id,
    o.order_total,
    p.amount,
    p.method,
    p.currency
FROM
    orders o
    JOIN payments p ON o.order_id = p.order_id
WHERE
    o.current_status = 'delivered'
    AND p.payment_status = 'approved'
ORDER BY
    o.order_id;

-- 8. Pagos rechazados con nombre de cliente
SELECT
    p.payment_id,
    c.full_name,
    p.method,
    p.payment_status,
    p.amount,
    p.currency
FROM
    payments p
    JOIN orders o ON p.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
WHERE
    p.payment_status = 'rejected'
ORDER BY
    p.payment_id;

-- 9. Clientes con pedidos cancelados
SELECT DISTINCT
    c.customer_id,
    c.full_name,
    c.segment
FROM
    customers c
    JOIN orders o ON c.customer_id = o.customer_id
WHERE
    o.current_status = 'cancelled'
ORDER BY
    c.customer_id;

-- 10. Productos de todos los pedidos de un cliente
SELECT
    o.order_id,
    p.product_name,
    p.category,
    oi.quantity,
    oi.unit_price
FROM
    customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
WHERE
    c.customer_id = 1
ORDER BY
    o.order_id,
    p.product_name;

-- 11. Auditoria completa de un pedido
SELECT
    oa.field_name,
    oa.old_value,
    oa.new_value,
    oa.changed_at,
    oa.changed_by
FROM
    order_audit oa
    JOIN orders o ON oa.order_id = o.order_id
WHERE
    o.order_id = 26276
ORDER BY
    oa.changed_at;

-- 12. Pedidos con informacion completa ordenados por total
SELECT
    o.order_id,
    c.full_name,
    o.current_status,
    o.order_total,
    o.channel
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
ORDER BY
    o.order_total DESC;

-- ============================================================
-- VALIDACIONES DE INTEGRIDAD
-- ============================================================
-- V1. Pedidos paid sin ningun pago aprobado
SELECT
    o.order_id,
    o.current_status,
    o.order_total
FROM
    orders o
    LEFT JOIN payments p ON o.order_id = p.order_id
    AND p.payment_status = 'approved'
WHERE
    o.current_status = 'paid'
    AND p.payment_id IS NULL
ORDER BY
    o.order_id;

-- V2. Items huerfanos (order_items sin pedido padre)
SELECT
    oi.order_item_id,
    oi.order_id
FROM
    order_items oi
    LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE
    o.order_id IS NULL
ORDER BY
    oi.order_item_id;

-- V3. Pedidos sin ningun item
SELECT
    o.order_id,
    o.current_status,
    o.order_total
FROM
    orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE
    oi.order_item_id IS NULL
ORDER BY
    o.order_id;

-- V4. Pedidos delivered sin pago aprobado
SELECT
    o.order_id,
    o.current_status,
    o.order_total
FROM
    orders o
    LEFT JOIN payments p ON o.order_id = p.order_id
    AND p.payment_status = 'approved'
WHERE
    o.current_status = 'delivered'
    AND p.payment_id IS NULL
ORDER BY
    o.order_id;

-- V5. Pedidos sin historial de estados
SELECT
    o.order_id,
    o.current_status,
    o.order_datetime
FROM
    orders o
    LEFT JOIN order_status_history sh ON o.order_id = sh.order_id
WHERE
    sh.status_history_id IS NULL
ORDER BY
    o.order_id;

-- V6. Productos que nunca fueron pedidos
SELECT
    p.product_id,
    p.product_name,
    p.category
FROM
    products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE
    oi.order_item_id IS NULL
ORDER BY
    p.product_id;

-- V7. Clientes sin ciudad registrada
SELECT
    customer_id,
    full_name,
    city
FROM
    customers
WHERE
    city IS NULL
    OR city = ''
ORDER BY
    customer_id;