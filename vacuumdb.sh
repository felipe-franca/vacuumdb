#!/usr/bin/env sh

if [ -e "/etc/rsyslog.d/dbmaintenance.conf" ]; then
    break;
else
    echo -e "local0.*\t/var/log/dbmaintenance.log" > /etc/rsyslog.d/dbmaintenance.conf;
    systemctl restart rsyslog.service
fi

echo > /var/log/dbmaintenance.log

DOLOG="logger -p local0.debug -t [DEBUG] [$0] "
$DOLOG "[INFO] Logger init."
exec 1>>/var/log/dbmaintenance.log
exec 2>&1

for db in $@; do

    DB="$db"
    CONTAINER="$(docker ps | grep db: | cut  -d ' ' -f1)"
    PSQL="/bin/docker exec -i $CONTAINER psql -U postgres -d $DB -c"
    EXIT_CODE=0

    MAIN_TABLES=(
        "sincronizacao_enterprise"
        "ticketmobile"
        "cartoes"
        "ociosidade"
        "ociosidadeporgrupo"
        "valorcontador"
        "lot"
        "movimento_por_horario"
        "estatistica_por_permanencia"
        "configuracoes"
        "detalhetickets"
        "somas_faturamento_trn"
        "somas_tipo_trn"
        "somaspermanencia"
        "somas_pagamento_trn"
        "somas_pagamento_trn_parcial"
        "somas_vendas_trn"
        "somas_fechafinan_arrecadacao_trn"
        "estat_permanencia_pos_pagto"
        "dailies"
        "somas"
        "somasparcial"
        "estatistica_por_permanencia_setor"
        "valores_parcial"
        "valores"
        "receita_por_tarifa_parcial"
        "receita_por_tarifa_vendas"
        "estatistica_pagantes_abonados"
        "receita_por_tarifa"
        "patio"
        "recibos"
        );

    TRUNC_TABLES=(
        "arqueo"
        "seqs_uruguai_por_terminal"
        "seqs_uruguai_por_terminal_parcial"
        "controle_sequenciais_uruguai"
        "ppmestadoestacao"
        "sinalcontagem"
        "etstickets_temp"
        "imagenslpr"
        );

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
                $DOLOG "[INFO] Finalized '$1' operation on ${ARRAY_ARGS[y]} table - $(date +%T)"
            done
            return 0;
        fi
    }

    $DOLOG "Container id - $CONTAINER - database: $DB"

    $DOLOG "[INFO] Maintenance tables:: ${MAIN_TABLES[@]}"
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
                    EXIT_CODE=$?
                $DOLOG "[INFO] Operation ended."
            fi
        elif [ "${OPERATION[i]}" = "TRUNCATE TABLE" ]; then
            $DOLOG "[INFO] Calls maintenance function."
            $DOLOG "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#TRUNC_TABLES[@]} | tables: ${TRUNC_TABLES[@]}"
                execParams "${OPERATION[i]}" "TRUNC_TABLES[@]"
                EXIT_CODE=$?
            $DOLOG "[INFO] Operation ended."

        elif [ "${OPERATION[i]}" = "VACUUM FULL ANALYSE VERBOSE" ] || [ "${OPERATION[i]}" = "REINDEX TABLE" ]; then
            $DOLOG "[INFO] Calls maintenance function."
            $DOLOG "[INFO] Call: execParams | operation: ${OPERATION[i]} | Quantity: ${#MAIN_TABLES[@]} | tables: ${MAIN_TABLES[@]}"
                execParams "${OPERATION[i]}" "MAIN_TABLES[@]"
                EXIT_CODE=$?
            $DOLOG "[INFO] Operation ended."

        else
            $DOLOG "[WARN] Unknow Operation."
            break;
        fi

        if [ ! $EXIT_CODE -eq 0 ]; then
            $DOLOG "[ERROR] Exit code: $EXIT_CODE on operation ${OPERATION[i]}."
        fi
    done
done