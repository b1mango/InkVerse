// Isolated QML JavaScript contract checks; this does not replace native Qt QA.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../ui/pages/ReaderPage.qml'), 'utf8');

function qmlFunction(name) {
  const start = source.indexOf(`    function ${name}(`);
  assert.notEqual(start, -1);
  const open = source.indexOf('{', start);
  let depth = 1, end = open + 1;
  for (; depth; end++) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
  }
  return source.slice(start, end);
}

test('encoding selection preserves text and prior choice after rejected decoding', () => {
  const context = vm.createContext({
    bookId: 'book', bookText: 'old text', _textEncoding: 'gb18030', _textError: '',
    _textEncodings: ['auto', 'utf-8-sig', 'gb18030'], encodingChoice: {},
    Qt: { binding: fn => fn }, jumpToPage() { throw Error('must not jump on failure'); },
    backend: { changeTextEncoding: () => ({error: 'invalid encoding'}) },
  });
  context.root = context;
  vm.runInContext(qmlFunction('changeTextEncoding'), context);
  context.changeTextEncoding('utf-8-sig');
  assert.equal(context.bookText, 'old text');
  assert.equal(context._textEncoding, 'gb18030');
  assert.equal(context._textError, 'invalid encoding');
  assert.equal(context.encodingChoice.currentIndex(), 2);
  context._textEncoding = 'auto'; // Retained binding follows opening another book.
  assert.equal(context.encodingChoice.currentIndex(), 0);
});

test('successful encoding choice replaces text and resets pagination', () => {
  const pages = [];
  const context = vm.createContext({
    bookId: 'book', bookText: 'old', _textEncoding: 'auto', _textError: 'old error',
    _textEncodings: ['auto', 'gb18030'], encodingChoice: {},
    Qt: { binding: fn => fn }, jumpToPage: page => pages.push(page),
    backend: { changeTextEncoding: () => ({text: '中文书籍', encoding: 'gb18030', error: ''}) },
  });
  context.root = context;
  vm.runInContext(qmlFunction('changeTextEncoding'), context);
  context.changeTextEncoding('gb18030');
  assert.equal(context.bookText, '中文书籍');
  assert.equal(context._textError, '');
  assert.equal(context.encodingChoice.currentIndex(), 1);
  assert.deepEqual(pages, [0]);
});
