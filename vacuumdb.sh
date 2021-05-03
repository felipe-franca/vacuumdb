#!/usr/bin/env bash

# cria configuracoes para o gerador de log rsyslog
if [ -e "/etc/rsyslog.d/vacuumdb.conf" ]; then
    break
else 
    echo -e "local0.*\t/var/log/pingchecker.log" > /etc/rsyslog.d/vacuumdb.conf
    systemctl restart rsyslog
fi

DOLOG="logger -p local0.debug -t [DEBUG] [$0]"

CONTAINER=$(docker ps | grep db: | cut -d ' ' -f 1)
DOCKER="docker exec -i $CONTAINER psql -U postgres -d parkingplus -c"

$DOLOG "Container id: $CONTAINER"

$DOLOG "Inicializando script de manutencao banco as $(date +%T)"

QUERY="UPDATE recibo_provisorio_servicos \
    SET \
        tipocpfcnpj = 2, cpf_cnpj = '', im = '', nome_razaosocial = '', tipoendereco = '', endereco = '', \
        numero = '', complemento = '', bairro = '', cidade = '', uf = '', cep = 0, email = '', ie = '' \
    WHERE \
        DATA >=(current_date - '1 day'::INTERVAL) \
        AND tipocpfcnpj = 0 \
        AND ( nome_razaosocial = '' OR nome_razaosocial IS NULL);"

$DOLOG "Executando manutencao recibo_provisorio_servicos para tomadores não declarados: "
$DOLOG "$QUERY"

$DOCKER "$QUERY"

