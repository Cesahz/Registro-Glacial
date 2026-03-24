import sqlite3

print("--- INICIANDO DESPLIEGUE ---")

#crear y conectar a la base de datos
conn = sqlite3.connect('base_de_datos.db')
cursor = conn.cursor()

#activar claves foraneas
cursor.execute("PRAGMA foreign_keys = ON;")

#leer y ejecutar el archivo sql schema
with open('schema.sql', 'r', encoding='utf-8') as archivo_sql:
    script_ddl = archivo_sql.read()

try:
    cursor.executescript(script_ddl)
    conn.commit()
    print("Base de datos levantada: schema.sql ejecutado con éxito.")
except sqlite3.Error as e:
    print(f"Error crítico al levantar la base de datos: {e}")

conn.close()