import assert from 'node:assert/strict';
import { test } from 'node:test';
import { nationNameError } from './index';

test('valid nation names', () => {
  for (const name of ['Dacia', 'NewRome2', 'abc', 'X1234567890123456789']) assert.equal(nationNameError(name), null, name);
});

test('invalid nation names', () => {
  assert.match(nationNameError('1Rome')!, /start with a letter/);
  assert.match(nationNameError('New Rome')!, /letters and digits/);
  assert.match(nationNameError('Rome!')!, /letters and digits/);
  assert.match(nationNameError('România')!, /letters and digits/);
  assert.match(nationNameError('ab')!, /3-20/);
  assert.match(nationNameError('A'.repeat(21))!, /3-20/);
});
