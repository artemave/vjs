const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {findStatementStart} = require('../lib/queries')

describe('findStatementStart', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })
  context('current line is a top level variable declaration', function() {
    before(function() {
      code = `
      const a = 2
      b = 3
      c(4)
      `
    })
    it('returns current line', function() {
      assert.equal(findStatementStart({ast, current_line: 1}).line, 1)
      assert.equal(findStatementStart({ast, current_line: 2}).line, 2)
      assert.equal(findStatementStart({ast, current_line: 3}).line, 3)
    })
  })

  context('current line is inside function declaration', function() {
    before(function() {
      code = `const a = 2
      function balls() {
        const b = 3
      }`
    })
    it('returns current line', function() {
      assert.equal(findStatementStart({ast, current_line: 3}).line, 3)
    })
  })

  context('current line is inside object literal', function() {
    before(function() {
      code = `let a = 2
      a = {
        c: {
          d: 5
        }
      }`
    })
    it('returns the line where the object literal starts', function() {
      assert.equal(findStatementStart({ast, current_line: 3}).line, 2)
    })
  })

  context('current line is inside array literal', function() {
    before(function() {
      code = `let a = 2
      a = [
        2,
        {d: 5}
      ]`
    })
    it('returns the line where the array literal starts', function() {
      assert.equal(findStatementStart({ast, current_line: 4}).line, 2)
    })
  })

  context('current line is inside a function that is inside an array literal', function() {
    before(function() {
      code = `let a = 2
      a = [
        2,
        () => {
          fn({
            b: 3
          })
        }
      ]`
    })
    it('returns the line within the inner function', function() {
      assert.equal(findStatementStart({ast, current_line: 4}).line, 2)
      assert.equal(findStatementStart({ast, current_line: 6}).line, 5)
    })
  })

  context('current line is inside a function that is inside an object literal', function() {
    before(function() {
      code = `let a = 2
      a = {
        b: 2,
        c: () => {
          fn({
            b: 3
          })
        }
      }`
    })
    it('returns the line within the inner function', function() {
      assert.equal(findStatementStart({ast, current_line: 4}).line, 2)
      assert.equal(findStatementStart({ast, current_line: 6}).line, 5)
    })
  })
})
