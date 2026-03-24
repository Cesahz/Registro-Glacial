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

```
penguin-academy-sql/
├── base_de_datos.db          ← base de datos SQLite con todos los datos
├── schema.sql                ← DDL completo: CREATE TABLE con constraints
├── queries.sql               ← consultas estructurales y validaciones
├── analisis.ipynb            ← Etapa 1: exploración de CSV con pandas
├── insercion.ipynb           ← Etapa 4: pipeline de inserción de datos
└── data/
    ├── clientes.csv
    ├── productos.csv
    ├── pedidos.csv
    ├── detalle_pedido.csv
    ├── pagos.csv
    ├── historial_estados.csv
    └── auditoria_pedidos.csv
```

---

## El modelo relacional

El modelo tiene 7 tablas. Cada una con un rol específico e irremplazable.

```
clientes ──────────────────────────────────────── (entidad raíz)
productos ─────────────────────────────────────── (entidad raíz)
pedidos ──── FK → clientes ───────────────────── (entidad central)
detalle_pedido ── FK → pedidos, productos ──────── (tabla de unión N:M)
pagos ────── FK → pedidos ───────────────────────
historial_estados ── FK → pedidos ───────────────
auditoria_pedidos ── FK → pedidos ───────────────
```

`pedidos` es el núcleo del modelo. Todas las demás tablas dependen de ella directa o indirectamente.

### ¿Por qué existen `historial_estados` Y `auditoria_pedidos`?

No son redundantes. Son complementarias.

- `historial_estados` responde: **¿qué estados tuvo este pedido, en qué orden y quién los cambió?**
- `auditoria_pedidos` responde: **¿qué campo específico cambió, desde qué valor y hacia cuál?**

Si un cliente reclama que le cambiaron la dirección de envío sin avisarle, solo `auditoria_pedidos` puede responder eso.

---

## Constraints implementados

Nada decorativo. Todo defendible.

```sql
-- Ejemplo: tabla pedidos
estado_actual TEXT NOT NULL CHECK (
    estado_actual IN ('entregado','cancelado','devuelto',
                      'en_preparacion','confirmado','enviado','pendiente')
),
total_pedido NUMERIC NOT NULL CHECK (total_pedido > 0),
cliente_id   INTEGER NOT NULL REFERENCES clientes(cliente_id)
```

Constraints implementados por tabla:

- `PRIMARY KEY` en todas las tablas
- `FOREIGN KEY` en todas las tablas dependientes
- `NOT NULL` en todas las columnas donde el dominio no admite vacíos
- `CHECK` con lista de valores válidos en columnas categóricas
- `CHECK` con condición numérica en columnas de monto
- `UNIQUE` en columnas que no pueden repetirse (correo, codigo_producto)
- `CHECK` de tabla para condiciones entre dos columnas (`precio_venta > precio_costo`)
- `CHECK` con patrón: `correo LIKE '%@%.%'` y `codigo_producto LIKE 'SKU-%'`

---

## Resultados de inserción

| Tabla             | Insertados | Rechazados | Motivo principal                           |
| ----------------- | ---------- | ---------- | ------------------------------------------ |
| clientes          | 500        | 0          | —                                          |
| productos         | 192        | 8          | `CHECK precio_venta > 0`                   |
| pedidos           | 1.814      | 186        | `CHECK total_pedido > 0` + estado inválido |
| detalle_pedido    | 4.262      | 738        | `FOREIGN KEY` en cascada                   |
| pagos             | 1.975      | 525        | `CHECK monto > 0` + `FOREIGN KEY`          |
| historial_estados | —          | —          | pendiente                                  |
| auditoria_pedidos | —          | —          | pendiente                                  |

**Si todo entra sin errores, el diseño es débil.** Los rechazos son evidencia de que los constraints funcionan.

---

## El Pipeline Universal de Inyección

Una de las piezas que más me enorgullece de este proyecto es el motor de inserción. En lugar de repetir el mismo bloque de código para cada tabla, diseñé una función universal que recibe un diccionario de configuración y procesa todas las tablas en secuencia.

```python
diccionario_datos = {
    "clientes":           "data/clientes.csv",
    "productos":          "data/productos.csv",
    "pedidos":            "data/pedidos.csv",
    "detalle_pedido":     "data/detalle_pedido.csv",
    "pagos":              "data/pagos.csv",
    "historial_estados":  "data/historial_estados.csv",
    "auditoria_pedidos":  "data/auditoria_pedidos.csv",
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
```

Lo que hace especial a este motor:

- **Un solo cambio para agregar una tabla nueva** — solo una línea en el diccionario
- **Construye el SQL matemáticamente** — lee las columnas directas del CSV, sin hardcodear nombres
- **Diagnóstico clínico de rechazos** — agrupa los errores por tipo y los cuenta, no solo guarda los primeros 3
- **Vacíos convertidos a NULL automáticamente** — `''` se convierte a `None` antes de insertar
- **Orden respetado** — el diccionario se procesa en orden, garantizando que las entidades raíz entran primero

