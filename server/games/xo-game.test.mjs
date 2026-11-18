import test from 'node:test';
import assert from 'node:assert/strict';
import {createGameRegistry,createGame,getLegalMoves,applyGameMove,getGameResult,serializeGame,deserializeGame} from './game-sdk.mjs';
import {xoGameModule,XO_VARIANTS} from './xo-game.mjs';

const registry=createGameRegistry();registry.register(xoGameModule);
const newGame=(variant=XO_VARIANTS.CLASSIC)=>createGame(registry,'xo',['alice','bob'],{variant,gameInstanceId:'test-1'});
const play=(state,...indices)=>indices.reduce((s,index)=>applyGameMove(registry,s,s.currentPlayerId,{index}),state);

test('classic XO initializes a 3x3 board and exposes only legal moves to current player',()=>{
 const s=newGame();assert.equal(s.board.length,9);assert.equal(s.currentPlayerId,'alice');
 assert.equal(getLegalMoves(registry,s,'alice').length,9);assert.deepEqual(getLegalMoves(registry,s,'bob'),[]);
});
test('classic XO detects horizontal, vertical, main and anti-diagonal wins',()=>{
 const cases=[
  [0,3,1,4,2],
  [0,1,3,4,6],
  [0,1,4,2,8],
  [2,0,4,1,6],
 ];
 for(const moves of cases){const s=play(newGame(),...moves);assert.equal(getGameResult(registry,s).status,'won');assert.equal(getGameResult(registry,s).winnerId,'alice');assert.equal(getGameResult(registry,s).winningLine.length,3);}
});
test('classic XO detects a draw with a full board and no winning line',()=>{
 const s=play(newGame(),0,1,2,4,3,5,7,6,8);
 assert.deepEqual(getGameResult(registry,s),{status:'draw',winnerId:null,winningLine:null});
});
test('occupied, out-of-range, non-integer, wrong-turn and post-game moves are rejected',()=>{
 const s=applyGameMove(registry,newGame(),'alice',{index:0});
 assert.throws(()=>applyGameMove(registry,s,'bob',{index:0}),/occupied/);
 assert.throws(()=>applyGameMove(registry,s,'bob',{index:9}),/outside/);
 assert.throws(()=>applyGameMove(registry,s,'bob',{index:1.5}),/outside/);
 assert.throws(()=>applyGameMove(registry,s,'alice',{index:1}),/turn/);
 const won=play(newGame(),0,3,1,4,2);
 assert.throws(()=>applyGameMove(registry,won,'bob',{index:5}),/finished/);
});
test('applyMove is pure and never mutates the previous state',()=>{
 const before=newGame(),snapshot=JSON.stringify(before);const after=applyGameMove(registry,before,'alice',{index:4});
 assert.equal(JSON.stringify(before),snapshot);assert.equal(after.board[4],'alice');assert.notEqual(after,before);
});
test('five-by-five bonus mode requires four connected marks in each direction',()=>{
 const wins=[
  [5,0,6,1,7,2,8],
  [0,1,5,2,10,3,15],
  [0,1,6,2,12,3,18],
  [3,0,7,1,11,2,15],
 ];
 for(const moves of wins){const s=play(newGame(XO_VARIANTS.FIVE),...moves);const r=getGameResult(registry,s);
  assert.equal(r.status,'won');assert.equal(r.winnerId,'alice');assert.equal(r.winningLine.length,4);}
});
test('five-by-five mode does not award a win for only three in a row',()=>{
 const s=play(newGame(XO_VARIANTS.FIVE),0,5,1,6,2);
 assert.equal(getGameResult(registry,s).status,'active');
});
test('init rejects invalid player lists and unsupported variants',()=>{
 assert.throws(()=>createGame(registry,'xo',['alice']),/two players/);
 assert.throws(()=>createGame(registry,'xo',['alice','alice']),/unique/);
 assert.throws(()=>createGame(registry,'xo',['alice','bob'],{variant:'giant'}),/variant/);
});
test('serialize/deserialize round-trip preserves state and remains below 2 KB',()=>{
 const s=play(newGame(XO_VARIANTS.FIVE),0,6,1,7,2);
 const payload=serializeGame(registry,s);assert.ok(new TextEncoder().encode(payload).byteLength<2048);
 assert.deepEqual(deserializeGame(registry,'xo',payload),s);
 assert.throws(()=>deserializeGame(registry,'xo','{broken'),/valid JSON/);
 const corrupted={...s,currentPlayerId:'alice'};
 assert.throws(()=>deserializeGame(registry,'xo',JSON.stringify(corrupted)),/turn/);
});
test('winning line is exact and highlights only the four winning cells in bonus mode',()=>{
 const s=play(newGame(XO_VARIANTS.FIVE),5,0,6,1,7,2,8);
 assert.deepEqual(getGameResult(registry,s).winningLine,[5,6,7,8]);
});
test('10,000 random bot games complete without invalid states or stuck turns',()=>{
 let seed=0x12345678;
 const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/0x100000000;};
 for(let game=0;game<10000;game++){
  let state=newGame(game%2===0?XO_VARIANTS.CLASSIC:XO_VARIANTS.FIVE),steps=0;
  while(state.status==='active'&&steps<25){
   const legal=getLegalMoves(registry,state,state.currentPlayerId);
   assert.ok(legal.length>0);const move=legal[Math.floor(random()*legal.length)];
   state=applyGameMove(registry,state,state.currentPlayerId,move);steps++;
  }
  assert.notEqual(state.status,'active',`game ${game} did not finish`);
  assert.ok(steps<=25);
 }
});
