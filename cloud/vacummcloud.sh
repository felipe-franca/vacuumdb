#!/usr/bin/env sh

export PGUSER=postgres
export PGPASSWORD=#change it

HOST_IP="10.27.192.3"
PSQL="psql -U postgres -h $HOST_IP -c "

dbs=$($PSQL "SELECT datname FROM pg_database a WHERE datname LIKE '%-enterprise-%'" --tuples-only)

for db in $dbs; do
    echo "Banco -> $db"
    pPSQL="psql -U postgres -h $HOST_IP -d $db -c "

    TABLES=($($pPSQL "SELECT DISTINCT tablename  from (select t1.relname as tablename, t2.nspname as schema, t2.nspname || '.' ||t1.relname as schema_table, t1.reltuples as qtd_reg, t1.relowner from pg_catalog.pg_class t1 join pg_catalog.pg_namespace t2 on (t1.relnamespace = t2.oid) where t2.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and t1.relkind = 'r') as tbs where  pg_total_relation_size(schema_table) >= 606650368" --tuples-only))

    execParams() {
        local ARRAY_ARGS=("${!2}")

        if [ "$1" = "QUERY" ]; then
            echo "[INFO] Parameters passed to function execParams: $1 | ${#ARRAY_ARGS[@]}"
            echo "[INFO] Perform operation: $1"
            for ((y = 0; y < ${#ARRAY_ARGS[@]}; y++)); do
                echo "[INFO] Operation '$1' started the ${ARRAY_ARGS[y]} table - $(date +%T)"
                echo "[INFO] $pPSQL \"${ARRAY_ARGS[y]};\""
                $PSQL "${ARRAY_ARGS[y]};"
                if [ $? -ne 0 ]; then
                    echo "[WARN] Something wrong -> $1 | ${ARRAY_ARGS[y]} "
                else
                    echo "[INFO] Succesfuly."
                fi
                echo "[INFO] Finalized '$1' operation on ${ARRAY_ARGS[y]} table - $(date +%T)"
            done
            return 0
        else
            echo "[INFO] Parameters passed to function execParams: $1 | ${#ARRAY_ARGS[@]}"
            echo "[INFO] Perform operation: $1"
            for ((y = 0; y < ${#ARRAY_ARGS[@]}; y++)); do
                echo "[INFO] Operation '$1' started the ${ARRAY_ARGS[y]} table - $(date +%T)"
                echo "[INFO] $pPSQL \"$1 ${ARRAY_ARGS[y]};\""
                $pPSQL "$1 ${ARRAY_ARGS[y]};"
                if [ $? -ne 0 ]; then
                    echo "[WARN] Something wrong -> $1 | ${ARRAY_ARGS[y]} "
                else
                    echo "[INFO] Succesfuly."
                fi
                echo "[INFO] Finalized '$1' operation on ${ARRAY_ARGS[y]} table - $(date +%T)"
            done
            return 0
        fi
    }

    echo "Maintenance will be started on database: $db"

    echo "[INFO] Maintenance tables: ${TABLES[@]}"

    OPERATION=("VACUUM FULL" "REINDEX TABLE")

    echo "[INFO - INIT] Starting maintenance processes: ${!OPERATION[@]} -> ${OPERATION[@]}"

    for ((i = 0; i < ${#OPERATION[@]}; i++)); do

        if [ "${OPERATION[i]}" = "QUERY" ]; then
            if [ -z "${QUERY[i]}" ]; then
                echo "[WARN] No query to execute."
                continue
            else
                echo "[INFO] Calls maintenance function."
                echo "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#QUERY[@]} | statement: ${QUERY[@]}"
                execParams "${OPERATION[i]}" "QUERY[@]"
                echo "[INFO] Operation ${OPERATION[i]} ended."
            fi
        elif [ "${OPERATION[i]}" = "VACUUM FULL" ] || [ "${OPERATION[i]}" = "REINDEX TABLE" ]; then
            echo "[INFO] Calls maintenance function."
            echo "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#TABLES[@]} | tables: ${TABLES[@]}"
            execParams "${OPERATION[i]}" "TABLES[@]"
            echo "[INFO] Operation ${OPERATION[i]} ended."

        else
            echo "[WARN] Unknow Operation."
            continue
        fi
    done
    echo "[INFO] >>>> Maintenance Finished on database $db <<<<<"
done
