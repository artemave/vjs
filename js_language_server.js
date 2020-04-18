#!/usr/bin/env node

const {parse} = require('@babel/parser')
const readline = require('readline')
const jsEditorTags = require('js-editor-tags')
const {findStatementStart, findVariablesDefinedWithinSelectionButUsedOutside} = require('./queries')
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
      } else if (action === 'extract_function') {
        const loc = findStatementStart({ast, current_line: start_line})
        const [return_value] = findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line, end_line})
        console.info(
          JSON.stringify(
            Object.assign({context}, loc, {return_value})
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
