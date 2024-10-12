#!/bin/bash

# Carpeta donde estarán los archivos .sql
SQL_DIR="/docker-entrypoint-initdb.d/scripts/sql"

# Crear el usuario no root y darle privilegios si no existe
create_user_if_not_exists() {
    local user_exists=$(mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$MYSQL_USER');" | grep 1 > /dev/null; echo "$?")
    
    if [ $user_exists -ne 0 ]; then
        echo "Creando usuario $MYSQL_USER..."
        mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';"
        echo "Usuario $MYSQL_USER creado con éxito."
    else
        echo "El usuario $MYSQL_USER ya existe."
    fi
}

# Función para restaurar bases de datos
restore_database() {
    local sql_file=$1
    local db_name=$(basename "$sql_file" .sql) # Extrae el nombre de la base de datos desde el archivo
    echo "Restaurando la base de datos: $db_name desde $sql_file"

    # Verifica si la base de datos ya existe
    DB_EXISTS=$(mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES LIKE '$db_name';" | grep "$db_name" > /dev/null; echo "$?")
    
    # Si la base de datos no existe, la crea y la restaura
    if [ $DB_EXISTS -ne 0 ]; then
        echo "Creando la base de datos $db_name..."
        mysql -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE $db_name;"
        mysql -u root -p$MYSQL_ROOT_PASSWORD $db_name < "$sql_file"
        echo "Base de datos $db_name restaurada."

        # Otorgar privilegios al usuario no root sobre la base de datos recién creada
        mysql -u root -p$MYSQL_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$MYSQL_USER'@'%';"
        echo "Permisos otorgados al usuario $MYSQL_USER en la base de datos $db_name."
    else
        echo "La base de datos $db_name ya existe, no se restaura."
    fi
}

# Crear el usuario no root si es necesario
create_user_if_not_exists

# Recorrer todos los archivos .sql en el directorio
for sql_file in $SQL_DIR/*.sql; do
    if [ -f "$sql_file" ]; then
        restore_database "$sql_file"
    else
        echo "No se encontraron archivos .sql en $SQL_DIR"
    fi
done