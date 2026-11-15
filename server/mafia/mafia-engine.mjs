import { randomInt } from 'node:crypto';

export const Phase = Object.freeze({
  LOBBY:'lobby', ROLE_DISTRIBUTION:'roleDistribution', NIGHT:'night',
  DAWN:'dawn', DAY:'day', VOTING:'voting', DEFENSE:'defense',
  FINAL_VOTE:'finalVote', EXECUTION:'execution', FINISHED:'finished',
});
export const Role = Object.freeze({
  MAFIA:'mafia', CITIZEN:'citizen', DOCTOR:'doctor', DETECTIVE:'detective',
  MAFIA_BOSS:'mafiaBoss', SNIPER:'sniper', VETERAN:'veteran', MAYOR:'mayor',
  INTERROGATOR:'interrogator', MADMAN:'madman', JOKER:'joker',
});
export const Action = Object.freeze({
  KILL:'kill', PROTECT:'protect', INVESTIGATE:'investigate',
  SHOOT:'shoot', ALERT:'alert', INTERROGATE:'interrogate', PASS:'pass',
});
const teamOf = role => [Role.MAFIA,Role.MAFIA_BOSS].includes(role) ? 'mafia'
  : [Role.MADMAN,Role.JOKER].includes(role) ? 'neutral' : 'town';
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const iso = date => new Date(date).toISOString();

export function buildRoleSet(count, options={}) {
  assert(Number.isInteger(count) && count>=6 && count<=16,'Player count must be 6..16.');
  const roles=[];
  const mafia=count<=8?2:count<=11?3:count<=14?4:5;
  roles.push(...Array(mafia).fill(Role.MAFIA),Role.DOCTOR,Role.DETECTIVE);
  if(count>=9 && options.sniper!==false) roles.push(Role.SNIPER);
  if(count>=11 && options.veteran!==false) roles.push(Role.VETERAN);
  if(count>=12 && options.mayor!==false) roles.push(Role.MAYOR);
  if(count>=13 && options.interrogator!==false) roles.push(Role.INTERROGATOR);
  if(count>=14 && options.madman===true) roles.push(Role.MADMAN);
  if(count>=15 && options.joker===true) roles.push(Role.JOKER);
  for(const [role,n] of Object.entries(options.customRoles??{})) {
    assert(Object.values(Role).includes(role) && Number.isInteger(n) && n>=0,'Invalid custom role count.');
    roles.push(...Array(n).fill(role));
  }
  while(roles.length<count) roles.push(Role.CITIZEN);
  assert(roles.length===count,'Configured roles exceed player count.');
  return roles;
}

