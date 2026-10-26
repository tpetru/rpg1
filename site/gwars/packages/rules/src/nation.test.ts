import assert from 'node:assert/strict';
import { test } from 'node:test';
import { nationNameError, nationNameIssue } from './index';

test('valid nation names', () => {
  for (const name of ['Dacia', 'NewRome2', 'abc', 'X1234567890123456789', 'New Rome', 'Saint-Pierre', 'Big Red Land', 'A-B-C D E']) {
    assert.equal(nationNameIssue(name), null, name);
  }
});

test('at most 2 spaces and 2 hyphens', () => {
  assert.equal(nationNameIssue('A B C D'), 'nation_spaces');
  assert.equal(nationNameIssue('A-B-C-D'), 'nation_hyphens');
  assert.equal(nationNameIssue('A B-C-D E'), null);
  assert.equal(nationNameIssue('Aa-Bb-Cc-Dd'), 'nation_hyphens');
});

test('invalid characters, start and separators', () => {
  assert.equal(nationNameIssue('1Dacia'), 'nation_start');
  assert.equal(nationNameIssue(' Dacia'), 'nation_start');
  assert.equal(nationNameIssue('-Dacia'), 'nation_start');
  assert.equal(nationNameIssue('Rome!'), 'nation_chars');
  assert.equal(nationNameIssue('România'), 'nation_chars');
  assert.equal(nationNameIssue('New_Rome'), 'nation_chars');
  assert.equal(nationNameIssue('New  Rome'), 'nation_separators');
  assert.equal(nationNameIssue('New - Rome'), 'nation_separators');
  assert.equal(nationNameIssue('Rome-'), 'nation_separators');
  assert.equal(nationNameIssue('Rome '), 'nation_separators');
});

test('length limits', () => {
  assert.equal(nationNameIssue('ab'), 'nation_length');
  assert.equal(nationNameIssue('A'.repeat(21)), 'nation_length');
  assert.match(nationNameError('ab')!, /3-20/);
  assert.equal(nationNameError('Dacia'), null);
});
