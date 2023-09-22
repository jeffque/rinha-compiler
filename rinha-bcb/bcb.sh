#!/usr/bin/env bash

declare -a STACK
declare -a NAME

function add_constant_literal() {
    local cte="$1"
    local -i pos=${#STACK[@]}
    
    STACK[$pos]="$cte"

    if [ $# = 2 ]; then
        local name="$2"
        NAME[$pos]="$name"
    fi
}

function add_function() {
    local nargs="$1"
    local fname="$2"

    add_constant_literal "&$nargs#$fname" "$fname"
}

function add_constant_int() {
    local -i n="$1"

    if [ $# = 2 ]; then
        add_constant_literal "#$n" "$2"
    else
        add_constant_literal "#$n"
    fi
}

function add_constant_string() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"

    if [ $# = 2 ]; then
        add_constant_literal "\$\"$s\"" "$2"
    else
        add_constant_literal "\$\"$s\""
    fi
}

function add_to_stack_unary_external_functions() {
    local unary_functions=( print first second )
    for f in "${unary_functions[@]}"; do
        add_function 1 "$f"
    done
}

function add_to_stack_binary_external_functions() {
    local binary_functions=( 
            add subtract multiply division remainder 
            equal nequal
            lesser_than lesser_equal greater_than greater_equal
            and or
            tuple
        )
    for f in "${binary_functions[@]}"; do
        add_function 2 "$f"
    done
}

add_to_stack_unary_external_functions
add_to_stack_binary_external_functions

function extract_type() {
    local dif="${1::1}"
    case "$dif" in
        '#') echo "INT" ;;
        '$') echo "STR" ;;
        '(') echo TUPLE ;; 
        T) echo TRUE ;;
        F) echo FALSE ;;
        *) echo CLOSURE ;;
    esac
}

function string_representation_tuple() {
    local TUPLE="$1"
    local LHS=`extract_first_element_tuple "${TUPLE}"`
    local RHS=`extract_second_element_tuple "${TUPLE}"`

    echo "(`string_representation "$LHS"`, `string_representation "$RHS"`)"
}

function extract_string() {
    local RET="${1:2}"
    RET="${RET%\"}"
    RET="${RET//\\\\/\\}"
    RET="${RET//\\\"/\"}"
    echo "$RET"
}

function extract_int() {
    echo "${1:1}"
}

