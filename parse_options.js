module.exports = function(filetype) {
  const plugins = [
    'jsx',
    'classProperties',
    'asyncGenerators',
    'bigInt',
    'classPrivateProperties',
    'classPrivateMethods',
    'doExpressions',
    'dynamicImport',
    'exportDefaultFrom',
    'exportNamespaceFrom',
    'functionBind',
    'functionSent',
    'importMeta',
    'logicalAssignment',
    'nullishCoalescingOperator',
    'numericSeparator',
    'objectRestSpread',
    'optionalCatchBinding',
    'optionalChaining',
    'partialApplication',
    'throwExpressions',
    'topLevelAwait',
    ['decorators', { decoratorsBeforeExport: true }]
  ]

  if (filetype === 'typescript') {
    plugins.push('typescript')
  } else {
    plugins.push('flow', 'flowComments')
  }

  return {
    allowImportExportEverywhere: true,
    allowAwaitOutsideFunction: true,
    errorRecovery: true,
    allowSuperOutsideMethod: true,
    allowUndeclaredExports: true,
    sourceType: 'unambiguous',
    plugins
  }
}
