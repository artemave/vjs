const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findGlobalFunctionStart} = require('./queries')

describe('findGlobalFunctionStart', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  before(function() {
    code = `
      const a = 2

      function stuff(a) {
        const b = a

        function foo() {
          let c = b
          return c + 3
        }
      }

      const d = 3
      `
  })

  it('returns line before outer function start', function() {
    assert.equal(findGlobalFunctionStart({ast, current_line: 6}).line, 4)
    assert.equal(findGlobalFunctionStart({ast, current_line: 8}).line, 4)
    assert.equal(findGlobalFunctionStart({ast, current_line: 13}).line, 13)
  })
})
