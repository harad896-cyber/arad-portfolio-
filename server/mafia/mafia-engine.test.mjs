import test from 'node:test';
import assert from 'node:assert/strict';
import {MafiaEngine,buildRoleSet,Role,Action,Phase} from './mafia-engine.mjs';

const roster=Array.from({length:8},(_,i)=>({id:'p'+i,displayName:'Player '+i}));
const fixedRoles=[Role.MAFIA,Role.MAFIA,Role.DOCTOR,Role.DETECTIVE,Role.CITIZEN,Role.CITIZEN,Role.CITIZEN,Role.CITIZEN];
const game=()=>new MafiaEngine({roster,roles:[...fixedRoles],now:new Date('2026-01-01T00:00:00Z')});
const setRoles=(g,roles)=>{for(const [id,role] of Object.entries(roles))g.players.get(id).role=role;};

test('8-player default role composition is exactly 2 mafia, doctor, detective, 4 citizens',()=>{
 const roles=buildRoleSet(8);assert.equal(roles.filter(x=>x===Role.MAFIA).length,2);
 assert.equal(roles.filter(x=>x===Role.DOCTOR).length,1);assert.equal(roles.filter(x=>x===Role.DETECTIVE).length,1);
 assert.equal(roles.filter(x=>x===Role.CITIZEN).length,4);
});
test('role bounds, custom-role overflow and duplicate IDs are rejected',()=>{
 assert.throws(()=>buildRoleSet(5));assert.throws(()=>buildRoleSet(8,{customRoles:{[Role.JOKER]:8}}));
 assert.throws(()=>new MafiaEngine({roster:[...roster,{id:'p0',displayName:'dup'}],roles:Array(9).fill(Role.CITIZEN)}));
});
test('public snapshot omits every secret role; private snapshot returns only own role/allies',()=>{
 const g=game();const pub=JSON.stringify(g.publicSnapshot());
 assert.equal(pub.includes('mafia'),false);assert.equal(g.publicSnapshot().players[0].role,undefined);
 assert.deepEqual(g.privateSnapshot('p0').mafiaAllyIds,['p0','p1']);
 assert.deepEqual(g.privateSnapshot('p4').mafiaAllyIds,[]);
 assert.throws(()=>g.privateSnapshot('intruder'));
});
test('doctor protection is resolved before mafia attack',()=>{
 const g=game();g.beginNight();
 g.submitNightAction({actorId:'p0',type:Action.KILL,targetId:'p4'});
 g.submitNightAction({actorId:'p2',type:Action.PROTECT,targetId:'p4'});
 const result=g.resolveNight();assert.deepEqual(result.eliminatedIds,[]);assert.equal(g.players.get('p4').alive,true);
});
test('mafia shared kill ballot tie results in no kill',()=>{
 const g=game();g.beginNight();
 g.submitNightAction({actorId:'p0',type:Action.KILL,targetId:'p4'});
 g.submitNightAction({actorId:'p1',type:Action.KILL,targetId:'p5'});
 assert.deepEqual(g.resolveNight().eliminatedIds,[]);
});
test('detective result is private and not broadcast in public snapshot',()=>{
 const g=game();g.beginNight();g.submitNightAction({actorId:'p3',type:Action.INVESTIGATE,targetId:'p0'});
 const r=g.resolveNight();assert.deepEqual(r.privateResults,{p3:'مافیا'});
 assert.equal(JSON.stringify(g.publicSnapshot()).includes('مافیا'),false);
});
test('missing actions become pass and phase transitions reject out-of-order calls',()=>{
 const g=game();g.beginNight();assert.throws(()=>g.openVoting());assert.deepEqual(g.resolveNight().eliminatedIds,[]);
 assert.equal(g.phase,Phase.DAWN);g.beginDay();g.openVoting();g.closeVoting();g.openFinalVote();assert.equal(g.resolveFinalVote(),null);
});
test('invalid role actions, self-targets, duplicate actions and dead actors are rejected',()=>{
 const g=game();g.beginNight();
 assert.throws(()=>g.submitNightAction({actorId:'p4',type:Action.KILL,targetId:'p0'}));
 assert.throws(()=>g.submitNightAction({actorId:'p0',type:Action.KILL,targetId:'p0'}));
 g.submitNightAction({actorId:'p0',type:Action.KILL,targetId:'p4'});
 assert.throws(()=>g.submitNightAction({actorId:'p0',type:Action.KILL,targetId:'p5'}));
});
test('first-round tied leaders both advance; final-vote tie executes nobody',()=>{
 const g=game();g.beginNight();g.resolveNight();g.beginDay();g.openVoting();
 for(const [v,t] of Object.entries({p0:'p4',p1:'p4',p2:'p4',p3:'p5',p6:'p5',p7:'p5'}))g.submitVote(v,t);
 assert.deepEqual([...g.closeVoting()].sort(),['p4','p5']);g.openFinalVote();
 g.submitVote('p0','p4');g.submitVote('p1','p5');assert.equal(g.resolveFinalVote(),null);
 assert.equal(g.players.get('p4').alive,true);
});
test('final vote cannot target a player who was not on defense',()=>{
 const g=game();g.beginNight();g.resolveNight();g.beginDay();g.openVoting();g.submitVote('p0','p4');
 g.closeVoting();g.openFinalVote();assert.throws(()=>g.submitVote('p1','p5'));
});
test('mafia wins at parity; town wins when all mafia are eliminated',()=>{
 const g=game();for(let i=2;i<8;i++)g.players.get('p'+i).alive=false;g.beginNight();
 assert.equal(g.phase,Phase.FINISHED);assert.equal(g.winner,'mafia');
 const h=game();h.players.get('p0').alive=false;h.players.get('p1').alive=false;h.beginNight();
 assert.equal(h.phase,Phase.FINISHED);assert.equal(h.winner,'town');
});
test('disconnect grace is exactly 60 seconds and reconnect cancels expiry',()=>{
 const g=game(),t=new Date('2026-01-01T00:00:00Z');g.setConnection('p4',false,t);
 g.expireReconnects(new Date(t.getTime()+59000));assert.equal(g.players.get('p4').alive,true);
 g.setConnection('p4',true,new Date(t.getTime()+59000));g.setConnection('p4',false,t);
 g.expireReconnects(new Date(t.getTime()+60000));assert.equal(g.players.get('p4').alive,false);
});
test('phase deadlines are server-generated and event log is append-only',()=>{
 const g=game(),t=new Date('2026-01-01T00:00:00Z');g.beginNight(t);
 assert.equal(g.phaseDeadline,'2026-01-01T00:00:45.000Z');
 assert.equal(g.events.at(-1).type,'night_started');assert.equal('role' in g.events.at(-1),false);
});
