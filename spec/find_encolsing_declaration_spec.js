const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findEnclosingDeclaration} = require('../lib/queries')

describe('findEnclosingDeclaration', function() {
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

        things.each(function() {
          return 1
        })

        function stuffBar() {
          return 1
        }

        const ggg = {
          a: 2,
          b: 3
        }
      `
    })

    it('returns line before outer function start', function() {
      assert.deepEqual(findEnclosingDeclaration({ast, current_line: 9}), {
        name: 'Bbb',
        start_line: 6,
        end_line: 15,
      })
      // assert.deepEqual(findEnclosingDeclaration({ast, current_line: 10}), {
      //   name: 'foo',
      //   start_line: 10,
      //   end_line: 13,
      // })
      // assert.equal(findEnclosingDeclaration({ast, current_line: 17}), undefined)
      // assert.deepEqual(findEnclosingDeclaration({ast, current_line: 22}), {
      //   name: 'stuffBar',
      //   start_line: 21,
      //   end_line: 23,
      // })
      // assert.deepEqual(findEnclosingDeclaration({ast, current_line: 26}), {
      //   name: 'ggg',
      //   start_line: 25,
      //   end_line: 28,
      // })
    })
  })
})
