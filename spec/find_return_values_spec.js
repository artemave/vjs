const assert = require('assert')
const {parse} = require('@babel/parser')
const {findVariablesDefinedWithinSelectionButUsedOutside} = require('../lib/queries')
const parseOptions = require('../parse_options')

describe('findVariablesDefinedWithinSelectionButUsedOutside', function() {
  let code, ast

  beforeEach(function() {
    ast = parse(code, parseOptions())
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
      var mm = b
      let boo = 'stuff'
      d = mm
      dd = boo
      `
    })

    context('but it is not used outside after the end line', function() {
      it('returns []', function() {
        assert.deepEqual(
          findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 3, end_line: 9}),
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
        assert.deepEqual(
          findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 3, end_line: 6}),
          [{kind: 'var', name: 'mm'}]
        )
        assert.deepEqual(
          findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 3, end_line: 7}),
          [{kind: 'var', name: 'mm'}, {kind: 'let', name: 'boo'}]
        )
      })
    })
  })

  context('works with var', function() {
    before(function() {
      code = `
      function notSillyBlankIEObject (element) {
        return Object.keys(element).length > 0
      }
      module.exports = {
        focus: function (element, options) {
          var focus = typeof options === 'object' && options.hasOwnProperty('focus') ? options.focus : true

          if (focus) {
            var $ = this.get('$')
            var document = this.get('document')
            if (element && element.length > 0) {
              element = element[0]
            }

            var activeElement = document.activeElement
            if (activeElement && !$(activeElement).is(':focus') && notSillyBlankIEObject(activeElement)) {
              $(activeElement).trigger('blur')
            }
            if (['[object Document]', '[object HTMLDocument]'].indexOf(document.toString()) === -1) {
              element = activeElement
            }
            $(element).focus()
          }
        },
      }
      `
    })

    it('returns var', function() {
      assert.deepEqual(
        findVariablesDefinedWithinSelectionButUsedOutside({ast, start_line: 16, end_line: 19}),
        [{kind: 'var', name: 'activeElement'}]
      )
    })
  })
})