function extract_X_element_tuple() {
    local TUPLE="$1"
    local firstOrSecond="$2"
    local -i TUPLE_LEN=${#TUPLE}
    local -i level=0
    local c
    local -i i
    for (( i=0; i < TUPLE_LEN; i++ )) do
        c="${TUPLE:$i:1}"
        if [ "$c" = '$' ]; then
            # SKIP STRING
            # skipping the $", search for the closing "
            for (( i+=2 ; i < TUPLE_LEN; i++ )) do
                c="${TUPLE:$i:1}"
                if [ "$c" = '\' ]; then
                    # if sca[e, ignore next char
                    i+=1
                elif [ "$c" = '"' ]; then
                    # closing ", breaking loop
                    break
                fi
            done
        elif [ "$c" = '(' ]; then
            level+=1
        elif [ "$c" = ')' ]; then
            level+=-1
        elif [ "$level" = 1 -a "$c" = ',' ]; then
            # ACHOU!
            if [ "${firstOrSecond}" = first ]; then
                local -i x
                x=$i-1
                echo "${TUPLE:1:$x}"
            else
                local -i x
                x=$i+1
                local -i end
                end=$TUPLE_LEN-$x-1
                echo "${TUPLE:$x:$end}"
            fi
            return
        fi
    done
}

function extract_first_element_tuple() {
    local TUPLE="$1"
    extract_X_element_tuple "$TUPLE" first
}

function extract_second_element_tuple() {
    local TUPLE="$1"
    extract_X_element_tuple "$TUPLE" second
}

function first() {
    extract_first_element_tuple "$1"
}

function second() {
    extract_second_element_tuple "$1"
}

function tuple() {
    local LHS="$1"
    local RHS="$2"

    echo "($LHS,$RHS)"
}

function lesser_than() {
    local -i LHS=`extract_int "$1"`
    local -i RHS=`extract_int "$2"`

    if [ "$LHS" -lt "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function lesser_equal() {
    local -i LHS=`extract_int "$1"`
    local -i RHS=`extract_int "$2"`

    if [ "$LHS" -le "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function greater_than() {
    local -i LHS=`extract_int "$1"`
    local -i RHS=`extract_int "$2"`

    if [ "$LHS" -lt "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function greater_equal() {
    local -i LHS=`extract_int "$1"`
    local -i RHS=`extract_int "$2"`

    if [ "$LHS" -ge "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function subtract() {
    local LHS=`extract_int "$1"`
    local RHS=`extract_int "$2"`
    echo "#$(( LHS - RHS ))"
}

function multiply() {
    local LHS=`extract_int "$1"`
    local RHS=`extract_int "$2"`
    echo "#$(( LHS * RHS ))"
}

function division() {
    local LHS=`extract_int "$1"`
    local RHS=`extract_int "$2"`
    echo "#$(( LHS / RHS ))"
}


function remainder() {
    local LHS=`extract_int "$1"`
    local RHS=`extract_int "$2"`
    echo "#$(( LHS % RHS ))"
}

function add() {
    local LHS="$1"
    local RHS="$2"

    local tl=`extract_type "$LHS"`
    local tr=`extract_type "$RHS"`

    if [ $tl = INT ]; then
        LHS=`extract_int "$LHS"`
    else
        LHS=`extract_string "$LHS"`
    fi
    if [ $tr = INT ]; then
        RHS=`extract_int "$RHS"`
    else
        RHS=`extract_string "$RHS"`
    fi
    if [ $tl = INT -a $tr = INT ]; then
        echo "#$(( LHS + RHS ))"
    else
        echo "\$\"$LHS$RHS\""
    fi
}

function equal() {
    local LHS="$1"
    local RHS="$2"

    if [ "$LHS" = "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function nequal() {
    local LHS="$1"
    local RHS="$2"

    if [ "$LHS" = "$RHS" ]; then
        echo T
    else
        echo F
    fi
}

function and() {
    local LHS="$1"
    local RHS="$2"

    if [ "$LHS" = T -a "$RHS" = T ]; then
        echo T
    else
        echo F
    fi
}

function or() {
    local LHS="$1"
    local RHS="$2"

    if [ "$LHS" = T -o "$RHS" = T ]; then
        echo T
    else
        echo F
    fi
}

function string_representation() {
    local ARG="$1"
    local type=`extract_type "$ARG"`
    case $type in
        INT) echo "${ARG:1}" ;;
        STR) echo `extract_string "$ARG"` ;;
        CLOSURE) echo "<#closure>" ;;
        TRUE) echo true ;;
        FALSE) echo false ;;
        TUPLE) string_representation_tuple "$ARG" ;;
    esac
}

function print() {
    local result="`string_representation "$1"`"
    echo "$result" >&3
    echo "$1"
}

function bytecode_recog() {
    local bytecode="$1"
    case "$bytecode" in
        L) echo LOAD ;;
        C) echo CALL ;;
        J) echo JUMP_IFNOT ;;
        G) echo JUMP ;;
        X) echo EXEC ;;
        !) echo END ;;
        *) echo ERROR ;;
    esac
}

function region_recog() {
    local region="$1"
    case "$region" in
        '#') echo GLOBAL ;;
        %) echo LOCAL ;;
        *) echo ERROR ;;
    esac
}

function extract_args_quant() {
    local fcalled="$1"
    local -i len=${#fcalled}
    local -i i
    local buff=''
    local c

    for (( i=1; i<len; i++ )) do
        c="${fcalled:$i:1}"
        case "$c" in
            [0-9]) buff+="$c" ;;
            *) break ;;
        esac
    done
    echo "$buff"
}

function name_dump() {
    local -i i
    local -i STACK_POINTER=$1

    for (( i=0; i<STACK_POINTER; i++ )) do
        echo "NAME[$i]:${NAME[$i]}"
    done >&2
}

