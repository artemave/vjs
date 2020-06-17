const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findReferencedImports} = require('../lib/queries')

describe('findReferencedImports', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('inside class method', function() {
    before(function() {
      code = `
        import nnn from 'nnn'
        const ppp = require('./ppp')
        import ooo from 'ooo'

        nnn()

        function mmm() {
          ppp()
          return nnn()
        }

        nnn()
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findReferencedImports({ast, start_line: 8, end_line: 11}), [
        {line: 2, referenced_on_lines: [9]},
        {line: 1, referenced_on_lines: [6, 10, 13]},
      ])
    })
  })
})
