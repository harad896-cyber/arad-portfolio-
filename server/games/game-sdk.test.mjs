import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createGameRegistry,createGame,getLegalMoves,applyGameMove,getGameResult,
  serializeGame,deserializeGame,MAX_SERIALIZED_STATE_BYTES,
} from './game-sdk.mjs';

const module=(id='mock')=>({id,init:()=>({gameId:id}),getLegalMoves:()=>[],applyMove:s=>s,
 getResult:()=>({status:'active'}),serialize:s=>JSON.stringify(s),deserialize:s=>JSON.parse(s)});

test('registry registers, lists and retrieves modules',()=>{
 const registry=createGameRegistry();registry.register(module('alpha'));registry.register(module('beta'));
 assert.deepEqual(registry.list(),['alpha','beta']);assert.equal(registry.has('alpha'),true);
 assert.equal(registry.get('beta').id,'beta');
});
test('registry rejects malformed modules, duplicate IDs and unknown games',()=>{
 const registry=createGameRegistry();assert.throws(()=>registry.register({id:'bad'}));
 registry.register(module());assert.throws(()=>registry.register(module()));assert.throws(()=>registry.get('missing'));
});
test('SDK delegates the stable module contract and enforces the serialized state budget',()=>{
 const registry=createGameRegistry();registry.register(module());
 const state=createGame(registry,'mock',[]);assert.deepEqual(getLegalMoves(registry,state,'p'),[]);
 assert.equal(applyGameMove(registry,state,'p',{}),state);
 assert.deepEqual(getGameResult(registry,state),{status:'active'});
 assert.deepEqual(deserializeGame(registry,'mock',serializeGame(registry,state)),state);
 const oversized={gameId:'mock',data:'x'.repeat(MAX_SERIALIZED_STATE_BYTES)};
 assert.throws(()=>serializeGame(registry,oversized),/2048/);
 assert.throws(()=>deserializeGame(registry,'mock','x'.repeat(MAX_SERIALIZED_STATE_BYTES)),/2048/);
});
