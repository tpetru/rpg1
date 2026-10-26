import assert from 'node:assert/strict';
import { test } from 'node:test';
import { settlementNameIssue } from './index';

test('valid settlement names', () => {
  for (const name of ['Roma', 'București', 'São Paulo', 'Saint-Pierre', 'Fort Knox 2', 'Éire', 'A-B C-D E']) {
    assert.equal(settlementNameIssue(name), null, name);
  }
});

test('diacritics count as single characters', () => {
  assert.equal(settlementNameIssue('Ștei'), null);
  assert.equal(settlementNameIssue('Ăăă'), null);
  assert.equal(settlementNameIssue('Ab'), 'settlement_length');
  assert.equal(settlementNameIssue('Ț'.repeat(25)), null);
  assert.equal(settlementNameIssue('Ț'.repeat(26)), 'settlement_length');
});

test('invalid names', () => {
  assert.equal(settlementNameIssue('1Roma'), 'settlement_start');
  assert.equal(settlementNameIssue('-Roma'), 'settlement_start');
  assert.equal(settlementNameIssue('Roma!'), 'settlement_chars');
  assert.equal(settlementNameIssue('Roma_2'), 'settlement_chars');
  assert.equal(settlementNameIssue('Roma <b>'), 'settlement_chars');
  assert.equal(settlementNameIssue('A B C D'), 'settlement_spaces');
  assert.equal(settlementNameIssue('A-B-C-D'), 'settlement_hyphens');
  assert.equal(settlementNameIssue('Roma  Nova'), 'settlement_separators');
  assert.equal(settlementNameIssue('Roma-'), 'settlement_separators');
});
