#!/usr/bin/env bash

read -p "exemplo de chamada do BCB: imprimir um nome " &&
./bcb.sh --add-literal "_true:T" --add-string '_nome: jeff que' --stack-dump --name-dump 'L#_nome;C#print;!' || echo

read -p "exemplo de chamada do BCB: apenas o stack dump do ternário... " &&
./bcb.sh --add-function "_ternary:&3%L%1;J2;L%2;G1;L%3;!" --add-int "_um:1" --add-int "_dois:2" --add-int "_dez:10" --add-literal "_true:T" --add-literal "_false:F" --stack-dump || echo

read -p "exemplo de chamada do BCB: print(sumAndQuad(1, 10)) " &&
./bcb.sh --add-function "_sumAndQuad:&2%L%1;L%2;C#add;L%3;C#multiply;!" --add-int "_um:1" --add-int "_dez:10" 'L#_um;L#_dez;C#_sumAndQuad;C#print;!' || echo

read -p "exemplo de chamada do BCB: print(fib(12)) " &&
./bcb.sh --add-function "_fib:&1%L%1;L#_1;C#lesser_equal;J2;L%1;G9;L%1;L#_1;C#subtract;C#_fib;L%1;L#_2;C#subtract;C#_fib;C#add;!" --add-int "_1:1" --add-int "_2:2" --add-int "_entrada:12" 'L#_entrada;C#_fib;C#print;!' || echo

read -p "exemplo de chamada do BCB: 0, 1, 1, 1, _marm, X, X, X, X, print, X " &&
./bcb.sh --add-int "_1:1" --add-int "_0:0" --add-function '_marm:&1%L%1;L#_0;C#equal;J2;L#_1;G1;L#_marm;!' 'L#_0;L#_1;L#_1;L#_1;L#_marm;X;X;X;X;L#print;X;!' || echo
