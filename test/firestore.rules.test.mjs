import { after, before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

const accountContext = (uid) =>
  env.authenticatedContext(uid, {
    firebase: { sign_in_provider: 'google.com' },
  });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'foxyco-rules-test',
    firestore: { rules: await readFile('firestore.rules', 'utf8') },
  });
});

beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

test('owner can create a server-stamped trial and read it', async () => {
  const owner = 'owner';
  const trial = 'trials/owner';
  const db = accountContext(owner).firestore();

  await assertSucceeds(setDoc(doc(db, trial), { startedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(db, trial)));
});

test('another account cannot create or read an owner trial', async () => {
  const ownerDb = accountContext('owner').firestore();
  const otherDb = accountContext('other').firestore();
  await assertSucceeds(
    setDoc(doc(ownerDb, 'trials/owner'), { startedAt: serverTimestamp() }),
  );

  await assertFails(
    setDoc(doc(otherDb, 'trials/owner'), { startedAt: serverTimestamp() }),
  );
  await assertFails(getDoc(doc(otherDb, 'trials/owner')));
});

test('chosen timestamps and extra trial fields are rejected', async () => {
  const db = accountContext('owner').firestore();

  await assertFails(
    setDoc(doc(db, 'trials/owner'), { startedAt: new Date(0) }),
  );
  await assertFails(
    setDoc(doc(db, 'trials/owner'), {
      startedAt: serverTimestamp(),
      reset: true,
    }),
  );
});

test('a trial cannot be updated or deleted', async () => {
  const db = accountContext('owner').firestore();
  const trial = doc(db, 'trials/owner');
  await assertSucceeds(setDoc(trial, { startedAt: serverTimestamp() }));

  await assertFails(updateDoc(trial, { startedAt: serverTimestamp() }));
  await assertFails(deleteDoc(trial));
});

test('signed-out, anonymous-auth, and every other path are denied', async () => {
  const signedOut = env.unauthenticatedContext().firestore();
  const anonymous = env
    .authenticatedContext('anonymous', {
      firebase: { sign_in_provider: 'anonymous' },
    })
    .firestore();
  const owner = accountContext('owner').firestore();

  await assertFails(getDoc(doc(signedOut, 'trials/owner')));
  await assertFails(
    setDoc(doc(anonymous, 'trials/anonymous'), {
      startedAt: serverTimestamp(),
    }),
  );
  await assertFails(getDoc(doc(anonymous, 'trials/anonymous')));
  await assertFails(setDoc(doc(owner, 'offers/one'), { payout: 10 }));
  await assertFails(getDoc(doc(owner, 'offers/one')));
});
