import { createGameRegistry } from './game-sdk.mjs';
import { xoGameModule } from './xo-game.mjs';

export const gameRegistry = createGameRegistry();
gameRegistry.register(xoGameModule);
