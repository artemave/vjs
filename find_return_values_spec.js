const assert = require('assert')
const {parse} = require('@babel/parser')
const {findVariablesDefinedWithinSelectionButUsedOutside} = require('./queries')

describe('findVariablesDefinedWithinSelectionButUsedOutside', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('nothing is defined between start and end lines', function() {
    before(function() {
      code = `
      foo(2)
      lines.each(() => {
        console.log('yep')
      })
      b.a = 'stuff'
      d = 3
      `
    })

    it('returns []', function() {
      assert.deepEqual(
        findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 2, end_line: 5}),
        []
      )
    })
  })

  context('a variable is defined between start and end lines', function() {
    before(function() {
      code = `
      foo(2)
      const b = {}
      b.a = 'stuff'
      bar(b)
      let boo = 'stuff'
      d = 3
      `
    })

    context('but it is not used outside after the end line', function() {
      it('returns []', function() {
        assert.deepEqual(
          findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 3, end_line: 5}),
          []
        )
      })
    })

    context('and it is used after the end line', function() {
      it('returns the name and the kind of that variable', function() {
        assert.deepEqual(
          findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 3, end_line: 4}),
          [{kind: 'const', name: 'b'}]
        )
      })
    })
  })
})