export class MafiaEngine {
  constructor({roster,roles,config={},now=new Date(),randomIndex=randomInt}) {
    assert(Array.isArray(roster)&&roster.length>=6&&roster.length<=16,'Mafia requires 6 to 16 players.');
    assert(new Set(roster.map(p=>p.id)).size===roster.length && roster.every(p=>typeof p.id==='string'&&p.id.trim()),'Player IDs must be unique and non-empty.');
    assert(roles.length===roster.length,'Role count does not match roster.');
    this.config={nightSeconds:45,daySeconds:180,voteSeconds:45,defenseSeconds:30,finalVoteSeconds:30,...config};
    this.players=new Map(roster.map((p,i)=>[p.id,{id:p.id,displayName:p.displayName,role:roles[i],alive:true,connected:true,reconnectDeadline:null}]));
    this.phase=Phase.ROLE_DISTRIBUTION; this.phaseDeadline=iso(now); this.round=0;
    this.actions=new Map(); this.votes=new Map(); this.defenseCandidates=new Set();
    this.usedSniperShots=new Set(); this.events=[]; this.winner=null; this.randomIndex=randomIndex;
    this._event('roles_distributed',now,{playerCount:roster.length});
  }
  static create({roster,config={},now=new Date(),randomIntFn=randomInt}) {
    const roles=buildRoleSet(roster.length,config);
    // Fisher-Yates with cryptographically secure randomInt in production.
    for(let i=roles.length-1;i>0;i--){const j=randomIntFn(i+1);[roles[i],roles[j]]=[roles[j],roles[i]];}
    return new MafiaEngine({roster,roles,config,now,randomIndex:randomIntFn});
  }
  get alivePlayers(){return [...this.players.values()].filter(p=>p.alive);}
  get mafiaAlive(){return this.alivePlayers.filter(p=>teamOf(p.role)==='mafia').length;}
  get townAlive(){return this.alivePlayers.filter(p=>teamOf(p.role)==='town').length;}
  beginNight(now=new Date()){
    this._require([Phase.ROLE_DISTRIBUTION,Phase.EXECUTION,Phase.DAY]);
    if(this._checkWin()) return;
    this.phase=Phase.NIGHT;this.round++;this.phaseDeadline=this._deadline(now,this.config.nightSeconds);
    this.actions.clear();this.votes.clear();this.defenseCandidates.clear();
    this._event('night_started',now,{round:this.round});
  }
  beginDay(now=new Date()){
    this._require([Phase.DAWN]);this.phase=Phase.DAY;
    this.phaseDeadline=this._deadline(now,this.config.daySeconds);this._event('day_started',now,{round:this.round});
  }
  openVoting(now=new Date()){
    this._require([Phase.DAY]);this.phase=Phase.VOTING;this.votes.clear();
    this.phaseDeadline=this._deadline(now,this.config.voteSeconds);this._event('voting_started',now,{});
  }
  submitNightAction({actorId,type,targetId=null},now=new Date()){
    this._require([Phase.NIGHT]);const actor=this._alive(actorId);
    assert(!this.actions.has(actorId),'Action already submitted.');
    const allowed={
      [Role.MAFIA]:[Action.KILL,Action.PASS],[Role.MAFIA_BOSS]:[Action.KILL,Action.PASS],
      [Role.DOCTOR]:[Action.PROTECT,Action.PASS],[Role.DETECTIVE]:[Action.INVESTIGATE,Action.PASS],
      [Role.SNIPER]:[Action.SHOOT,Action.PASS],[Role.VETERAN]:[Action.ALERT,Action.PASS],
      [Role.INTERROGATOR]:[Action.INTERROGATE,Action.PASS],
    };
    assert((allowed[actor.role]??[Action.PASS]).includes(type),'Role cannot perform this action.');
    if(type===Action.PASS) assert(targetId===null,'Pass cannot have a target.');
    else {
      const target=this.players.get(targetId);
      assert(target?.alive,'Target must be a living player.');
      assert(targetId!==actorId || type===Action.ALERT,'Self-target is not allowed.');
      if(type===Action.KILL) assert(teamOf(target.role)!=='mafia','Mafia cannot target its own team.');
    }
    if(type===Action.SHOOT) assert(!this.usedSniperShots.has(actorId),'Sniper shot already used.');
    this.actions.set(actorId,{actorId,type,targetId});
    this._event('night_action_submitted',now,{actorId,action:type,targetId});
  }
  resolveNight(now=new Date()){
    this._require([Phase.NIGHT]);
    const protections=new Set(),alerts=new Set(),attacks=new Map(),mafiaBallot=new Map(),privateResults={};
    for(const p of this.alivePlayers){
      const a=this.actions.get(p.id)??{type:Action.PASS};
      if(a.type===Action.PROTECT) protections.add(a.targetId);
      if(a.type===Action.ALERT) alerts.add(p.id);
      if(a.type===Action.KILL) mafiaBallot.set(a.targetId,[...(mafiaBallot.get(a.targetId)??[]),p.id]);
      if(a.type===Action.SHOOT){attacks.set(a.targetId,p.id);this.usedSniperShots.add(p.id);}
    }
    if(mafiaBallot.size){
      const high=Math.max(...[...mafiaBallot.values()].map(v=>v.length));
      const leaders=[...mafiaBallot.entries()].filter(([,v])=>v.length===high);
      if(leaders.length===1) attacks.set(leaders[0][0],leaders[0][1][0]);
    }
    const eliminated=new Set();
    for(const [targetId,attackerId] of attacks){
      if(protections.has(targetId)) continue;
      eliminated.add(targetId);
      if(alerts.has(targetId)) eliminated.add(attackerId);
    }
    for(const p of this.alivePlayers){
      const a=this.actions.get(p.id);if(!a || eliminated.has(p.id)) continue;
      if(a.type===Action.INVESTIGATE) privateResults[p.id]=teamOf(this.players.get(a.targetId).role)==='mafia'?'مافیا':'غیرمافیا';
      if(a.type===Action.INTERROGATE) privateResults[p.id]=teamOf(this.players.get(a.targetId).role);
    }
    for(const id of eliminated) this.players.get(id).alive=false;
    this.phase=Phase.DAWN;this.phaseDeadline=null;
    const eliminatedIds=[...eliminated].sort();
    this._event('night_resolved',now,{eliminatedIds});this._checkWin();
    return Object.freeze({eliminatedIds:Object.freeze(eliminatedIds),privateResults:Object.freeze({...privateResults})});
  }
  submitVote(voterId,targetId,now=new Date()){
    this._require([Phase.VOTING,Phase.FINAL_VOTE]);this._alive(voterId);
    const target=this.players.get(targetId);
    assert(target?.alive&&voterId!==targetId,'Invalid vote target.');
    if(this.phase===Phase.FINAL_VOTE) assert(this.defenseCandidates.has(targetId),'Final vote target must be a defense candidate.');
    this.votes.set(voterId,targetId);this._event('vote_submitted',now,{voterId,targetId});
  }
  closeVoting(now=new Date()){
    this._require([Phase.VOTING]);const counts=this._voteCounts();
    this.defenseCandidates.clear();
    if(counts.size){const high=Math.max(...counts.values());for(const [id,n] of counts)if(n===high)this.defenseCandidates.add(id);}
    this.phase=Phase.DEFENSE;this.phaseDeadline=this._deadline(now,this.config.defenseSeconds);this.votes.clear();
    this._event('defense_started',now,{candidateIds:[...this.defenseCandidates].sort()});
    return new Set(this.defenseCandidates);
  }
  openFinalVote(now=new Date()){
    this._require([Phase.DEFENSE]);this.phase=Phase.FINAL_VOTE;this.votes.clear();
    this.phaseDeadline=this._deadline(now,this.config.finalVoteSeconds);this._event('final_vote_started',now,{});
  }
  resolveFinalVote(now=new Date()){
    this._require([Phase.FINAL_VOTE]);const counts=this._voteCounts();let executed=null;
    if(counts.size){const high=Math.max(...counts.values());const leaders=[...counts].filter(([,n])=>n===high);if(leaders.length===1)executed=leaders[0][0];}
    this.phase=Phase.EXECUTION;this.phaseDeadline=null;if(executed)this.players.get(executed).alive=false;
    this._event('execution_resolved',now,{executedId:executed});this._checkWin();return executed;
  }
  setConnection(playerId,connected,now=new Date()){
    const p=this.players.get(playerId);assert(p?.alive,'Unknown or eliminated player.');
    p.connected=connected;p.reconnectDeadline=connected?null:this._deadline(now,60);
    this._event(connected?'player_reconnected':'player_disconnected',now,{playerId});
  }
  expireReconnects(now=new Date()){
    for(const p of this.players.values())if(p.alive&&!p.connected&&p.reconnectDeadline&&new Date(now)>=new Date(p.reconnectDeadline)){
      p.alive=false;p.reconnectDeadline=null;this._event('player_forfeit',now,{playerId:p.id});
    }
    this._checkWin();
  }
  publicSnapshot(){
    return Object.freeze({phase:this.phase,round:this.round,winner:this.winner,players:this.aliveAndDead().map(({id,displayName,alive,connected})=>({id,displayName,alive,connected}))});
  }
  privateSnapshot(authenticatedPlayerId){
    const p=this.players.get(authenticatedPlayerId);assert(p,'Player is not in this game.');
    const mafiaAllyIds=teamOf(p.role)==='mafia'?this.alivePlayers.filter(x=>teamOf(x.role)==='mafia').map(x=>x.id):[];
    return Object.freeze({playerId:p.id,role:p.role,mafiaAllyIds:Object.freeze(mafiaAllyIds)});
  }
  replayForModerator(){return this.events.map(e=>({...e}));}
  _alive(id){const p=this.players.get(id);assert(p?.alive,'Actor is not alive in this game.');return p;}
  _require(phases){assert(phases.includes(this.phase),`Action invalid during ${this.phase}.`);}
  _deadline(now,seconds){return iso(new Date(new Date(now).getTime()+seconds*1000));}
  _voteCounts(){
    const counts=new Map();
    for(const [voterId,targetId] of this.votes){const voter=this.players.get(voterId);if(!voter?.alive)continue;counts.set(targetId,(counts.get(targetId)??0)+(voter.role===Role.MAYOR?2:1));}
    return counts;
  }
  _checkWin(){
    if(this.phase===Phase.FINISHED)return true;
    if(this.mafiaAlive===0)this.winner='town';
    else if(this.mafiaAlive>=this.townAlive)this.winner='mafia';
    if(this.winner){this.phase=Phase.FINISHED;this.phaseDeadline=null;return true;}
    return false;
  }
  _event(type,at,data){this.events.push(Object.freeze({type,at:iso(at),...data}));}
  aliveAndDead(){return [...this.players.values()];}
}
