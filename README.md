# 🐧 Penguin Academy — SQL Challenge

> _"Persistir no es guardar datos. Es poder defenderlos."_

## Descripción

Este proyecto es el núcleo transaccional real de Penguin Academy. A partir de archivos CSV crudos sin garantías ni integridad, construí una base de datos relacional funcional desde cero: analicé el dominio, diseñé el modelo, implementé las restricciones, inserté los datos y construí las consultas que permiten detectar inconsistencias desde adentro.

No se trata solo de que funcione. Se trata de que cada decisión se pueda defender.

---

## Tecnologías utilizadas

- **Python 3.11** — análisis, inserción y automatización
- **SQLite** — motor de base de datos relacional
- **pandas** — exploración y análisis de los CSV
- **Jupyter Notebook** — entorno de desarrollo

**¿Por qué SQLite?** Porque el proyecto debe ser completamente portable. Todo vive en un único archivo `.db` que viaja con el proyecto. Sin servidor, sin Docker, sin configuración. En cualquier máquina con Python funciona. Para producción real elegiría PostgreSQL, pero para un entorno de evaluación en tiempo limitado, SQLite es la decisión técnicamente correcta.

---

## Estructura del proyecto

Registro-Glacial/
├── base_de_datos.db ← base de datos SQLite con todos los datos
├── schema.sql ← DDL completo: CREATE TABLE con constraints
├── queries.sql ← consultas estructurales y validaciones
├── analisis.ipynb ← Etapa 1: exploración de CSV con pandas
├── motor_insercion.py ← Etapa 4: pipeline de inserción de datos
└── data/
├── customers.csv
├── products.csv
├── orders.csv
├── order_status_history.csv
├── payments.csv
├── order_audit.csv
└── order_items.csv

---

## El modelo relacional

El modelo tiene 7 tablas. Cada una con un rol específico e irremplazable.

customers ──────────────────────────────────────── (entidad raíz)
products ─────────────────────────────────────── (entidad raíz)
orders ──── FK → customers ───────────────────── (entidad central)
order_items ── FK → orders, products ──────── (tabla de unión N:M)
payments ────── FK → orders ───────────────────────
order_status_history ── FK → orders ───────────────
order_audit ── FK → orders ───────────────

`orders` es el núcleo del modelo. Todas las demás tablas dependen de ella directa o indirectamente.

### ¿Por qué existen `order_status_history` Y `order_audit`?

No son redundantes. Son complementarias.

- `order_status_history` responde: **¿qué estados tuvo este pedido, en qué orden y quién los cambió?**
- `order_audit` responde: **¿qué campo específico cambió, desde qué valor y hacia cuál?**

Si un cliente reclama que le cambiaron la dirección de envío sin avisarle, solo `order_audit` puede responder eso.

---

## Constraints implementados

Nada decorativo. Todo defendible.

-- Ejemplo: tabla orders
current_status TEXT NOT NULL CHECK (
current_status IN ('delivered', 'paid', 'shipped', 'packed',
'cancelled', 'created', 'refunded')
),
order_total NUMERIC NOT NULL CHECK (order_total > 0),
customer_id INTEGER NOT NULL REFERENCES customers(customer_id)

Constraints implementados por tabla:

- `PRIMARY KEY` en todas las tablas
- `FOREIGN KEY` en todas las tablas dependientes
- `NOT NULL` en todas las columnas donde el dominio no admite vacíos
- `CHECK` con lista de valores válidos en columnas categóricas
- `CHECK` con condición numérica en columnas de monto (`> 0`)
- `UNIQUE` en columnas que no pueden repetirse (`email`, `sku`)
- `CHECK` de tabla para condiciones lógicas cruzadas (`unit_price > unit_cost`)
- `CHECK` con patrón de negocio: `email LIKE '%@%'`

---

## Resultados de inserción

| Tabla                | Insertados | Rechazados | Motivo principal                          |
| -------------------- | ---------- | ---------- | ----------------------------------------- |
| customers            | 500        | 0          | —                                         |
| products             | 192        | 8          | `CHECK unit_price > 0`                    |
| orders               | 1.814      | 186        | `CHECK order_total > 0` + estado inválido |
| order_items          | 4.262      | 738        | `FOREIGN KEY` en cascada                  |
| payments             | 1.975      | 525        | `CHECK amount > 0` + `FOREIGN KEY`        |
| order_status_history | —          | —          | pendiente                                 |
| order_audit          | —          | —          | pendiente                                 |

**Si todo entra sin errores, el diseño es débil.** Los rechazos son evidencia de que los constraints funcionan.

---

## El Pipeline Universal de Inyección

Una de las piezas que más me enorgullece de este proyecto es el motor de inserción. En lugar de repetir el mismo bloque de código para cada tabla, diseñé una función universal que recibe un diccionario de configuración y procesa todas las tablas en secuencia.

diccionario_datos = {
"customers": "data/customers.csv",
"products": "data/products.csv",
"orders": "data/orders.csv",
"order_items": "data/order_items.csv",
"payments": "data/payments.csv",
"order_status_history": "data/order_status_history.csv",
"order_audit": "data/order_audit.csv",
}

