const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findMethodScopeStart} = require('./queries')

describe('findMethodScopeStart', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('inside class method', function() {
    before(function() {
      code = `
        import nnn from 'nnn'

        const a = 2

        class Bbb {
          stuff(a) {
            const b = a

            function foo() {
              let c = b
              return c + 3
            }
          }
        }

        const d = 3
      `
    })

    it('returns line before outer function start', function() {
      assert.equal(findMethodScopeStart({ast, current_line: 8}).line, 7)
      assert.equal(findMethodScopeStart({ast, current_line: 12}).line, 7)
    })
  })

  context('inside object method', function() {
    before(function() {
      code = `
        import nnn from 'nnn'

        const a = 2

        const aaa = {
          stuff(a) {
            const b = a

            function foo() {
              let c = b
              return c + 3
            }
          }
        }

        const d = 3
      `
    })

    it('returns line before outer function start', function() {
      assert.equal(findMethodScopeStart({ast, current_line: 8}).line, 7)
      assert.equal(findMethodScopeStart({ast, current_line: 12}).line, 7)
    })
  })

  context('inside object function expression', function() {
    before(function() {
      code = `
        import nnn from 'nnn'

        const a = 2

        const aaa = {
          stuff: function(a) {
            const b = a

            function foo() {
              let c = b
              return c + 3
            }
          }
        }

        const d = 3
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findMethodScopeStart({ast, current_line: 8}), {line: 7, column: 10})
      assert.deepEqual(findMethodScopeStart({ast, current_line: 12}), {line: 7, column: 10})
    })
  })
})