Para ejecutar el pipeline completo:

```python
try:
    insercion_datos(diccionario_datos)
finally:
    conn.close()
```

---

## Consultas SQL

### Estructurales

```sql
-- Pedidos de un cliente con su nombre
SELECT o.pedido_id, c.nombre_completo, o.estado_actual, o.total_pedido
FROM pedidos o
JOIN clientes c ON o.cliente_id = c.cliente_id
WHERE o.cliente_id = 1
ORDER BY o.fecha_pedido;

-- Productos de un pedido específico
SELECT o.pedido_id, p.nombre_producto, d.cantidad, d.precio_unitario
FROM pedidos o
JOIN detalle_pedido d ON o.pedido_id = d.pedido_id
JOIN productos p      ON d.producto_id = p.producto_id
WHERE o.pedido_id = 100;

-- Clientes sin ningún pedido
SELECT c.cliente_id, c.nombre_completo
FROM clientes c
LEFT JOIN pedidos o ON c.cliente_id = o.cliente_id
WHERE o.pedido_id IS NULL;
```

### Validaciones de integridad

```sql
-- Pedidos en estado 'confirmado' sin ningún pago aprobado
SELECT o.pedido_id, o.estado_actual, o.total_pedido
FROM pedidos o
LEFT JOIN pagos p
    ON o.pedido_id = p.pedido_id
    AND p.estado_pago = 'aprobado'
WHERE o.estado_actual = 'confirmado'
AND p.pago_id IS NULL;

-- Pedidos sin ningún ítem de detalle
SELECT o.pedido_id, o.estado_actual
FROM pedidos o
LEFT JOIN detalle_pedido d ON o.pedido_id = d.pedido_id
WHERE d.detalle_id IS NULL;

-- Productos que nunca fueron vendidos
SELECT p.producto_id, p.nombre_producto, p.categoria
FROM productos p
LEFT JOIN detalle_pedido d ON p.producto_id = d.producto_id
WHERE d.detalle_id IS NULL;
```

---

## Índices y performance

```sql
-- Índices en todas las FK (el motor no los crea automáticamente)
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente_id    ON pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_id     ON detalle_pedido(pedido_id);
CREATE INDEX IF NOT EXISTS idx_detalle_producto_id   ON detalle_pedido(producto_id);
CREATE INDEX IF NOT EXISTS idx_pagos_pedido_id       ON pagos(pedido_id);
CREATE INDEX IF NOT EXISTS idx_historial_pedido_id   ON historial_estados(pedido_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_pedido_id   ON auditoria_pedidos(pedido_id);

-- Índices en columnas de filtro frecuente
CREATE INDEX IF NOT EXISTS idx_pedidos_estado        ON pedidos(estado_actual);
CREATE INDEX IF NOT EXISTS idx_pagos_estado          ON pagos(estado_pago);
```

**Benchmark real:**

```
Sin índice (SCAN):   5.998 segundos  → recorre todas las filas
Con índice (SEARCH): 0.030 segundos  → va directo al dato

Mejora: 199x más rápido
```

---

## Seguridad — SQL Injection

```python
# VULNERABLE: el atacante puede ejecutar cualquier SQL
query = "SELECT * FROM clientes WHERE nombre = '" + input_usuario + "'"

# SEGURO: el ? nunca se interpreta como SQL
cursor.execute("SELECT * FROM clientes WHERE nombre = ?", (input_usuario,))
```

Con el input `' OR '1'='1' --`:

- Versión vulnerable: devuelve **todos los registros** de la tabla
- Versión segura: devuelve **0 registros**

Las consultas parametrizadas no mitigan SQL Injection, la eliminan estructuralmente. El motor compila el SQL primero y recibe los datos después. En ese punto la compilación ya terminó y ningún valor puede convertirse en código.

---

## Cómo ejecutar

```bash
# 1. Clonar el repositorio
git clone https://github.com/usuario/penguin-academy-sql

# 2. Instalar dependencias
pip install pandas

# 3. Crear las tablas
# Ejecutar celda 1 del notebook (carga schema.sql)

# 4. Insertar los datos
# Ejecutar el pipeline universal con insercion_datos(diccionario_datos)

# 5. Ejecutar las consultas
# Abrir queries.sql en VSCode o ejecutar desde el notebook
```

---

## Lecciones aprendidas

El modelado relacional no es un ejercicio técnico. Es un ejercicio de comprensión del dominio. Los constraints no son restricciones arbitrarias, son reglas de negocio formalizadas en la estructura. Los rechazos no son errores del sistema, son el sistema funcionando. Y la diferencia entre un modelo que funciona y uno que se puede defender es la capacidad de justificar cada decisión con el dominio real, no con preferencias técnicas.

---

_Penguin Academy SQL Challenge — construido con criterio, defendible en cada línea._
