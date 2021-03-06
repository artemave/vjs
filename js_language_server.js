#!/usr/bin/env node

// AST explorer:
//  - https://lihautan.com/babel-ast-explorer/#?eyJiYWJlbFNldHRpbmdzIjp7InZlcnNpb24iOiI3LjYuMCJ9LCJ0cmVlU2V0dGluZ3MiOnsiaGlkZUVtcHR5Ijp0cnVlLCJoaWRlTG9jYXRpb24iOnRydWUsImhpZGVUeXBlIjp0cnVlLCJoaWRlQ29tbWVudHMiOnRydWV9LCJjb2RlIjoiICAgICAgY29uc3QgYSA9IDJcblxuICAgICAgZnVuY3Rpb24gc3R1ZmYoYWEpIHtcbiAgICAgICAgY29uc3QgYiA9IGFcbiAgICAgICAgY29uc3QgbiA9IDJcblxuICAgICAgICBsZXQgYyA9IGIgKyBuICsgYWFcbiAgICAgICAgd29yayhjKVxuXG4gICAgICAgIHJldHVybiBjICsgM1xuICAgICAgfVxuXG4gICAgICBjb25zdCBkID0gM+KAqFxuXG4ifQ==
//  - https://astexplorer.net/

const {parse} = require('@babel/parser')
const readline = require('readline')
const parseOptions = require('./parse_options')
const {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside,
  findGlobalScopeStart,
  findGlobalFunctionArguments,
  determineExtractedFunctionType,
  findMethodScopeLoc,
  findEnclosingDeclaration,
  referencesForScope,
  getThisContainer,
} = require('./lib/queries')
const argv = require('yargs')
  .command('refactoring', 'start refactoring server', {
    'single-run': {
      type: 'boolean'
    }
  })
  .demandCommand()
  .argv

const rl = readline.createInterface({
  input: process.stdin
})

rl.on('line', message => {
  try {
    const {code, action, filetype, start_line, end_line, context = {}} = JSON.parse(message)

    const ast = parse(code, parseOptions(filetype))
    context.action = action

    if (action === 'extract_variable') {

      const loc = findStatementStart({ast, current_line: start_line})
      console.info(JSON.stringify(Object.assign({context}, loc)))

    } else if (action === 'extract_local_function') {

      const loc = findStatementStart({ast, current_line: start_line})
      const return_values = findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line})

      console.info(
        JSON.stringify(
          Object.assign({context, function_arguments: [], return_values, type: 'function'}, loc)
        )
      )
    } else if (action === 'extract_function_or_method') {

      const return_values = findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line})
      const type = determineExtractedFunctionType({ast, start_line, end_line})

      const response = {context, type, return_values}
      response.function_arguments = findGlobalFunctionArguments({ast, start_line, end_line})

      if (type === 'function' || type === 'unboundFunction') {
        Object.assign(response, findGlobalScopeStart({ast, current_line: start_line}))
      } else {
        Object.assign(response, findMethodScopeLoc({ast, current_line: start_line}).start)
      }
      console.info(JSON.stringify(response))

    } else if (action === 'extract_declaration') {

      const response = {context, line: 1}
      const declaration = findEnclosingDeclaration({ast, current_line: start_line})
      if (declaration) {
        response.declaration = declaration
      }
      console.info(JSON.stringify(response))

    } else if (action === 'create_declaration') {

      const response = {context}

      if (context.reference_type === 'method') {
        const {type, properties} = getThisContainer({ast, current_line: start_line})

        if (!properties.includes(context.reference)) {
          context.reference_type = type

          const methodScopeLoc = findMethodScopeLoc({ast, current_line: start_line})
          response.declaration = type === 'objectMethod' ? methodScopeLoc.start : methodScopeLoc.end
          response.declaration.column = methodScopeLoc.start.column
        }
      } else {
        if (!referencesForScope({ast, current_line: start_line}).includes(context.reference)) {
          const loc = ['variable', 'property'].includes(context.reference_type)
            ? findStatementStart({ast, current_line: start_line})
            : findGlobalScopeStart({ast, current_line: start_line})

          response.declaration = loc
        }
      }

      console.info(JSON.stringify(response))

    } else {
      console.error(JSON.stringify({error: `unknown action "${action}"`}))
    }
  } catch (e) {
    console.error(JSON.stringify({error: e.stack}))
  }

  if (argv.single_run) {
    rl.close()
  }
})
