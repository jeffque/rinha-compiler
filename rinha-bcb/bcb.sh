#!/usr/bin/env bash

declare -a STACK
declare -a NAME

declare REGISTER

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
        '#') REGISTER="INT" ;;
        '$') REGISTER="STR" ;;
        '(') REGISTER=TUPLE ;; 
        T) REGISTER=TRUE ;;
        F) REGISTER=FALSE ;;
        *) REGISTER=CLOSURE ;;
    esac
}

function string_representation_tuple() {
    local TUPLE="$1"
    extract_first_element_tuple "${TUPLE}"
    local LHS="$REGISTER"
    extract_second_element_tuple "${TUPLE}"
    local RHS="$REGISTER"

    echo "(`string_representation "$LHS"`, `string_representation "$RHS"`)"
}

function extract_string() {
    local RET="${1:2}"
    RET="${RET%\"}"
    RET="${RET//\\\\/\\}"
    RET="${RET//\\\"/\"}"
    REGISTER="$RET"
}

function extract_int() {
    REGISTER="${1:1}"
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
                    # if scape, ignore next char
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
                REGISTER="${TUPLE:1:$x}"
            else
                local -i x
                x=$i+1
                local -i end
                end=$TUPLE_LEN-$x-1
                REGISTER="${TUPLE:$x:$end}"
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

# function
function first() {
    extract_first_element_tuple "${STACK[$1]}"
}

# function
function second() {
    extract_second_element_tuple "${STACK[$1]}"
}

# function
function tuple() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"

    REGISTER="($LHS,$RHS)"
}

function compare_those() {
    local -i STACK_BASE="$1"
    extract_int "${STACK[$STACK_BASE]}"
    local -i LHS="$REGISTER"
    extract_int "${STACK[$(( STACK_BASE + 1 ))]}"
    local -i RHS="$REGISTER"
    local COMPARATOR="$2"

    if [ "$LHS" "$COMPARATOR" "$RHS" ]; then
        REGISTER=T
    else
        REGISTER=F
    fi
}

# function
function lesser_than() {
    compare_those "$1" -lt
}

# function
function lesser_equal() {
    compare_those "$1" -le
}

# function
function greater_than() {
    compare_those "$1" -gt
}

# function
function greater_equal() {
    compare_those "$1" -ge
}

# function
function subtract() {
    local -i STACK_BASE="$1"
    extract_int "${STACK[$STACK_BASE]}"
    local -i LHS="$REGISTER"
    extract_int "${STACK[$(( STACK_BASE + 1 ))]}"
    local -i RHS="$REGISTER"
    REGISTER="#$(( LHS - RHS ))"
}

# function
function multiply() {
    local -i STACK_BASE="$1"
    extract_int "${STACK[$STACK_BASE]}"
    local -i LHS="$REGISTER"
    extract_int "${STACK[$(( STACK_BASE + 1 ))]}"
    local -i RHS="$REGISTER"
    REGISTER="#$(( LHS * RHS ))"
}

# function
function division() {
    local -i STACK_BASE="$1"
    extract_int "${STACK[$STACK_BASE]}"
    local -i LHS="$REGISTER"
    extract_int "${STACK[$(( STACK_BASE + 1 ))]}"
    local -i RHS="$REGISTER"
    REGISTER="#$(( LHS / RHS ))"
}

# function
function remainder() {
    local -i STACK_BASE="$1"
    extract_int "${STACK[$STACK_BASE]}"
    local -i LHS="$REGISTER"
    extract_int "${STACK[$(( STACK_BASE + 1 ))]}"
    local -i RHS="$REGISTER"
    REGISTER="#$(( LHS % RHS ))"
}

# function
function add() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"

    extract_type "$LHS"
    local tl="$REGISTER"
    extract_type "$RHS"
    local tr="$REGISTER"

    if [ $tl = INT ]; then
        extract_int "$LHS"
        LHS="$REGISTER"
    else
        extract_string "$LHS"
        LHS="$REGISTER"
    fi
    if [ $tr = INT ]; then
        extract_int "$RHS"
        RHS="$REGISTER"
    else
        extract_string "$RHS"
        RHS="$REGISTER"
    fi
    if [ $tl = INT -a $tr = INT ]; then
        REGISTER="#$(( LHS + RHS ))"
    else
        REGISTER="\$\"$LHS$RHS\""
    fi
}

# function
function equal() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"
    if [ "$LHS" = "$RHS" ]; then
        REGISTER=T
    else
        REGISTER=F
    fi
}

# function
function nequal() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"
    if [ "$LHS" != "$RHS" ]; then
        REGISTER=T
    else
        REGISTER=F
    fi
}

