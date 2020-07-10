const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findMethodScopeLoc} = require('../lib/queries')

describe('findMethodScopeLoc', function() {
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

    it('returns class method start and end', function() {
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 8}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 12}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
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

    it('returns object method start/end', function() {
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 8}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 12}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
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
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 8}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
      assert.deepEqual(findMethodScopeLoc({ast, current_line: 12}), {start: {line: 7, column: 10}, end: {line: 14, column: 11}})
    })
  })
})
