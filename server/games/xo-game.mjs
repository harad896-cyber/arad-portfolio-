import { MAX_SERIALIZED_STATE_BYTES } from './game-sdk.mjs';

export const XO_GAME_ID = 'xo';
export const XO_SCHEMA_VERSION = 1;
export const XO_VARIANTS = Object.freeze({
  CLASSIC: 'classic',
  FIVE: 'five',
});

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const clone = state => ({
  ...state,
  players: [...state.players],
  board: [...state.board],
  winningLine: state.winningLine ? [...state.winningLine] : null,
});
const validPlayerId = id => typeof id === 'string' && id.length > 0 && id.length <= 64;

function normalizePlayers(players) {
  assert(Array.isArray(players) && players.length === 2, 'XO requires exactly two players.');
  const ids = players.map(player => typeof player === 'string' ? player : player?.id);
  assert(ids.every(validPlayerId), 'Each player must have a non-empty ID of at most 64 characters.');
  assert(new Set(ids).size === 2, 'XO player IDs must be unique.');
  return ids;
}

function getWinningLine(board, size, winLength) {
  const directions = [[0,1],[1,0],[1,1],[1,-1]];
  const lines = [];
  for (let row=0; row<size; row++) {
    for (let col=0; col<size; col++) {
      const player = board[row*size+col];
      if (player === null) continue;
      for (const [dr,dc] of directions) {
        const endRow=row+(winLength-1)*dr, endCol=col+(winLength-1)*dc;
        if (endRow<0 || endRow>=size || endCol<0 || endCol>=size) continue;
        const line=[];
        for(let step=0;step<winLength;step++) line.push((row+step*dr)*size+col+step*dc);
        if(line.every(index=>board[index]===player)) lines.push({playerId:player,line});
      }
    }
  }
  if (lines.length > 1 && new Set(lines.map(item=>item.playerId)).size > 1) {
    throw new Error('Invalid state: both players have winning lines.');
  }
  return lines[0] ?? null;
}

function calculateResult(state) {
  const win = getWinningLine(state.board,state.boardSize,state.winLength);
  if (win) return {status:'won',winnerId:win.playerId,winningLine:win.line};
  if (state.board.every(cell=>cell!==null)) return {status:'draw',winnerId:null,winningLine:null};
  return {status:'active',winnerId:null,winningLine:null};
}

function validateState(state) {
  assert(state && typeof state==='object' && !Array.isArray(state),'State must be an object.');
  assert(state.gameId===XO_GAME_ID && state.schemaVersion===XO_SCHEMA_VERSION,'Unsupported XO state version.');
  assert([XO_VARIANTS.CLASSIC,XO_VARIANTS.FIVE].includes(state.variant),'Unknown XO variant.');
  const size=state.variant===XO_VARIANTS.CLASSIC?3:5;
  const winLength=state.variant===XO_VARIANTS.CLASSIC?3:4;
  assert(state.boardSize===size && state.winLength===winLength,'Board rules do not match the variant.');
  assert(Array.isArray(state.players)&&state.players.length===2&&state.players.every(validPlayerId)
    &&new Set(state.players).size===2,'Invalid players in state.');
  assert(Array.isArray(state.board)&&state.board.length===size*size,'Invalid board dimensions.');
  assert(state.board.every(cell=>cell===null||state.players.includes(cell)),'Board contains an unknown mark.');
  const counts=state.players.map(id=>state.board.filter(cell=>cell===id).length);
  assert(counts[0]===counts[1]||counts[0]===counts[1]+1,'Invalid turn counts.');
  const moveCount=state.board.filter(cell=>cell!==null).length;
  assert(state.moveCount===moveCount,'Move count does not match board.');
  const expectedTurn=counts[0]===counts[1]?state.players[0]:state.players[1];
  assert(state.currentPlayerId===expectedTurn,'Current player does not match board turn.');
  assert(Number.isInteger(state.version)&&state.version===moveCount,'Invalid state version.');
  const result=calculateResult(state);
  assert(state.status===result.status&&state.winnerId===result.winnerId,'Stored result does not match board.');
  assert(JSON.stringify(state.winningLine??null)===JSON.stringify(result.winningLine),'Winning line does not match board.');
  if(result.status==='won'){
    assert(counts[0]===counts[1]+1&&result.winnerId===state.players[0] ||
      counts[0]===counts[1]&&result.winnerId===state.players[1],
      'Winner cannot have made the last move.');
  }
  return result;
}

export const xoGameModule = Object.freeze({
  id: XO_GAME_ID,

  init(players, options={}) {
    const ids=normalizePlayers(players);
    const variant=options.variant??XO_VARIANTS.CLASSIC;
    assert([XO_VARIANTS.CLASSIC,XO_VARIANTS.FIVE].includes(variant),'Variant must be classic or five.');
    const boardSize=variant===XO_VARIANTS.CLASSIC?3:5;
    const winLength=variant===XO_VARIANTS.CLASSIC?3:4;
    return {
      gameId:XO_GAME_ID,schemaVersion:XO_SCHEMA_VERSION,
      gameInstanceId:typeof options.gameInstanceId==='string'&&options.gameInstanceId.length<=64?options.gameInstanceId:'xo',
      variant,boardSize,winLength,players:ids,board:Array(boardSize*boardSize).fill(null),
      currentPlayerId:ids[0],moveCount:0,version:0,status:'active',winnerId:null,winningLine:null,
    };
  },

  getLegalMoves(state, playerId) {
    validateState(state);
    if(state.status!=='active'||state.currentPlayerId!==playerId)return [];
    return state.board.flatMap((cell,index)=>cell===null?[{index}]:[]);
  },

  applyMove(state, playerId, move) {
    validateState(state);
    assert(state.status==='active','Game is already finished.');
    assert(playerId===state.currentPlayerId,'It is not this player\'s turn.');
    assert(move&&Number.isInteger(move.index)&&move.index>=0&&move.index<state.board.length,
      'Move index is outside the board.');
    assert(state.board[move.index]===null,'Cell is already occupied.');
    const next=clone(state);
    next.board[move.index]=playerId;
    next.moveCount++;
    next.version++;
    next.currentPlayerId=state.players.find(id=>id!==playerId);
    const result=calculateResult(next);
    next.status=result.status;next.winnerId=result.winnerId;next.winningLine=result.winningLine;
    validateState(next);
    return next;
  },

  getResult(state) {
    const result=validateState(state);
    return {...result,winningLine:result.winningLine?[...result.winningLine]:null};
  },

  serialize(state) {
    validateState(state);
    const payload=JSON.stringify(state);
    const bytes=new TextEncoder().encode(payload).byteLength;
    assert(bytes<MAX_SERIALIZED_STATE_BYTES,'XO state exceeds the 2 KB limit.');
    return payload;
  },

  deserialize(payload) {
    assert(typeof payload==='string','Serialized XO state must be a string.');
    assert(new TextEncoder().encode(payload).byteLength<MAX_SERIALIZED_STATE_BYTES,'Serialized XO state exceeds 2 KB.');
    let state;
    try { state=JSON.parse(payload); } catch { throw new Error('Serialized XO state is not valid JSON.'); }
    validateState(state);
    return clone(state);
  },
});
