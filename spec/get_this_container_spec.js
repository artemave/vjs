const assert = require('assert').strict
const {parse} = require('@babel/parser')
const {getThisContainer} = require('../lib/queries')

describe('getThisContainer', function() {
  let ast, code

  beforeEach(function() {
    ast = parse(code, {sourceType: 'module'})
  })

  context('class with a method', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        class Aaa {
          stuff(aa) {
            const b = a
            const n = 2

            return b + n
          }
        }

        class Stuff {
          foo() {
            const bbb = this.getBbb()
          }
        }

        const d = 3
      `
    })

    it('returns "classMethod" and class methods', function() {
      assert.deepEqual(getThisContainer({ast, current_line: 6}), {type: 'classMethod', properties: ['stuff']})
      assert.deepEqual(getThisContainer({ast, current_line: 15}), {type: 'classMethod', properties: ['foo']})
    })
  })

  context('object with a method', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const aaa = {
          xxx: '6',
          stuff(aa) {
            const b = a
            const n = 2

            return b + n
          },
          mmm: 2
        }

        const d = 3
      `
    })

    it('returns "objectMethod" and object properties', function() {
      assert.deepEqual(getThisContainer({ast, current_line: 7}), {type: 'objectMethod', properties: ['xxx', 'stuff', 'mmm']})
    })
  })

  context('object with a method and a property whose value is a class', function() {
    before(function() {
      code = `
        import {foo} from 'bar'

        const aaa = {
          xxx: class Yyy {
            getYyy() {
              return 1
            }
          },
          stuff(aa) {
            const b = a
            const n = 2

            return b + n
          },
        }

      const d = 3
      `
    })

    it('returns "objectMethod" and object methods', function() {
      assert.deepEqual(getThisContainer({ast, current_line: 6}), {type: 'classMethod', properties: ['getYyy']})
      assert.deepEqual(getThisContainer({ast, current_line: 11}), {type: 'objectMethod', properties: ['xxx', 'stuff']})
    })
  })
})
