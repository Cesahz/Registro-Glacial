import csv, sqlite3

#conexion y seguridad
conn = sqlite3.connect('base_de_datos.db')
cursor = conn.cursor()
cursor.execute("PRAGMA foreign_keys = ON;")
diccionario_datos = {
    "customers": "data/customers.csv",
    "products": "data/products.csv",
    "orders": "data/orders.csv",
    "payments": "data/payments.csv",
    "order_items": "data/order_items.csv",
    "order_status_history": "data/order_status_history.csv",
    "order_audit": "data/order_audit.csv"
}
#motor de insercion de datos global
def insercion_datos(dic_datos: dict):
    for tabla,ruta_archivo in dic_datos.items():
        exitos, rechazos = 0, 0
        motivos_rechazo = {} #diccionario para contar los errores

    #inicio del motor
        with open(ruta_archivo, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            columnas = reader.fieldnames
            nombres_cols = ", ".join(columnas)
            comodines = ", ".join(["?"] * len(columnas))
            sql = f"INSERT INTO {tabla} ({nombres_cols}) VALUES ({comodines})"

            for fila in reader:
                datos = tuple(None if fila[col] == '' else fila[col] for col in columnas)

                try:
                    cursor.execute(sql, datos)
                    exitos += 1
                except sqlite3.Error as error_motor:
                    rechazos += 1
                    #capturar el error del motor y lo guardamos en una variable
                    mensaje = str(error_motor)

                    #si el error ya existe en nuestro registro, le suma 1, si no existe lo crea
                    if mensaje in motivos_rechazo:
                        motivos_rechazo[mensaje] += 1
                    else:
                        motivos_rechazo[mensaje] = 1

        #reporte de inteligencia
        conn.commit()
        print(f"--- REPORTE DE INYECCIÓN: {tabla.upper()} ---")
        print(f" Insertados: {exitos}")
        print(f" Rechazados: {rechazos}")

        #imprimir el analisis de errores
        if rechazos > 0:
            print("\n--- DIAGNÓSTICO CLÍNICO DE RECHAZOS ---")
            for motivo, cantidad in motivos_rechazo.items():
                print(f" {cantidad} filas rebotaron por: {motivo}")



print("INICIANDO PIPELINE DE INYECCIÓN MASIVA...")
insercion_datos(diccionario_datos)

conn.close()