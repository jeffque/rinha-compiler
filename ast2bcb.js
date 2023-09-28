const fs = require('fs');

const astSource = process.env.AST_SOURCE ?? 'rinha.ast'
const ast = JSON.parse(fs.readFileSync(astSource, 'utf8'))
const constantPool = []; // tipo, valor, apelido

const createContext = (context) => {
    return {
        type: 'Blob',
        table: [],
        context: context,
        bytecodes: [],
        toString: function() {
            return this.bytecodes.reduce((p, n) => p+n, "")
        },
        pushBytecode(bc) {
            this.bytecodes.push(bc)
        },
        addMapping(name, bytecodes) {
            this.table.push({name, bytecodes})
        }
    }
}

const yieldAnonFunctionName = (() => {
    let n = 0
    return () => {
        n++
        return "_+anon+" + n
    }
})()

const createFunction = (nParams, params) => {
    f = {
        type: 'Func',
        nParams: nParams,
        nCaptures: 0,
        argsName: params.argsName ?? [],
        table: [],
        unmangledName: params.name ?? yieldAnonFunctionName(),
        context: params.context,
        bytecodes: [],
        toString: function() {
            const strbc = this.bytecodes.reduce((p, n) => p+n, "")
            return `&${this.nParams}%${strbc}!`
        },
        mangledName() {
            return this.unmangledName ? `_${this.unmangledName}`: undefined
        },
        pushBytecode(bc) {
            this.bytecodes.push(bc)
        },
        addMapping(name, bytecodes) {
            this.table.push({name, bytecodes})
        }
    }

    if (params.argsName) {
        let i = 1
        for (p of params.argsName) {
            f.addMapping(p, [`L%${i};`])
            i++
        }
    }

    return f
}

const createLet = (name, params) => {
    return {
        type: 'Let',
        name: name,
        bytecodes: [],
        table: [],
        toString: function() {
            return this.bytecodes.reduce((p, n) => p+n, "")
        },
        pushBytecode(bc) {
            this.bytecodes.push(bc)
        },
        addMapping(name, bytecodes) {
            this.table.push({name, bytecodes})
        },
        context: params.context
    }
}


const program = ast.expression;

let deuBom = true;

const toBcbFunction = (op) => ({
    'Add': 'add',
    'Sub': 'subtract',
    'Mul': 'multiply',
    'Div': 'division',
    'Rem': 'remainder',
    'Eq': 'equal',
    'Neq': 'nequal',
    'Lt': 'lesser_than',
    'Gt': 'greater_than',
    'Lte': 'lesser_equal',
    'Gte': 'greater_equal',
    'And': 'and',
    'Or': 'or'
})[op]

const addMain = (main) => {
    constantPool.push({tipo: 'Func', valor: `${main}`, apelido: main.mangledName()})
}

const addConstToPool = (value, t) => {
    // tratativa especial de função
    if (t == 'Func') {
        for (let {tipo, valor, apelido} of constantPool) {
            if (tipo == 'Func' && valor.unmangledName == value.unmangledName) {
                return apelido;
            }
        }
    } else if (t == 'Bool') {
        for (let {tipo, valor, apelido} of constantPool) {
            if (tipo == t && valor == value) {
                return apelido;
            }
        }
        let apelido
        if (value == "T") {
            apelido = "_T"
        } else {
            apelido = "_F"
        }
        constantPool.push({tipo: t, valor: value, apelido: apelido})
        return apelido
    } else {
        for (let {tipo, valor, apelido} of constantPool) {
            if (tipo == t && valor == value) {
                return apelido;
            }
        }
    }
    
    
    const apelido = `_${constantPool.length}`
    constantPool.push({tipo: t, valor: value, apelido: apelido})

    return apelido
}

const letDeclaration = (expr, functionContext) => {
    const name = expr.name.text
    const lelet = createLet(name, {context: functionContext})
    readExpression(expr.value, lelet)

    functionContext.addMapping(name, lelet.bytecodes)
    readExpression(expr.next, functionContext)
}

const placeholderDeclaration = (expr, functionContext) => {
    console.log(`tá no placeholder ${expr.kind}`)
    deuBom = false;
}

const printDeclaration = (expr, functionContext) => {
    readExpression(expr.value, functionContext)
    functionContext.pushBytecode("C#print;")
}

const strDeclaration = (expr, functionContext) => {
    const value = expr.value;

    const apelido = addConstToPool(value, 'Str');
    const bc = `L#${apelido};`
    functionContext.pushBytecode(bc)
    return [bc]
}

const getFunctionNameIfGlobal = (functionContext) => {
    if (functionContext.type == 'Let') {
        const candidateName = functionContext.name
        while (functionContext.type != 'Func') {
            functionContext = functionContext.context
        }
        if (functionContext.unmangledName == 'main') {
            return candidateName
        }
    }
}

const functionDeclaration = (expr, functionContext) => {
    const nParams = expr.parameters.length
    const argsName = expr.parameters.map(t => t.text)
    const name = getFunctionNameIfGlobal(functionContext)
    const newFunc = createFunction(nParams, {argsName: argsName, context: functionContext, name: name})
    const alias = addConstToPool(newFunc, 'Func') // para obter chamadas recursivas

    readExpression(expr.value, newFunc)
    functionContext.pushBytecode(`L#${alias};`)
}

const boolDeclaration = (expr, functionContext) => {
    const value = expr.value + "";
    let bc;
    if (value == 'true') {
        const alias = addConstToPool("T", 'Bool')
        bc = "L#_T;"
    } else {
        const alias = addConstToPool("F", 'Bool')
        bc = "L#_F;"
    }
    
    functionContext.pushBytecode(bc)
}

