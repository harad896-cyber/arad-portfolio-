export const GAME_SDK_VERSION = 1;
export const MAX_SERIALIZED_STATE_BYTES = 2048;

const requiredMethods = ['init','getLegalMoves','applyMove','getResult','serialize','deserialize'];
const assert = (condition, message) => { if (!condition) throw new TypeError(message); };

export function createGameRegistry() {
  const modules = new Map();
  return Object.freeze({
    register(gameModule) {
      assert(gameModule && typeof gameModule.id === 'string' && /^[a-z][a-z0-9-]{1,31}$/.test(gameModule.id),
        'Game module must have a stable lowercase id.');
      for (const method of requiredMethods) assert(typeof gameModule[method] === 'function',
        `Game module "${gameModule.id}" is missing ${method}().`);
      assert(!modules.has(gameModule.id), `Game module "${gameModule.id}" is already registered.`);
      modules.set(gameModule.id, Object.freeze(gameModule));
      return gameModule.id;
    },
    get(gameId) {
      const gameModule = modules.get(gameId);
      assert(gameModule, `Unknown game module: ${gameId}.`);
      return gameModule;
    },
    list() { return [...modules.keys()].sort(); },
    has(gameId) { return modules.has(gameId); },
  });
}

export function createGame(registry, gameId, players, options = {}) {
  const gameModule = registry.get(gameId);
  const state = gameModule.init(players, options);
  assert(state && state.gameId === gameId, 'Module returned state for a different game.');
  return state;
}

export function getLegalMoves(registry, state, playerId) {
  return registry.get(state?.gameId).getLegalMoves(state, playerId);
}

export function applyGameMove(registry, state, playerId, move) {
  return registry.get(state?.gameId).applyMove(state, playerId, move);
}

export function getGameResult(registry, state) {
  return registry.get(state?.gameId).getResult(state);
}

export function serializeGame(registry, state) {
  const payload = registry.get(state?.gameId).serialize(state);
  const size = new TextEncoder().encode(payload).byteLength;
  assert(size < MAX_SERIALIZED_STATE_BYTES, `Serialized game state is ${size} bytes; limit is below 2048.`);
  return payload;
}

export function deserializeGame(registry, gameId, payload) {
  assert(typeof payload === 'string', 'Serialized state must be a string.');
  const size = new TextEncoder().encode(payload).byteLength;
  assert(size < MAX_SERIALIZED_STATE_BYTES, `Serialized game state is ${size} bytes; limit is below 2048.`);
  return registry.get(gameId).deserialize(payload);
}