function get_position_by_name() {
    local desired_name="$1"
    local -i i
    local -i STACK_POINTER=${#STACK[@]}

    for (( i=0; i<STACK_POINTER; i++ )) do
        if [ "${NAME[$i]}" = "$desired_name" ]; then
            echo $i
            return
        fi
    done
    echo -1
    return 1
}

function stack_dump() {
    local -i i
    local -i STACK_POINTER=$1

    for (( i=0; i<STACK_POINTER; i++ )) do
        echo "STACK[$i]:${STACK[$i]}"
    done >&2
}

declare RET=""

function run_global() {
    local -i STACK_BASE=$1
    local -i NPARAMS=$2
    local FCALLED="$3"
    local -a ARGUMENTS
    local -i i
    local -i j

    for (( i=0; i<NPARAMS; i++ )) do
        j=$(( i + STACK_BASE ))
        ARGUMENTS[$i]="${STACK[$j]}"
    done

    RET=`$FCALLED "${ARGUMENTS[@]}"`
}

function run() {
    local -i STACK_BASE=$1
    local -i STACK_POINTER=$2
    local LOCAL_FUNCTION="$3"
    local -i INSTRUCTION_POINTER
    local -i EOP=${#LOCAL_FUNCTION}

    local STATE_BYTECODE=START
    local buff
    local region

    local -i FUTURE_STACK_BASE
    local fcalled
    local -i nparams
    local -i njumps
    local -i i

    for (( INSTRUCTION_POINTER=0 ; INSTRUCTION_POINTER < EOP; INSTRUCTION_POINTER++ )) do
        case $STATE_BYTECODE in
            START)
                buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                STATE_BYTECODE=`bytecode_recog $buff`
                ;;
            LOAD)
                buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                region=`region_recog $buff`
                INSTRUCTION_POINTER+=1

                if [ "$region" = ERROR ]; then
                    STATE_BYTECODE=ERROR
                    continue
                fi
                buff=''
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done

                if [ "$region" = LOCAL ]; then
                    buff=$(( $buff + ${STACK_BASE} ))
                fi

                STACK[${STACK_POINTER}]="${STACK[$buff]}"
                STACK_POINTER+=1
                STATE_BYTECODE=START
                ;;
            CALL)
                buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                region=`region_recog $buff`
                INSTRUCTION_POINTER+=1

                if [ "$region" = ERROR ]; then
                    STATE_BYTECODE=ERROR
                    continue
                fi

                buff=''
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done
                if [ "$region" = LOCAL ]; then
                    buff=$(( $buff + ${STACK_BASE} ))
                fi
                FUTURE_STACK_BASE=${STACK_POINTER}
                fcalled="${STACK[$buff]}"
                if [ "${fcalled::1}" != '&' ]; then
                    STATE_BYTECODE=ERROR
                    continue
                fi
                nparams=`extract_args_quant "$fcalled"`
                FUTURE_STACK_BASE+=-$nparams
                buff="${fcalled#&$nparams}"

                case "${buff::1}" in
                    '#') run_global $FUTURE_STACK_BASE $nparams "${buff:1}" ;;
                    '%') run $(( FUTURE_STACK_BASE - 1 )) $STACK_POINTER "${buff:1}" ;;
                esac
                STACK_POINTER+=-$nparams
                STACK[${STACK_POINTER}]="$RET"
                STACK_POINTER+=1
                STATE_BYTECODE=START
                ;;
            EXEC)
                STACK_POINTER+=-1
                FUTURE_STACK_BASE=${STACK_POINTER}
                fcalled="${STACK[$STACK_POINTER]}"

                if [ "${fcalled::1}" != '&' ]; then
                    STATE_BYTECODE=ERROR
                    continue
                fi
                nparams=`extract_args_quant "$fcalled"`
                FUTURE_STACK_BASE+=-$nparams
                buff="${fcalled#&$nparams}"

                case "${buff::1}" in
                    '#') run_global $FUTURE_STACK_BASE $nparams "${buff:1}" ;;
                    '%') run $(( FUTURE_STACK_BASE - 1 )) $STACK_POINTER "${buff:1}" ;;
                esac
                STACK_POINTER+=-$nparams
                STACK[${STACK_POINTER}]="$RET"
                STACK_POINTER+=1
                STATE_BYTECODE=START
                ;;
            JUMP_IFNOT)
                buff=''
                
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done
                STACK_POINTER+=-1
                if [ "${STACK[${STACK_POINTER}]}" != T ]; then
                    njumps="$buff"
                    
                    for (( i=-1; i < njumps; INSTRUCTION_POINTER++ )) do
                        if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = ';' ]; then
                            i+=1
                        fi
                    done
                    INSTRUCTION_POINTER+=-1
                fi
                STATE_BYTECODE=START
                ;;
            JUMP)
                buff=''
                
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done

                njumps="$buff"

                for (( i=-1; i < njumps; INSTRUCTION_POINTER++ )) do
                    if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = ';' ]; then
                        i+=1
                    fi
                done
                INSTRUCTION_POINTER+=-1

                STATE_BYTECODE=START
                ;;
            END)
                STACK_POINTER+=-1
                RET="${STACK[$STACK_POINTER]}"
                ;;
            ERROR)
                echo "BCB em estado inválido" >&2
                return 1
                ;;
        esac
    done
    STACK_POINTER+=-1
    RET="${STACK[$STACK_POINTER]}"
}