# function
function and() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"

    if [ "$LHS" = T -a "$RHS" = T ]; then
        REGISTER=T
    else
        REGISTER=F
    fi
}

# function
function or() {
    local -i STACK_BASE="$1"
    local LHS="${STACK[$STACK_BASE]}"
    local RHS="${STACK[$(( STACK_BASE + 1 ))]}"

    if [ "$LHS" = T -o "$RHS" = T ]; then
        REGISTER=T
    else
        REGISTER=F
    fi
}

function string_representation() {
    local ARG="$1"

    extract_type "$ARG"
    local type="$REGISTER"
    case $type in
        INT) echo "${ARG:1}" ;;
        STR)
            extract_string "$ARG"
            echo "$REGISTER"
            ;;
        CLOSURE) echo "<#closure>" ;;
        TRUE) echo true ;;
        FALSE) echo false ;;
        TUPLE) string_representation_tuple "$ARG" ;;
    esac
}

# function
function print() {
    local desired="${STACK[$1]}"
    string_representation "$desired"
    REGISTER="$desired"
}

function bytecode_recog() {
    local bytecode="$1"
    case "$bytecode" in
        L) REGISTER=LOAD ;;
        C) REGISTER=CALL ;;
        J) REGISTER=JUMP_IFNOT ;;
        G) REGISTER=JUMP ;;
        X) REGISTER=EXEC ;;
        !) REGISTER=END ;;
        *) REGISTER=ERROR ;;
    esac
}

function region_recog() {
    local region="$1"
    case "$region" in
        '#') REGISTER=GLOBAL ;;
        %) REGISTER=LOCAL ;;
        +) REGISTER=LITERAL ;;
        *) REGISTER=ERROR ;;
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
    REGISTER="$buff"
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
            REGISTER=$i
            return
        fi
    done
    REGISTER=-1
    return 1
}

