import { inspect } from 'util';
import test from 'ava';
import activeWindow from './index.js';

function asserter(t, result) {
	t.log(inspect(result));
	t.is(typeof result, 'object');
	t.is(typeof result.title, 'string');
	t.is(typeof result.id, 'number');
	t.is(typeof result.owner, 'object');
	t.is(typeof result.owner.name, 'string');
}

test('async', async t => {
	asserter(t, await activeWindow());
});

test('sync', t => {
	asserter(t, activeWindow.sync());
});