const intDeclaration = (expr, functionContext) => {
    const value = expr.value;
    const apelido = addConstToPool(value, 'Int');

    const bc = `L#${apelido};`
    functionContext.pushBytecode(bc)
}

const binaryDeclaration = (expr, functionContext) => {
    const lhsContext = createContext(functionContext)
    readExpression(expr.lhs, lhsContext)
    const rhsContext = createContext(functionContext)
    readExpression(expr.rhs, rhsContext)

    const op = toBcbFunction(expr.op);

    for (let bc of lhsContext.bytecodes) {
        functionContext.pushBytecode(bc)
    }
    for (let bc of rhsContext.bytecodes) {
        functionContext.pushBytecode(bc)
    }
    const callByteCode = `C#${op};`
    functionContext.pushBytecode(callByteCode)
}

const ifDeclaration = (expr, functionContext) => {
    const condBytecode = createContext(functionContext)
    readExpression(expr.condition, condBytecode)
    
    const thenBytecode = createContext(functionContext)
    readExpression(expr.then, thenBytecode)

    const elseBytecode = createContext(functionContext)
    readExpression(expr.otherwise, elseBytecode)

    for (let bc of condBytecode.bytecodes) {
        functionContext.pushBytecode(bc)
    }
    
    functionContext.pushBytecode(`J${thenBytecode.bytecodes.length + 1};`)
    for (let bc of thenBytecode.bytecodes) {
        functionContext.pushBytecode(bc)
    }

    functionContext.pushBytecode(`G${elseBytecode.bytecodes.length};`)
    for (let bc of elseBytecode.bytecodes) {
        functionContext.pushBytecode(bc)
    }
}

const callDeclaration = (expr, functionContext) => {
    const terms = []
    for (let term of expr.arguments) {
        const subcontext = createContext(functionContext)
        readExpression(term, subcontext)
        terms.push(...subcontext.bytecodes)
    }
    const callee = createContext(functionContext)
    readExpression(expr.callee, callee)
    // functionContext.pushBytecode("X;");
    for (let bc of [...terms, ...callee.bytecodes, 'X;']) {
        functionContext.pushBytecode(bc);
        // pushBytecode
    }
}

const tupleDeclaration = (expr, functionContext) => {
    const firstContext = createContext(functionContext)
    readExpression(expr.first, firstContext)
    
    const secondContext = createContext(functionContext)
    readExpression(expr.second, secondContext)
    for (let bc of [...firstContext.bytecodes, ...secondContext.bytecodes]) {
        functionContext.pushBytecode(bc);
    }
    functionContext.pushBytecode("C#tuple;")
}

const firstDeclaration = (expr, functionContext) => {
    readExpression(expr.value, functionContext)
    functionContext.pushBytecode("C#first;")
}

const secondDeclaration = (expr, functionContext) => {
    readExpression(expr.value, functionContext)
    functionContext.pushBytecode("C#second;")
}

/*
L#_1;L%1;L#_1;C#subtract;L#_1;L%2;L#_1;C#subtract;X;L#_1;L%1;L#_1;C#subtract;X;C#add;!'
combination(n - 1, k - 1) + combination(n - 1, k)
*/

const varDeclaration = (expr, functionContext) => {
    const bytecodes = (() => {
        const varName = expr.text
        let which = functionContext
        while (true) {
            for (let {name, bytecodes} of which.table) {
                if (name == varName) {
                    return bytecodes
                }
            }
            if (which.type == 'Let') {
                if (which.name == varName) {
                    return which.bytecodes
                }
            }
            if (which.type == 'Func' && which.unmangledName && which.unmangledName != 'main') {
                if (which.unmangledName == varName) {
                    const apelido = (() => {
                        for (let {tipo, valor, apelido} of constantPool) {
                            if (tipo == 'Func' && valor.unmangledName == varName) {
                                return apelido;
                            }
                        }
                    })()
                    return [`L#${apelido};`]
                }
            }
            which = which.context
        }
        return []
    })()
    for (let bc of bytecodes) {
        functionContext.pushBytecode(bc)
    }
}

const readExpression =  (expr, functionContext) => {
    const kind2action = {
        'Let' : letDeclaration,
        'Print': printDeclaration,
        'Binary': binaryDeclaration,

        'If': ifDeclaration,
        'Var': varDeclaration,
        'Call': callDeclaration,

        "Tuple": tupleDeclaration,
        "First": firstDeclaration,
        "Second": secondDeclaration,

        // tipos
        'Function': functionDeclaration,
        'Str': strDeclaration,
        'Int': intDeclaration,
        'Bool': boolDeclaration,
    };
    const shouldCall = kind2action[expr.kind] ?? placeholderDeclaration;
    return shouldCall(expr, functionContext)
}


const bcb = createFunction(0, { name: 'main'})

readExpression(program, bcb);

addMain(bcb)

const toBcbCli = (c) => {
    if (c.tipo == 'Str') {
        return ["--add-string", `${c.apelido}:${c.valor}`]
    }
    if (c.tipo == 'Func') {
        return ["--add-function", `${c.apelido}:${c.valor}`]
    }
    if (c.tipo == 'Int') {
        return ["--add-int", `${c.apelido}:${c.valor}`]
    }
    if (c.tipo == 'Bool') {
        return ["--add-literal", `${c.apelido}:${c.valor}`]
    }
}

const args = []
for (let c of constantPool) {
    args.push(...toBcbCli(c))
}
args.push(`C#${bcb.mangledName()};!`)

if (!deuBom) {
    return
}
const { spawn } = require('node:child_process');
const ls = spawn('rinha-bcb/bcb.sh', args);

ls.stdout.on('data', (data) => {
    console.log(`${data}`)
});

ls.stderr.on('data', (data) => {
    console.error(`${data}`)
});