function stack_dump() {
    local -i i
    local -i STACK_POINTER=${1:-${#STACK[@]}}

    for (( i=0; i<STACK_POINTER; i++ )) do
        echo "STACK[$i]:${STACK[$i]}"
    done >&2
}

declare RET=""

function run_global() {
    local -i STACK_BASE=$1
    local FCALLED="$2"

    $FCALLED $STACK_BASE
    RET="$REGISTER"
}

function run() {
    local -i STACK_BASE=$1
    local -i STACK_POINTER=$2
    local LOCAL_FUNCTION="$3"
    local -i INSTRUCTION_POINTER
    local -i LAST_CONTINUATION_ADDR=-1

    local buff
    local region

    local -i FUTURE_STACK_BASE
    local fcalled
    local -i nparams
    local -i njumps
    local -i i

    for (( INSTRUCTION_POINTER=0 ;; INSTRUCTION_POINTER++ )) do
        bytecode_recog "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
        INSTRUCTION_POINTER+=1
        case $REGISTER in
            LOAD)
                region_recog "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                region="$REGISTER"
                INSTRUCTION_POINTER+=1

                if [ "$region" = ERROR ]; then
                    echo "BCB em estado inválido" >&2
                    return 1
                elif [ "$region" = LITERAL ]; then
                    if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '#' ]; then
                        buff=''
                        while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                            buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            INSTRUCTION_POINTER+=1
                        done
                    elif [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '$' ]; then
                        buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:2}"
                        INSTRUCTION_POINTER+=2
                        while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != '"' ]; do
                            if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '\' ]; then
                                buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                INSTRUCTION_POINTER+=1
                            fi
                            buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            INSTRUCTION_POINTER+=1
                        done
                        buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                        INSTRUCTION_POINTER+=1
                    elif [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '(' ]; then
                        local -i level=1

                        buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                        INSTRUCTION_POINTER+=1
                        while [ "$level" != '0' ]; do
                            local charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            if [ "$charLido" = '(' ]; then
                                level+=1
                            elif [ "$charLido" = ')' ]; then
                                level+=-1
                            elif [ "$charLido" = '"' ]; then
                                buff+="$charLido"
                                INSTRUCTION_POINTER+=1
                                charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                while [ "${charLido}" != '"' ]; do
                                    if [ "${charLido}" = '\' ]; then
                                        buff+="${charLido}"
                                        INSTRUCTION_POINTER+=1
                                        charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                    fi
                                    buff+="${charLido}"
                                    INSTRUCTION_POINTER+=1
                                    charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                done
                            fi
                            buff+="$charLido"
                            INSTRUCTION_POINTER+=1
                        done
                    fi
                    
                    STACK[${STACK_POINTER}]="$buff"
                else
                    local -i start=$INSTRUCTION_POINTER
                    local -i cnt=0
                    while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                        INSTRUCTION_POINTER+=1
                        cnt+=1
                    done
                    buff="${LOCAL_FUNCTION:$start:$cnt}"
                    if [ "$region" = LOCAL ]; then
                        buff=$(( $buff + ${STACK_BASE} ))
                    fi
                    STACK[${STACK_POINTER}]="${STACK[$buff]}"
                fi

                STACK_POINTER+=1
                ;;
            CALL)
                buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                region_recog $buff
                region="$REGISTER"
                INSTRUCTION_POINTER+=1

                if [ "$region" = ERROR ]; then
                    echo "BCB em estado inválido" >&2
                    return 1
                fi
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"
                if [ "$region" = LOCAL ]; then
                    buff=$(( $buff + ${STACK_BASE} ))
                fi
                FUTURE_STACK_BASE=${STACK_POINTER}
                fcalled="${STACK[$buff]}"
                if [ "${fcalled::1}" != '&' ]; then
                    echo "BCB em estado inválido" >&2
                    return 1
                fi
                extract_args_quant "$fcalled"
                nparams="$REGISTER"
                FUTURE_STACK_BASE+=-$nparams
                buff="${fcalled#&$nparams}"

                case "${buff::1}" in
                    '#')
                        run_global $FUTURE_STACK_BASE "${buff:1}"
                        STACK_POINTER+=-$nparams
                        STACK[${STACK_POINTER}]="$RET"
                        STACK_POINTER+=1
                        ;;
                    '%')
                        # marcar continuation precisa ser em %0, shift em todos os elementos...
                        local continuation="$INSTRUCTION_POINTER:$STACK_BASE:$((STACK_POINTER - nparams)):$LAST_CONTINUATION_ADDR:$LOCAL_FUNCTION"

                        local -i i

                        # do shift
                        for (( i=$FUTURE_STACK_BASE+$nparams ; $i >= $FUTURE_STACK_BASE; i+=-1 )) do
                            STACK[$i]="${STACK[$(( i - 1 ))]}"
                        done
                        STACK[${FUTURE_STACK_BASE}]="$continuation"

                        # colocar novos valores da nova função
                        LAST_CONTINUATION_ADDR=$FUTURE_STACK_BASE
                        STACK_BASE=$(( FUTURE_STACK_BASE ))
                        STACK_POINTER+=1
                        LOCAL_FUNCTION="${buff:1}"
                        INSTRUCTION_POINTER=-1
                        ;;
                esac
                ;;
            EXEC)
                STACK_POINTER+=-1
                FUTURE_STACK_BASE=${STACK_POINTER}
                fcalled="${STACK[$STACK_POINTER]}"

                if [ "${fcalled::1}" != '&' ]; then
                    echo "BCB em estado inválido" >&2
                    return 1
                fi
                extract_args_quant "$fcalled"
                nparams="$REGISTER"
                FUTURE_STACK_BASE+=-$nparams
                buff="${fcalled#&$nparams}"

                case "${buff::1}" in
                    '#')
                        run_global $FUTURE_STACK_BASE "${buff:1}"
                        STACK_POINTER+=-$nparams
                        STACK[${STACK_POINTER}]="$RET"
                        STACK_POINTER+=1
                        ;;
                    '%')
                        # marcar continuation precisa ser em %0, shift em todos os elementos...
                        local continuation="$INSTRUCTION_POINTER:$STACK_BASE:$((STACK_POINTER - nparams)):$LAST_CONTINUATION_ADDR:$LOCAL_FUNCTION"

                        local -i i

                        # do shift
                        for (( i=$FUTURE_STACK_BASE+$nparams ; $i >= $FUTURE_STACK_BASE; i+=-1 )) do
                            STACK[$i]="${STACK[$(( i - 1 ))]}"
                        done
                        STACK[${FUTURE_STACK_BASE}]="$continuation"

                        # colocar novos valores da nova função
                        LAST_CONTINUATION_ADDR=$FUTURE_STACK_BASE
                        STACK_BASE=$(( FUTURE_STACK_BASE ))
                        STACK_POINTER+=1
                        LOCAL_FUNCTION="${buff:1}"
                        INSTRUCTION_POINTER=-1
                        ;;
                esac
                ;;
            JUMP_IFNOT)
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"
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
                ;;
            JUMP)
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"
                njumps="$buff"

                for (( i=-1; i < njumps; INSTRUCTION_POINTER++ )) do
                    if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = ';' ]; then
                        i+=1
                    fi
                done
                INSTRUCTION_POINTER+=-1
                ;;
            END)
                STACK_POINTER+=-1
                RET="${STACK[$STACK_POINTER]}"

                if [ "$LAST_CONTINUATION_ADDR" = -1 ]; then
                    return
                fi

                # resgatar última continuation
                local continuation="${STACK[$LAST_CONTINUATION_ADDR]}"

                INSTRUCTION_POINTER="${continuation%%:*}"
                continuation="${continuation#*:}"

                STACK_BASE="${continuation%%:*}"
                continuation="${continuation#*:}"

                STACK_POINTER="${continuation%%:*}"
                continuation="${continuation#*:}"

                LAST_CONTINUATION_ADDR="${continuation%%:*}"
                LOCAL_FUNCTION="${continuation#*:}"

                STACK[${STACK_POINTER}]="$RET"
                STACK_POINTER+=1
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
    local buff
    local region

    local -i i

    local assembled=""

    for (( INSTRUCTION_POINTER=0 ;; INSTRUCTION_POINTER++ )) do
        buff="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
        INSTRUCTION_POINTER+=1
        bytecode_recog $buff
        case $REGISTER in
            LOAD)
                local region_mnemonics
                region_mnemonics="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                INSTRUCTION_POINTER+=1
                region_recog $region_mnemonics
                region="$REGISTER"

                if [ "$region" = ERROR ]; then
                    return 1
                fi

                buff=''
                if [ "$region" = LITERAL ]; then
                    if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '#' ]; then
                        while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                            buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            INSTRUCTION_POINTER+=1
                        done
                    elif [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '$' ]; then
                        buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:2}"
                        INSTRUCTION_POINTER+=2
                        while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != '"' ]; do
                            if [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '\' ]; then
                                buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                INSTRUCTION_POINTER+=1
                            fi
                            buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            INSTRUCTION_POINTER+=1
                        done
                        buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                        INSTRUCTION_POINTER+=1
                    elif [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" = '(' ]; then
                        local -i level=1
                        
                        buff+="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                        INSTRUCTION_POINTER+=1
                        while [ "$level" != '0' ]; do
                            local charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                            if [ "$charLido" = '(' ]; then
                                level+=1
                            elif [ "$charLido" = ')' ]; then
                                level+=-1
                            elif [ "$charLido" = '"' ]; then
                                buff+="$charLido"
                                INSTRUCTION_POINTER+=1
                                charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                while [ "${charLido}" != '"' ]; do
                                    if [ "${charLido}" = '\' ]; then
                                        buff+="${charLido}"
                                        INSTRUCTION_POINTER+=1
                                        charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                    fi
                                    buff+="${charLido}"
                                    INSTRUCTION_POINTER+=1
                                    charLido="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                                done
                            fi
                            buff+="$charLido"
                            INSTRUCTION_POINTER+=1
                        done
                    fi
                else
                    local -i start=${INSTRUCTION_POINTER}
                    local -i cnt=0
                    while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                        INSTRUCTION_POINTER+=1
                        cnt+=1
                    done
                    buff="${LOCAL_FUNCTION:$start:$cnt}"
                    if [ "$region" = GLOBAL ]; then
                        get_position_by_name "$buff"
                        buff=$REGISTER
                    fi
                fi

                assembled+="L${region_mnemonics}${buff};"
                ;;
            CALL)
                local region_mnemonics
                region_mnemonics="${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}"
                INSTRUCTION_POINTER+=1
                region_recog $region_mnemonics
                region="$REGISTER"

                if [ "$region" = ERROR ]; then
                    return 1
                fi

                buff=''
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"
                if [ "$region" = GLOBAL ]; then
                    get_position_by_name "$buff"
                    buff=$REGISTER
                fi

                assembled+="C${region_mnemonics}${buff};"
                ;;
            EXEC)
                assembled+="X;"
                ;;
            JUMP_IFNOT)
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"

                assembled+="J$buff;"
                ;;
            JUMP)
                local -i start=${INSTRUCTION_POINTER}
                local -i cnt=0
                while [ "${LOCAL_FUNCTION:${INSTRUCTION_POINTER}:1}" != ';' ]; do
                    INSTRUCTION_POINTER+=1
                    cnt+=1
                done
                buff="${LOCAL_FUNCTION:$start:$cnt}"

                assembled+="G$buff;"
                ;;
            END)
                break
                ;;
            ERROR)
                echo "BCB em estado inválido" >&2
                return 1
                ;;
        esac
    done
    REGISTER="${assembled}!"
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
            get_position_by_name "$mangled_name"
            add_later_rewrite[${#add_later_rewrite[@]}]=$REGISTER
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

        bind_values_by_map "$raw"
        bind="$header$REGISTER"
        STACK[$pos]="$bind"
    done
}

resolve_all_late_bind

if [ "$PROGRAM" = "" ]; then
    exit
fi

bind_values_by_map "$PROGRAM"
PROGRAM="$REGISTER"

run ${#STACK[@]} ${#STACK[@]} "$PROGRAM"