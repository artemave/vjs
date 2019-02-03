#!/usr/bin/env node

const {parse} = require('@babel/parser')
const readline = require('readline')
const argv = require('yargs')
  .boolean('single-run')
  .alias('single-run', 's')
  .describe('single-run', 'Exit after the first line of input is process')
  .argv
const {findStatementStart} = require('./queries')

const rl = readline.createInterface({
  input: process.stdin
})

rl.on('line', message => {
  try {
    const {code, current_line, query, context} = JSON.parse(message)
    const ast = parse(code, {
      sourceType: 'unambiguous',

      plugins: [
        'jsx',
        'typescript',
        'classProperties',
        ['decorators', { decoratorsBeforeExport: true }]
      ]
    })

    if (query === 'findStatementStart') {
      const loc = findStatementStart({ast, current_line})
      console.info(JSON.stringify(Object.assign({context}, loc)))
      return
    }
    console.error(`unknown query "${query}"`)
  } catch (e) {
    console.error(e)
  }

  if (argv.single_run) {
    rl.close()
  }
})
