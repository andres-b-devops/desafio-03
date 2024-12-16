#!/usr/bin/env bash

###############################################################################
# Configuración inicial del script
###############################################################################
#
#  Por: Andrés Burbano
#
# set -euo pipefail:
# -e: Si algún comando retorna un estado distinto a 0, se detiene el script.
# -u: Si se usa una variable no definida, se considera error y se detiene el script.
# -o pipefail: Si un comando en una cadena (pipe) falla, se considera error general.
#
# Estas configuraciones ayudan a asegurar que cualquier fallo se detecte
# inmediatamente, evitando comportamientos inesperados.
#
set -euo pipefail

# Atrapar señales de interrupción (ej. Ctrl+C) y terminación
trap 'echo " Script interrumpido por el usuario"; exit 1' INT TERM

###############################################################################
# Funciones de ayuda
###############################################################################

# Función para imprimir un encabezado del informe con el nombre del host
print_header() {
    echo "====================================================="
    echo "              INFORME DEL SISTEMA: $(hostname -s)"
    echo "====================================================="
}

# Función para imprimir la fecha y hora actual en formato DD/MM/YYYY HH:MM:SS
print_datetime() {
    echo "Fecha y Hora: $(date '+%d/%m/%Y %H:%M:%S')"
    echo ""
}

# Imprimir el uso de disco de la partición raíz
get_root_space() {
    local mount_point="$1"
    local disk_usage
    # Se obtiene la columna correspondiente al uso (porcentaje)
    disk_usage=$(df -h "$mount_point" | awk 'NR > 1 {print $5}')

    echo "+---------------------------------------------------+"
    echo "| Uso del Disco en $mount_point: $disk_usage"
    echo "+---------------------------------------------------+"
    echo ""
}

# Imprimir los usuarios actualmente logueados en el sistema
print_logged_in_users() {
    echo "+---------------------------------------------------+"
    echo "| Usuarios actualmente logueados:"
    echo "+---------------------------------------------------+"
    # Usar who y awk para listar los usuarios
    who | awk '{print "| " $1}'
    echo "+---------------------------------------------------+"
    echo ""
}


###############################################################################
# Funciones para formatear la tabla de procesos
###############################################################################
#
# Se define un ancho fijo para cada columna, y se imprime una tabla ASCII.
#
# Columnas del comando ps aux:
# USER      PID  %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
#
# Definimos anchos de columna aproximados:
# USER: 10
# PID:  8
# %CPU: 5
# %MEM: 5
# VSZ:  8
# RSS:  8
# TTY:  8
# STAT: 5
# START:10
# TIME: 10
# COMMAND: 50 (con ajuste de línea si excede)
#
# Nota: El COMMAND puede contener espacios. Por ello, se capturan todos los 
# campos desde el 11 en adelante.

COL_USER_WIDTH=10
COL_PID_WIDTH=8
COL_CPU_WIDTH=5
COL_MEM_WIDTH=5
COL_VSZ_WIDTH=8
COL_RSS_WIDTH=8
COL_TTY_WIDTH=8
COL_STAT_WIDTH=5
COL_START_WIDTH=10
COL_TIME_WIDTH=10
COL_CMD_WIDTH=60

# Función para repetir un carácter n veces
repeat_char() {
    local char="$1"
    local count="$2"
    printf "%${count}s" | tr ' ' "$char"
}

# Función para imprimir la línea divisoria de la tabla
print_divider() {
    echo "+$(repeat_char '-' $COL_USER_WIDTH)+$(repeat_char '-' $COL_PID_WIDTH)+$(repeat_char '-' $COL_CPU_WIDTH)+$(repeat_char '-' $COL_MEM_WIDTH)+$(repeat_char '-' $COL_VSZ_WIDTH)+$(repeat_char '-' $COL_RSS_WIDTH)+$(repeat_char '-' $COL_TTY_WIDTH)+$(repeat_char '-' $COL_STAT_WIDTH)+$(repeat_char '-' $COL_START_WIDTH)+$(repeat_char '-' $COL_TIME_WIDTH)+$(repeat_char '-' $COL_CMD_WIDTH)+"
}

# Función para imprimir el encabezado de la tabla
print_header_table() {
    print_divider
    printf "|%-${COL_USER_WIDTH}s|%-${COL_PID_WIDTH}s|%-${COL_CPU_WIDTH}s|%-${COL_MEM_WIDTH}s|%-${COL_VSZ_WIDTH}s|%-${COL_RSS_WIDTH}s|%-${COL_TTY_WIDTH}s|%-${COL_STAT_WIDTH}s|%-${COL_START_WIDTH}s|%-${COL_TIME_WIDTH}s|%-${COL_CMD_WIDTH}s|\n" \
        "USER" "PID" "%CPU" "%MEM" "VSZ" "RSS" "TTY" "STAT" "START" "TIME" "COMMAND"
    print_divider
}