# Opcodes:
#   L<pos>;
#       carrega o item na posição <pos> para o topo da pilha
#   C<pos>;
#       faz a chamada da função na posição <pos> para o topo da pilha
#       consome n elementos da pilha (a depender da função), e depois coloca
#       o retorno da função no topo da pilha
#   J<qnt>;
#       pula os próximos <qnt> opcodes, se o elemento no topo da pilha for falso
#       consome o elemento do topo da pilha
#   G<qnt>;
#       pula incondicionamente os próximos <qnt> opcodes
#   !
#       fim da função
#
# <pos> é indicada:
#   - # , se posição absoluta do começo da pilha
#   - % , se posição relativa a partir da chamada da função
#
# a representação de uma função:
#   &<nargs>#<nome>
#       a função tem <nargs> argumentos (vão ser consumidos da pilha), e vai chamar a
#       função do bash de nome <nome>
#   &<nargs>%<opcodes>!
#       a função tem <nargs> argumentos (vão ser consumidos da pilha), seu código é
#       a lista de <opcodes>, terminada por um !
#
# funções pré-definidas e suas posições de memória
#   - 0 : print, unária, retorna o seu argumento
#   - 1 : first, unária, retorna o primeiro elemento da tupla, não implementado tuplas
#   - 2 : second, unária, retorna o segundo elemento da tupla, não implementado tuplas
#   - 3 : add, binária, retorna a soma de dois inteiros ou uma string com a concatenação
#   - 4 : subtract, binária, retorna a diferença de dois inteiros
#   - 5 : multiply, binária, retorna a multiplicação de dois inteiros
#   - 6 : division, binária, retorna a divisão de dois inteiros
#   - 7 : remainder, binária, retorna o resto da divisão de dois inteiros
#   - 8 : equal, binária, retorna um boolean se os dois elementos são iguais
#   - 9 : nequal, binária, retorna um boolean se os dois elementos não são iguais
#   - 10 : lesser_than, binária, retorna um boolean se o primeiro inteiro for menor que o segundo inteiro
#   - 11 : lesser_equal, binária, retorna um boolean se o primeiro inteiro for menor que ou igual a o segundo inteiro
#   - 12 : greater_than, binária, retorna um boolean se o primeiro inteiro for maior que o segundo inteiro
#   - 13 : greater_equal, binária, retorna um boolean se o primeiro inteiro for maior que ou igual a o segundo inteiro
#   - 14 : and, binária, retorna a operação AND entre dois booleanos
#   - 15 : or, binária, retorna a operação OR entre dois booleanos
#   - 16 : tuple, binária, retorna uma tupla com os dois elementos

function mangled_id() {
    local id="$1"
    [ "${id::1}" = _ ]
}

function bind_values_by_map() {
    local LOCAL_FUNCTION="$1"
    local -i INSTRUCTION_POINTER
    local -i EOP=${#LOCAL_FUNCTION}

    local STATE_BYTECODE
    local buff
    local region

    local -i i

    local assembled=""

    for (( INSTRUCTION_POINTER=0 ; INSTRUCTION_POINTER < EOP; INSTRUCTION_POINTER++ )) do
        buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
        INSTRUCTION_POINTER+=1
        STATE_BYTECODE=`bytecode_recog $buff`
        case $STATE_BYTECODE in
            LOAD)
                local region_mnemonics
                region_mnemonics="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                INSTRUCTION_POINTER+=1
                region=`region_recog $region_mnemonics`

                if [ "$region" = ERROR ]; then
                    return 1
                fi

                buff=''
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done
                if [ "$region" = GLOBAL ]; then
                    buff=`get_position_by_name "$buff"`
                fi

                assembled+="L${region_mnemonics}${buff};"
                ;;
            CALL)
                local region_mnemonics
                region_mnemonics="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                INSTRUCTION_POINTER+=1
                region=`region_recog $region_mnemonics`

                if [ "$region" = ERROR ]; then
                    return 1
                fi

                buff=''
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done
                if [ "$region" = GLOBAL ]; then
                    buff=`get_position_by_name "$buff"`
                fi

                assembled+="C${region_mnemonics}${buff};"
                ;;
            EXEC)
                assembled+="X;"
                ;;
            JUMP_IFNOT)
                buff=''

                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done

                assembled+="J$buff;"
                ;;
            JUMP)
                buff=''

                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                    INSTRUCTION_POINTER+=1
                done

                assembled+="G$buff;"
                ;;
            END)
                ;;
            ERROR)
                echo "BCB em estado inválido" >&2
                return 1
                ;;
        esac
    done
    echo "${assembled}!"
}

