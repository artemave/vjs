#!/usr/bin/env node

// AST explorer:
//  - https://lihautan.com/babel-ast-explorer/#?eyJiYWJlbFNldHRpbmdzIjp7InZlcnNpb24iOiI3LjYuMCJ9LCJ0cmVlU2V0dGluZ3MiOnsiaGlkZUVtcHR5Ijp0cnVlLCJoaWRlTG9jYXRpb24iOnRydWUsImhpZGVUeXBlIjp0cnVlLCJoaWRlQ29tbWVudHMiOnRydWV9LCJjb2RlIjoiICAgICAgY29uc3QgYSA9IDJcblxuICAgICAgZnVuY3Rpb24gc3R1ZmYoYWEpIHtcbiAgICAgICAgY29uc3QgYiA9IGFcbiAgICAgICAgY29uc3QgbiA9IDJcblxuICAgICAgICBsZXQgYyA9IGIgKyBuICsgYWFcbiAgICAgICAgd29yayhjKVxuXG4gICAgICAgIHJldHVybiBjICsgM1xuICAgICAgfVxuXG4gICAgICBjb25zdCBkID0gM+KAqFxuXG4ifQ==
//  - https://astexplorer.net/

const {parse} = require('@babel/parser')
const readline = require('readline')
const jsEditorTags = require('js-editor-tags')
const {
  findStatementStart,
  findVariablesDefinedWithinSelectionButUsedOutside,
  findGlobalFunctionStart,
  findFunctionArguments,
} = require('./queries')
const argv = require('yargs')
  .command('refactoring', 'start refactoring server', {
    'single-run': {
      type: 'boolean'
    }
  })
  .command('tags', 'start generate/update tags file server', {
    update: {
      type: 'boolean'
    },
    ignore: {
      type: 'array',
      default: []
    }
  })
  .demandCommand()
  .argv

function refactoring() {
  const rl = readline.createInterface({
    input: process.stdin
  })

  rl.on('line', message => {
    try {
      const {code, action, start_line, end_line, context = {}} = JSON.parse(message)
      const ast = parse(code, {
        sourceType: 'unambiguous',
        // TODO: pass plugins from argv
        plugins: [
          'jsx',
          'typescript',
          'classProperties',
          ['decorators', { decoratorsBeforeExport: true }]
        ]
      })
      context.action = action

      if (action === 'extract_variable') {
        const loc = findStatementStart({ast, current_line: start_line})
        console.info(JSON.stringify(Object.assign({context}, loc)))
        return

      } else if (action === 'extract_local_function') {
        const loc = findStatementStart({ast, current_line: start_line})
        const return_values = findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line})

        console.info(
          JSON.stringify(
            Object.assign({context, function_arguments: [], return_values}, loc)
          )
        )
        return

      } else if (action === 'extract_function_or_method') {
        const loc = findGlobalFunctionStart({ast, current_line: start_line})
        const return_values = findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line})
        const function_arguments = findFunctionArguments({ast, start_line, end_line})

        console.info(
          JSON.stringify(
            Object.assign({context, return_values, function_arguments}, loc)
          )
        )
        return
      }

      console.error(`unknown action "${action}"`)
    } catch (e) {
      console.error(e)
    }

    if (argv.single_run) {
      rl.close()
    }
  })
}

switch (argv._[0]) {
case 'refactoring':
  refactoring()
  break
case 'tags':
  jsEditorTags({watch: true, ignore: argv.ignore})
  break
default:
  throw new Error(`Unknown command ${argv._[0]}`)
}
