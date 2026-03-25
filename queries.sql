-- recupera los ultimos pedidos cancelados junto con la informacion de contacto del cliente
SELECT
    o.order_id,
    o.order_datetime,
    c.full_name,
    o.current_status,
    c.email
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
WHERE
    o.current_status = 'cancelled'
ORDER BY
    o.order_datetime DESC
LIMIT
    5;

-- extrae el detalle exacto de productos, cantidades y precios para auditar un pedido especifico
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

-- detecta pedidos huerfanos de historial, identificando entidades incompletas en el rastreo
SELECT
    o.order_id,
    o.current_status,
    o.order_datetime
FROM
    orders o
    LEFT JOIN order_status_history osh ON o.order_id = osh.order_id
WHERE
    osh.status_history_id IS NULL
ORDER BY
    o.order_id
LIMIT
    10;

-- identifica productos del catalogo que representan ausencias absolutas de venta
SELECT
    p.product_id,
    p.product_name,
    p.category
FROM
    products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE
    oi.product_id IS NULL
ORDER BY
    p.product_id;

-- rastrea estados de espera identificando clientes con pagos en efectivo aun pendientes
SELECT
    c.full_name,
    o.order_id,
    o.current_status,
    p.method
FROM
    customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN payments p ON o.order_id = p.order_id
WHERE
    p.method = 'cash'
    AND p.payment_status = 'pending';

-- alerta de estado imposible: pedidos marcados como pagados que carecen de un pago aprobado en el sistema
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

-- alerta de estado imposible: pedidos que han sido entregados pero no registran ingreso de dinero aprobado
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