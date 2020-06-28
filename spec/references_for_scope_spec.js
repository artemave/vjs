const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {referencesForScope} = require('../lib/queries')

describe('referencesForScope', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  before(function() {
    code = `
      import fs from 'fs'

      const aaa = 2

      function bbb(ccc) {
        const ddd = ccc
      }

      function eee(fff) {
        const ggg = fff

        function hhh() {
          let ggg = 3
        }
      }

      const kkk = 5`
  })

  it('returns names of references available to current scope', function() {
    assert.deepEqual(
      referencesForScope({ast, current_line: 1}).sort(),
      ['fs', 'aaa', 'bbb', 'eee', 'kkk'].sort()
    )
    assert.deepEqual(
      referencesForScope({ast, current_line: 17}).sort(),
      ['fs', 'aaa', 'bbb', 'eee', 'kkk'].sort()
    )
    assert.deepEqual(
      referencesForScope({ast, current_line: 14}).sort(),
      ['fs', 'aaa', 'bbb', 'eee', 'fff', 'ggg', 'hhh', 'kkk'].sort()
    )
  })
})
