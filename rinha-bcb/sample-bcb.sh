#!/usr/bin/env bash

function msg_and_bcb() {
    local msg="exemplo de chamada do BCB: $1"
    shift
    read -p "$msg " && ./bcb.sh "$@" || { echo; echo; }
}

function _msg_and_bcb() {
    echo "skipping <$1>..."
}

_msg_and_bcb "imprimir um nome" \
    --add-literal "_true:T" --add-string '_nome: jeff que' --stack-dump --name-dump 'L#_nome;C#print;!'

_msg_and_bcb "apenas o stack dump do ternário..." \
    --add-function "_ternary:&3%L%1;J2;L%2;G1;L%3;!" --add-int "_um:1" --add-int "_dois:2" --add-int "_dez:10" --add-literal "_true:T" --add-literal "_false:F" --stack-dump

_msg_and_bcb "print(sumAndQuad(1, 10)) " \
    --add-function "_sumAndQuad:&2%L%1;L%2;C#add;L%3;C#multiply;!" --add-int "_um:1" --add-int "_dez:10" 'L#_um;L#_dez;C#_sumAndQuad;C#print;!'

msg_and_bcb "print(fib(12)) " \
    --add-function "_fib:&1%L%1;L#_1;C#lesser_equal;J2;L%1;G9;L%1;L#_1;C#subtract;C#_fib;L%1;L#_2;C#subtract;C#_fib;C#add;!" --add-int "_1:1" --add-int "_2:2" --add-int "_entrada:12" 'L#_entrada;C#_fib;C#print;!'

_msg_and_bcb "0, 1, 1, 1, _marm, X, X, X, X, print, X " \
    --add-int "_1:1" --add-int "_0:0" --add-function '_marm:&1%L%1;L#_0;C#equal;J2;L#_1;G1;L#_marm;!' 'L#_0;L#_1;L#_1;L#_1;L#_marm;X;X;X;X;L#print;X;!'

_msg_and_bcb "print de first de ((\$\"eu sou o Jeff, prazer\",#42),\$\"marmota\") " \
    --add-int "_42:42" --add-string "_marmota:marmota" --add-string "_oi:eu sou o Jeff, prazer" 'L#_oi;L#_42;C#tuple;L#_marmota;C#tuple;C#first;C#print;!'

_msg_and_bcb "print de second de first de ((\$\"eu sou o Jeff, prazer\",#42),\$\"marmota\") " \
    --add-int "_42:42" --add-string "_marmota:marmota" --add-string "_oi:eu sou o Jeff, prazer" 'L#_oi;L#_42;C#tuple;L#_marmota;C#tuple;C#first;C#second;C#print;!'

_msg_and_bcb "print de second de ((\$\"eu sou o Jeff, prazer\",#42),\$\"marmota\") " \
    --add-int "_42:42" --add-string "_marmota:marmota" --add-string "_oi:eu sou o Jeff, prazer" 'L#_oi;L#_42;C#tuple;L#_marmota;C#tuple;C#second;C#print;!'

_msg_and_bcb "print(print(1) + print(2))" \
    --add-int "_1:1" --add-int "_2:2" 'L#_1;C#print;L#_2;C#print;C#add;C#print;!'

msg_and_bcb "função de redução" \
    --add-function "_reduce:&3%L%1;C#first;C#first;J10;L%1;C#first;C#second;L%1;C#second;L%2;L%3;C#_reduce;C%2;G1;L%3;!" \
    --add-literal "_true:T" --add-literal "_false:F" \
    --add-int "_0:0" --add-int "_1:1" --add-int "_2:2" --add-int "_3:3" --add-int "_4:4" \
    'L#_true;L#_1;C#tuple;L#_true;L#_2;C#tuple;L#_true;L#_3;C#tuple;L#_true;L#_4;C#tuple;L#_false;L#_0;C#tuple;C#tuple;C#tuple;C#tuple;C#tuple;L#add;L#_0;C#_reduce;C#print;!'

msg_and_bcb "print(load literal inteiro 3)" \
    'L+#3;C#print;!'

msg_and_bcb "print(load literal string 3)" \
    'L+$"3";C#print;!'

msg_and_bcb "print(load literal string 3 + load literal int 1)" \
    'L+$"3";L+#1;C#add;C#print;!'

msg_and_bcb "print(load literal int 3 + load literal int 1)" \
    'L+#3;L+#1;C#add;C#print;!'

msg_and_bcb "print(load literal string 3;)" \
    'L+$"3;";C#print;!'

msg_and_bcb "print(soma(literal (1, 2)))" \
    --add-function '_soma:&1%L%1;C#first;L%1;C#second;C#add;!' --stack-dump \
    'L+(#1,#2);C#_soma;C#print;!'

msg_and_bcb 'print(soma(literal ("1", 2)))' \
    --add-function '_soma:&1%L%1;C#first;L%1;C#second;C#add;!' --stack-dump \
    'L+($"1",#2);C#_soma;C#print;!'

msg_and_bcb 'print(soma(literal ("1\",;)", 2)))' \
    --add-function '_soma:&1%L%1;C#first;L%1;C#second;C#add;!' --stack-dump \
    'L+($"1\",;\\)",#2);C#_soma;C#print;!'