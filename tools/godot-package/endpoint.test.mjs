import test from 'node:test';
import assert from 'node:assert/strict';
import {lobbyEndpoint} from './endpoint.mjs';

test('external LATTICE routes reuse an existing authority while other routes stay local', () => {
  const endpoint = 'ws://127.0.0.1:12345';
  for (const experience of ['lobby', 'lattice', 'lattice-world']) {
    assert.equal(lobbyEndpoint(endpoint, experience), endpoint);
    assert.equal(lobbyEndpoint(undefined, experience), null);
  }
  for (const experience of ['combat', 'horde', 'sports', 'objectives']) {
    assert.throws(() => lobbyEndpoint(endpoint, experience), /requires --experience/);
  }
  for (const invalid of ['http://127.0.0.1:12345', 'ws://user:pass@host', 'ws://host/#fragment', 'ws://host/ bad']) {
    assert.throws(() => lobbyEndpoint(invalid, 'lattice-world'));
  }
});
