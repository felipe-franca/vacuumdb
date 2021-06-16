#!/usr/bin/env sh

if [ ! -e "/etc/rsyslog.d/dbmaintenance.conf" ]; then
    echo -e "local0.*\t/var/log/dbmaintenance.log" > /etc/rsyslog.d/dbmaintenance.conf;
    systemctl restart rsyslog.service
fi

DOLOG="logger -p local0.debug -t [DEBUG] [$0] "
$DOLOG "[INFO] >>>> Logger Init <<<<<"
exec 1>>/var/log/dbmaintenance.log
exec 2>&1

for db in $@; do

    DB="$db"
    CONTAINER="$(docker ps | grep db: | cut  -d ' ' -f1)"
    PSQL="/bin/docker exec -i $CONTAINER psql -U postgres -d $DB -c"
    EXIT_CODE=0
    KILL_LONG_CONNECTIONS="SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE query_start <= ( now() - INTERVAL '2 hours')  and datname = '$DB'"

    MAIN_TABLES=( "sincronizacao_enterprise" "ticketmobile" "cartoes" "ociosidade"
                  "ociosidadeporgrupo" "valorcontador" "lot" "movimento_por_horario"
                  "estatistica_por_permanencia" "configuracoes" "detalhetickets" "somas_faturamento_trn"
                  "somas_tipo_trn" "somaspermanencia" "somas_pagamento_trn" "somas_pagamento_trn_parcial"
                  "somas_vendas_trn" "somas_fechafinan_arrecadacao_trn" "estat_permanencia_pos_pagto" "dailies"
                  "somas" "somasparcial" "estatistica_por_permanencia_setor" "valores_parcial" "valores"
                  "receita_por_tarifa_parcial" "receita_por_tarifa_vendas" "estatistica_pagantes_abonados" 
                  "receita_por_tarifa" "patio" "recibos" );

    TRUNC_TABLES=( "arqueo" "seqs_uruguai_por_terminal" "seqs_uruguai_por_terminal_parcial"
                   "controle_sequenciais_uruguai" "ppmestadoestacao" "sinalcontagem" "etstickets_temp" "imagenslpr" );

    QUERY=

    function execParams() {
        local ARRAY_ARGS=("${!2}")

        if [ "$1" = "QUERY" ]; then
            $DOLOG "[INFO] Parameters passed to function execParams: $1 | ${#ARRAY_ARGS[@]}"
            $DOLOG "[INFO] Perform operation: $1"
                for(( y = 0; y < ${#ARRAY_ARGS[@]}; y++ )); do
                    $DOLOG "[INFO] Operation '$1' started the ${ARRAY_ARGS[y]} table - $(date +%T)"
                    $DOLOG "[INFO] $PSQL \"${ARRAY_ARGS[y]};\""
                        $PSQL "${ARRAY_ARGS[y]};"
                    if [ $? -ne 0 ]; then
                        $DOLOG "[WARN] Something wrong -> $1 | ${ARRAY_ARGS[y]} "
                    else
                        $DOLOG "[INFO] Succesfuly."
                    fi
                $DOLOG "[INFO] Finalized '$1' operation on ${ARRAY_ARGS[y]} table - $(date +%T)"
            done
            return 0;
        else
            $DOLOG "[INFO] Parameters passed to function execParams: $1 | ${#ARRAY_ARGS[@]}"
            $DOLOG "[INFO] Perform operation: $1"
                for(( y = 0; y < ${#ARRAY_ARGS[@]}; y++ )); do
                    $DOLOG "[INFO] Operation '$1' started the ${ARRAY_ARGS[y]} table - $(date +%T)"
                    $DOLOG "[INFO] $PSQL \"$1 ${ARRAY_ARGS[y]};\""
                        $PSQL "$1 ${ARRAY_ARGS[y]};"
                    if [ $? -ne 0 ]; then
                        $DOLOG "[WARN] Something wrong -> $1 | ${ARRAY_ARGS[y]} "
                    else 
                        $DOLOG "[INFO] Succesfuly."
                    fi
                $DOLOG "[INFO] Finalized '$1' operation on ${ARRAY_ARGS[y]} table - $(date +%T)"
            done
            return 0;
        fi
    }

    $DOLOG "Maintenance will be started on Container id - $CONTAINER - database: $DB"
    $DOLOG "[INFO] Cheking long connections . . ."

    HAVE_LONG_CON=$($PSQL "SELECT count(procpid) FROM pg_catalog.pg_stat_activity WHERE query_start <= (now() - INTERVAL '2 hours') and datname like '$DB';" --tuples-only | sed 's/ //g')

    $DOLOG "[DEBUG] QTD long connectios: $HAVE_LONG_CON "

    [ "$HAVE_LONG_CON" ] || HAVE_LONG_CON=0

    if [ $HAVE_LONG_CON -gt 0 ]; then
        $DOLOG "[INFO] Killing longconnections . . ."
            $DOLOG "[DEBUG] QUERY: $PSQL $KILL_LONG_CONNECTIONS "
            $PSQL "$KILL_LONG_CONNECTIONS"
        if [ $? -eq 0 ]; then
            $DOLOG "[INFO] Done !"
        else
            $DOLOG "[WARN] Something wrong in execution var KILL_LOG_CONNECTIONS."
        fi
    else
        $DOLOG "[INFO] No long connectios found ! : $HAVE_LONG_CON"
    fi

    $DOLOG "[INFO] Maintenance tables: ${MAIN_TABLES[@]}"
    $DOLOG "[INFO] Tables to be truncated: ${TRUNC_TABLES[@]}"

    OPERATION=( "QUERY" "TRUNCATE TABLE" "VACUUM FULL ANALYSE VERBOSE" "REINDEX TABLE" )

    $DOLOG "[INFO - INIT] Starting maintenance processes: ${!OPERATION[@]} -> ${OPERATION[@]}"

    for((i=0; i<${#OPERATION[@]}; i++)); do

        if [ "${OPERATION[i]}" = "QUERY" ]; then
            if [ -z "${QUERY[i]}" ]; then
                $DOLOG "[WARN] No query to execute."
                continue;
            else
                $DOLOG "[INFO] Calls maintenance function."
                $DOLOG "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#QUERY[@]} | statement: ${QUERY[@]}"
                    execParams "${OPERATION[i]}" "QUERY[@]"
                $DOLOG "[INFO] Operation ${OPERATION[i]} ended."
            fi
        elif [ "${OPERATION[i]}" = "TRUNCATE TABLE" ]; then
            $DOLOG "[INFO] Calls maintenance function."
            $DOLOG "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#TRUNC_TABLES[@]} | tables: ${TRUNC_TABLES[@]}"
                execParams "${OPERATION[i]}" "TRUNC_TABLES[@]"
            $DOLOG "[INFO] Operation ${OPERATION[i]} ended."

        elif [ "${OPERATION[i]}" = "VACUUM FULL ANALYSE VERBOSE" ] || [ "${OPERATION[i]}" = "REINDEX TABLE" ]; then
            $DOLOG "[INFO] Calls maintenance function."
            $DOLOG "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#MAIN_TABLES[@]} | tables: ${MAIN_TABLES[@]}"
                execParams "${OPERATION[i]}" "MAIN_TABLES[@]"
            $DOLOG "[INFO] Operation ${OPERATION[i]} ended."

        else
            $DOLOG "[WARN] Unknow Operation."
            continue;
        fi
    done
    $DOLOG "[INFO] >>>> Maintenance Finished on database $DB <<<<<"
done
