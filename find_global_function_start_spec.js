const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findGlobalScopeStart} = require('./queries')

describe('findGlobalScopeStart', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('inside a method', function() {
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
      assert.equal(findGlobalScopeStart({ast, current_line: 8}).line, 6)
      assert.equal(findGlobalScopeStart({ast, current_line: 12}).line, 6)
    })
  })

  context('inside an object property', function() {
    before(function() {
      code = `
        import nnn from 'nnn'

        const a = 2

        module.exports = {
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
      assert.equal(findGlobalScopeStart({ast, current_line: 8}).line, 6)
      assert.equal(findGlobalScopeStart({ast, current_line: 12}).line, 6)
    })
  })

  context('inside an inner function', function() {
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
      assert.equal(findGlobalScopeStart({ast, current_line: 6}).line, 4)
      assert.equal(findGlobalScopeStart({ast, current_line: 8}).line, 4)
      assert.equal(findGlobalScopeStart({ast, current_line: 13}).line, 13)
    })
  })
})