function help_command() {
    cat <<EOL
$0 <constant pool manipulation...> PROGRAM

Roda o BCB com as manipulações do constant pool. Por favor, verifique a
descrição dis bytecodes para escrever o programa e funções.

Toda manipulação de constant pool é na forma de uma flag de CLI acompanhada de
uma única string no formato '_<name>:<value>', onde '_<name>' é o _mangled
name_ do objeto e '<value>' é o valor do objeto. Tuplas não são aceitas como
objetos de primeira classe, você vai precisar criar a sua dinamicamente.

    --help              imprime esta ajuda aqui
    --stack-dump        imprime todas as informações que estão na stack
    --name-dump         similar ao --stack-dump, mas imprime o nome dos objetos
                        relacionados as posições correspondentes.
    --add-literal [_name:value]
                        adiciona na constant pool o valor 'value', associando-o
                        ao nome '_name'. Use quando não precisar de
                        pós-processamento para o valor.
    --add-string [_name:value]
                        similar ao --add-literal, mas faz o tratamento da
                        string corretamente. Use para adicionar strings sem
                        precisar se preocupar com as representações internas do
                        BCB.
    --add-int [_name:value]
                        similar ao --add-string, mas faz o tratamento do número
                        corretamente. Use para adicionar números sem precisar
                        se preocupar com as representações internas do BCB.
    --add-function [_name:value]
                        similar ao --add-string, mas para adicionar funções.
                        Precisa colocar todos os bytecodes, porém com um twist:
                        as referências globais usadas são os nomes
                        referenciados no --name-dump. As funções adicionadas
                        dessa maneira passarão por um processamento para
                        resolver todas as questões relativas ao binding de
                        valores globais referenciados.
EOL
}

declare -a add_later_rewrite
PROGRAM=''

while [ $# -gt 0 ]; do
    cli_arg="$1"
    shift
    case "$cli_arg" in
        --stack-dump)
            stack_dump ${#STACK[@]}
            ;;
        --name-dump)
            name_dump ${#STACK[@]}
            ;;
        --add-literal)
            cli_arg="$1"
            shift
            mangled_name="${cli_arg%%:*}"
            literal="${cli_arg#*:}"
            if ! mangled_id "$mangled_name"; then
                echo >&2 "Identificadores passados no literal precisam ser mangled, começados com _"
                echo >&2 "<$mangled_name>"
                exit 1
            fi
            add_constant_literal "$literal" "$mangled_name"
            ;;
        --add-function)
            cli_arg="$1"
            shift
            mangled_name="${cli_arg%%:*}"
            literal="${cli_arg#*:}"
            if ! mangled_id "$mangled_name"; then
                echo >&2 "Identificadores passados no literal precisam ser mangled, começados com _"
                echo >&2 "<$mangled_name>"
                exit 1
            fi
            add_constant_literal "$literal" "$mangled_name"
            add_later_rewrite[${#add_later_rewrite[@]}]=`get_position_by_name "$mangled_name"`
            ;;
        --add-string)
            cli_arg="$1"
            shift
            mangled_name="${cli_arg%%:*}"
            literal="${cli_arg#*:}"
            if ! mangled_id "$mangled_name"; then
                echo >&2 "Identificadores passados no literal precisam ser mangled, começados com _"
                echo >&2 "<$mangled_name>"
                exit 1
            fi
            add_constant_string "$literal" "$mangled_name"
            ;;
        --add-int)
            cli_arg="$1"
            shift
            mangled_name="${cli_arg%%:*}"
            literal="${cli_arg#*:}"
            if ! mangled_id "$mangled_name"; then
                echo >&2 "Identificadores passados no literal precisam ser mangled, começados com _"
                echo >&2 "<$mangled_name>"
                exit 1
            fi
            add_constant_int "$literal" "$mangled_name"
            ;;
        --help)
            help_command
            exit
            ;;
        *)
            if [ "$PROGRAM" = "" ]; then
                PROGRAM="$cli_arg"
            else
                echo "Só pode passar um PROGRAM por vez" >&2
                help_command >&2
                exit 1
            fi
    esac
done

function resolve_all_late_bind() {
    local pos
    local raw
    local bind
    local header

    for pos in "${add_later_rewrite[@]}"; do
        raw="${STACK[$pos]}"

        header="${raw%%\%*}%"
        raw="${raw:${#header}}"

        bind="$header`bind_values_by_map "$raw"`"
        STACK[$pos]="$bind"
    done
}

resolve_all_late_bind

if [ "$PROGRAM" = "" ]; then
    exit
fi

PROGRAM=`bind_values_by_map "$PROGRAM"`

run ${#STACK[@]} ${#STACK[@]} "$PROGRAM" 3>&1