# Función para imprimir una fila de la tabla.
# Si la columna COMMAND excede el ancho, se partirá en varias líneas.
print_process_line() {
    local user="$1"
    local pid="$2"
    local cpu="$3"
    local mem="$4"
    local vsz="$5"
    local rss="$6"
    local tty="$7"
    local stat="$8"
    local start="$9"
    local time="${10}"
    shift 10
    local command="$*"

    # Usar fold para dividir la columna COMMAND en líneas de máximo COL_CMD_WIDTH caracteres
    # fold -s corta por palabras, evitando partir las palabras a la mitad si es posible.
    local folded_command
    folded_command=$(echo "$command" | fold -s -w "$COL_CMD_WIDTH")

    # El comando ahora puede tener varias líneas. Las procesaremos una por una.
    local first_line=true
    while IFS= read -r line; do
        if $first_line; then
            # Primera línea: imprimir todas las columnas
            printf "|%-${COL_USER_WIDTH}.${COL_USER_WIDTH}s|%-${COL_PID_WIDTH}.${COL_PID_WIDTH}s|%-${COL_CPU_WIDTH}.${COL_CPU_WIDTH}s|%-${COL_MEM_WIDTH}.${COL_MEM_WIDTH}s|%-${COL_VSZ_WIDTH}.${COL_VSZ_WIDTH}s|%-${COL_RSS_WIDTH}.${COL_RSS_WIDTH}s|%-${COL_TTY_WIDTH}.${COL_TTY_WIDTH}s|%-${COL_STAT_WIDTH}.${COL_STAT_WIDTH}s|%-${COL_START_WIDTH}.${COL_START_WIDTH}s|%-${COL_TIME_WIDTH}.${COL_TIME_WIDTH}s|%-${COL_CMD_WIDTH}.${COL_CMD_WIDTH}s|\n" \
                "$user" "$pid" "$cpu" "$mem" "$vsz" "$rss" "$tty" "$stat" "$start" "$time" "$line"
            first_line=false
        else
            # Siguientes líneas: imprimir las columnas vacías (para alineación) y solo COMMAND
            printf "|%-${COL_USER_WIDTH}s|%-${COL_PID_WIDTH}s|%-${COL_CPU_WIDTH}s|%-${COL_MEM_WIDTH}s|%-${COL_VSZ_WIDTH}s|%-${COL_RSS_WIDTH}s|%-${COL_TTY_WIDTH}s|%-${COL_STAT_WIDTH}s|%-${COL_START_WIDTH}s|%-${COL_TIME_WIDTH}s|%-${COL_CMD_WIDTH}.${COL_CMD_WIDTH}s|\n" \
                "" "" "" "" "" "" "" "" "" "" "$line"
        fi
    done <<< "$folded_command"
}

# Función para imprimir todos los procesos encontrados en una tabla formateada
print_processes_table() {
    local procesos="$1"

    # Imprimir encabezado
    print_header_table

    # Procesar cada línea de procesos
    # Saltar la línea que corresponde al grep -v grep (ya no se debe incluir esa)
    while IFS= read -r line; do
        # Evitar líneas vacías
        [[ -z "$line" ]] && continue

        # Dividir la línea en campos.
        # ps aux produce: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND...
        # Necesitamos: USER(1) PID(2) CPU(3) MEM(4) VSZ(5) RSS(6) TTY(7) STAT(8) START(9) TIME(10) COMMAND(11+)
        # Usaremos 'set --' para asignar cada campo a $1, $2, ...
        set -- $line

        user="$1"
        pid="$2"
        cpu="$3"
        mem="$4"
        vsz="$5"
        rss="$6"
        tty="$7"
        stat="$8"
        start="$9"
        time="${10}"

        # El comando inicia a partir de $11
        shift 10
        command="$*"

        print_process_line "$user" "$pid" "$cpu" "$mem" "$vsz" "$rss" "$tty" "$stat" "$start" "$time" "$command"
    done <<< "$procesos"

    # Imprimir línea final
    print_divider
    echo ""
}

###############################################################################
# Función para buscar proceso
###############################################################################
#
# Esta función solicita al usuario el nombre de un proceso a buscar y muestra
# los resultados en una tabla formateada. Si no se encuentran resultados,
# se le pide al usuario que ingrese otro nombre hasta que se obtenga uno válido.

search_process() {
    while true; do
        read -r -p "Ingrese el proceso que desea buscar: " proceso
        echo ""

        # Validar que el usuario haya ingresado un nombre de proceso
        if [[ -z "$proceso" ]]; then
            echo "Debe ingresar un nombre de proceso. Inténtelo de nuevo."
            echo ""
            continue
        fi

        # Buscar el proceso ignorando mayúsculas/minúsculas. Excluimos la propia búsqueda (grep).
        # Usamos || true para que el script no finalice si grep no encuentra nada.
        procesos_encontrados=$(ps aux | grep -i "$proceso" | grep -v grep || true)

        if [[ -z "$procesos_encontrados" ]]; then
            echo "No se encontraron procesos con el nombre '$proceso'. Inténtelo de nuevo."
        else
            echo "Se encontraron los siguientes procesos con el nombre '$proceso':"
            print_processes_table "$procesos_encontrados"
            break
        fi
    done
}

###############################################################################
# Función principal
###############################################################################

main() {
    print_header
    print_datetime
    get_root_space "/"
    print_logged_in_users
    search_process
    echo "Fin del informe."
}

###############################################################################
# Ejecución del script
###############################################################################

main