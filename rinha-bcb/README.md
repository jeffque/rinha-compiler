Aqui temos os bytecodes para executar a rinha-AST.

# Considerações para os bytecodes

Funções são chamadas pela posição delas em memória.

# Consideração para transformar em bytecodes

Primeiro se criam as funções básicas:

- print
- add
- sub
- mul
- div
- rem
- first
- second
- and
- or
- not
- eq
- neq
- lt
- le
- gt
- ge

Essas funções serão consideradas valores e estarão dentro da tabela
global de nomes. Elas não serão _mangled_.

Nodes do tipo `Print` serão efetivamente alteradas para `call #print`,
onde `#print` é a posição da função `print` declarada previamente.

Nodes do tipo `Binary` serão convertida em `call $op` onde `$op` é
referente ao `BinaryOp`.

Todos os nomes de variáveis na tabela de variáveis terão _mangling_.
Todo nome dentro da AST terá um `_` automaticamente colocado para
evitar misturar com nomes ds funções previamente listadas.

Uma função é definida como:

- externa, em que será realizado um chamado a uma linha CLI passando
  apenas 3 tipos e variáveis (serializadas):
  - inteiro, no formato `#<dec>`, como `#12` representando o número 12
  - string, no formato `$"<string>"`, onde `"` e `\` podem ser escapados com `\`
  - booleano, como `T` ou `F`
  - tupla, como `(TERM,TERM)`, onde `TERM` é a serialização do termo
  - clausura, como `?`, sem maior significância
- interna, um conjunto de byte codes.

O retorno de uma função externa é na forma de uma variável serializada.

Para funções internas, será armazenado como `&<nargs>%<bytecodes>!`. Para funções
externas, como `&<nargs>#nome` onde `nome` é o nome do comando shell (possivelmente
uma função) para realizar o trabalho, e `nargs` é um decimal com a quantidade de
argumentos. Os argumentos serão resgatados da stack, onde o topo da stack é o primeiro
parâmetro, o segundo elemento da stack o segundo parâmetro e assim por diante.

Cada bytecode dentro da função é separado por `;`, o fim da função é `!`.
Por exemplo, a função `&1%L%1;C#0;!` é uma função de um argumento. Esse argumento
é colocado na pilha e então a função na posição `0` global da stack é chamada
com esse argumento. O último elemento da pilha é sempre retornado.

A constant pool será inserida após a inserção das funções na stack.

A referência `#` é absoluta na STACK. A referência `%` é relativa a última
chamada da função, com os argumentos recebendo números positivos. Após a chamada
da função, os `nargs` são desempilhados.

# Lista de bytecodes

- `L` LOAD, copia uma variável da stack para o top da pilha
- `C` CALL, chama uma função com base na posição da stack
- `J` JUMP_IFNOT, salto condicional, consome o topo da pilha, indica
  quantas instruções vai pular; o salto será realizado se o
  topo da pilha estiver falso
- `G` JUMP/GOTO, salto incondicional, indica quantas instruções
  vai pular

Todo bytecode vem terminado por `;`. Toda sequência de bytecodes é terminada
por um `!`.

Não existem literais. Todo valor deve ser resgatado do constant pool,
que está na stack. `L` e `C` são acompanhados de uma "posição", que
se refere a uma posição do constant pool (`#0` resgata a função `print`)
ou a partir do começo da chamada da função (`%1` se refere ao primeiro
argumento da função).

Não há operadores. Só existem funções. As seguintes funções estão
previamente definidas:

| memória | nome          | nargs          | resultado                       |
|---------|---------------|----------------|---------------------------------|
| 0       | print         | 1              | #0                              |
| 1       | first         | 1              | LHS da tupla                    |
| 2       | second        | 1              | RHS da tupla                    |
| 3       | add           | 2              | soma se int, concat otherwise   |
| 4       | subtract      | 2              | diferença                       |
| 5       | multiply      | 2              | *                               |
| 6       | division      | 2              | /                               |
| 7       | remainder     | 2              | %                               |
| 8       | equal         | 2              | ==                              |
| 9       | nequal        | 2              | !=                              |
| 10      | lesser_than   | 2              | <                               |
| 11      | lesser_equal  | 2              | <=                              |
| 12      | greater_than  | 2              | >                               |
| 13      | greater_equal | 2              | >=                              |
| 14      | and           | 2              | E lógico                        |
| 15      | or            | 2              | OU lógico                       |
| 16      | tuple         | 2              | cria uma tupla                  |


Em memória, todos os tipos são tratados como variáveis e serializados.
Eles ficam na memória da seguinte forma:

- inteiro: `#42` é o inteiro `42`
- string: `$"marmota"` é a string `marmota`
- true: `T`
- false: `F`
- funções: vem em dois sabores, internas e externas; explicada em seção própria
- tupla: `(#42,($"quarenta",$"dois"))`, sempre na forma `(TERM,TERM)`,
  onde cada `TERM` é a representação da variável que constrói a tupla; no
  exemplo, o primeiro elemento é o inteiro `42`, e o segundo elemento é
  uma tupla com as strings `quarenta` e `dois`

## Representação de funções

Uma função sempre começa com `&<nargs>`, onde `nargs` é um inteiro com
a quantidade de argumentos que ela possui. Por exemplo, a função identidade
é `&1%L%1;!`. Toda função retorna, e o retorno da função de funções internas
vai ser o que estiver no topo da pilha.

Uma função interna é representada por um `%` após a quantidade de argumentos.
Após isso, vem uma sequência de bytecodes. No caso da função identidade,
temos `L%1;`, que carrega o primeiro argumento em memória. Como se chega ao
final da execução `!`, o elemento do topo da memória será retornado.

Outro exemplo de função interna: o ternário. A função recebe um booleano
e, se ele for verdade, retorna o segundo argumento valor, caso contrário retorna
o terceiro argumento:

```
&3%L%1;J2;L%2;G1;L%3;!
```