def insercion_datos(dic_datos: dict):
cursor.execute("PRAGMA foreign_keys = ON")
for tabla, ruta_archivo in dic_datos.items():
exitos, rechazos = 0, 0
motivos_rechazo = {}

        with open(ruta_archivo, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            columnas = reader.fieldnames
            nombres_cols = ", ".join(columnas)
            comodines   = ", ".join(["?"] * len(columnas))
            sql = f"INSERT INTO {tabla} ({nombres_cols}) VALUES ({comodines})"

            for fila in reader:
                datos = tuple(None if fila[col] == '' else fila[col] for col in columnas)
                try:
                    cursor.execute(sql, datos)
                    exitos += 1
                except sqlite3.Error as error_motor:
                    rechazos += 1
                    mensaje = str(error_motor)
                    motivos_rechazo[mensaje] = motivos_rechazo.get(mensaje, 0) + 1

        conn.commit()
        print(f"--- REPORTE: {tabla.upper()} ---")
        print(f"  Insertados: {exitos} | Rechazados: {rechazos}")
        if rechazos > 0:
            for motivo, cantidad in motivos_rechazo.items():
                print(f"  {cantidad} filas → {motivo}")

Lo que hace especial a este motor:

- **Un solo cambio para agregar una tabla nueva** — solo una línea en el diccionario
- **Construye el SQL matemáticamente** — lee las columnas directas del CSV, sin hardcodear nombres
- **Diagnóstico clínico de rechazos** — agrupa los errores por tipo y los cuenta, no solo guarda los primeros 3
- **Vacíos convertidos a NULL automáticamente** — `''` se convierte a `None` antes de insertar
- **Orden respetado** — el diccionario se procesa en orden, garantizando que las entidades raíz entran primero

Para ejecutar el pipeline completo:

try:
insercion_datos(diccionario_datos)
finally:
conn.close()

---

## Consultas SQL

### Estructurales

-- Pedidos de un cliente con su nombre
SELECT o.order_id, c.full_name, o.current_status, o.order_total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.customer_id = 1
ORDER BY o.order_datetime;

-- Productos de un pedido específico
SELECT o.order_id, p.product_name, oi.quantity, oi.unit_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_id = 100;

-- Clientes sin ningún pedido
SELECT c.customer_id, c.full_name
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

### Validaciones de integridad

-- Pedidos en estado 'created' sin ningún pago aprobado
SELECT o.order_id, o.current_status, o.order_total
FROM orders o
LEFT JOIN payments p
ON o.order_id = p.order_id
AND p.payment_status = 'approved'
WHERE o.current_status = 'created'
AND p.payment_id IS NULL;

-- Pedidos sin ningún ítem de detalle
SELECT o.order_id, o.current_status
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_item_id IS NULL;

-- Productos que nunca fueron vendidos
SELECT p.product_id, p.product_name, p.category
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
WHERE oi.product_id IS NULL;

---

## Índices y performance

-- Índices en todas las FK (el motor no los crea automáticamente)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);

-- Índices en columnas de filtro frecuente y ordenamiento
CREATE INDEX IF NOT EXISTS idx_orders_current_status ON orders(current_status);
CREATE INDEX IF NOT EXISTS idx_orders_datetime ON orders(order_datetime DESC);

**Benchmark real:**

Sin índice (SCAN): 5.998 segundos → recorre todas las filas
Con índice (SEARCH): 0.030 segundos → va directo al dato

Mejora: 199x más rápido

---

## Seguridad — SQL Injection

# VULNERABLE: el atacante puede ejecutar cualquier SQL

query = "SELECT \* FROM customers WHERE full_name = '" + input_usuario + "'"

# SEGURO: el ? nunca se interpreta como SQL

cursor.execute("SELECT \* FROM customers WHERE full_name = ?", (input_usuario,))

Con el input `' OR '1'='1' --`:

- Versión vulnerable: devuelve **todos los registros** de la tabla
- Versión segura: devuelve **0 registros**

Las consultas parametrizadas no mitigan SQL Injection, la eliminan estructuralmente. El motor compila el SQL primero y recibe los datos después. En ese punto la compilación ya terminó y ningún valor puede convertirse en código.

---

## Cómo ejecutar

# 1. Clonar el repositorio

git clone https://github.com/Cesahz/Registro-Glacial.git

# 2. Instalar dependencias

pip install pandas

# 3. Crear las tablas

# Ejecutar celda 1 del notebook (carga schema.sql)

# 4. Insertar los datos

# Ejecutar el pipeline universal con insercion_datos(diccionario_datos)

# 5. Ejecutar las consultas

# Abrir queries.sql en VSCode o ejecutar desde el notebook

---

## Lecciones aprendidas

El modelado relacional no es un ejercicio técnico. Es un ejercicio de comprensión del dominio. Los constraints no son restricciones arbitrarias, son reglas de negocio formalizadas en la estructura. Los rechazos no son errores del sistema, son el sistema funcionando. Y la diferencia entre un modelo que funciona y uno que se puede defender es la capacidad de justificar cada decisión con el dominio real, no con preferencias técnicas.

---

_Penguin Academy SQL Challenge — construido con criterio, defendible en cada línea._
