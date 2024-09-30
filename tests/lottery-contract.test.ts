import { Cl } from "@stacks/transactions";
import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const address3 = accounts.get("wallet_3")!;

describe("lottery contract tests", () => {
  beforeEach(() => {
    // Reset the contract state before each test
    simnet.mineEmptyBlock();
  });

  it('verifies starting a time-based lottery', () => {
    const startResponse = simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address1);
    console.log("start lottery response: " + Cl.prettyPrint(startResponse.result));
    expect(startResponse.result).toBeOk(Cl.bool(true));

    const lotteryType = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-type', [], address1);
    expect(lotteryType.result).toBe(Cl.stringAscii("time-based"));

    const endBlock = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-end-block', [], address1);
    expect(endBlock.result).toBeUint(simnet.blockHeight + 100);
  });

  it('verifies starting a participant-based lottery', () => {
    const startResponse = simnet.callPublicFn('lottery-contract', 'start-participant-lottery', [Cl.uint(10)], address1);
    console.log("start participant lottery response: " + Cl.prettyPrint(startResponse.result));
    expect(startResponse.result).toBeOk(Cl.bool(true));

    const lotteryType = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-type', [], address1);
    expect(lotteryType.result).toBe(Cl.stringAscii("participant-based"));

    const endCondition = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-end-condition', [], address1);
    expect(endCondition.result).toBeUint(10);
  });

  it('verifies buying a ticket', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address1);
    
    const buyResponse = simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address2);
    console.log("buy ticket response: " + Cl.prettyPrint(buyResponse.result));
    expect(buyResponse.result).toBeOk(Cl.bool(true));

    const participants = simnet.callReadOnlyFn('lottery-contract', 'get-participants', [], address1);
    expect(participants.result).toBeList([Cl.principal(address2)]);
  });

  it('verifies drawing a winner in time-based lottery', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(10)], address1);
    simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address2);
    simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address3);

    // Mine 10 blocks to end the lottery
    simnet.mineEmptyBlocks(10);

    const drawResponse = simnet.callPublicFn('lottery-contract', 'draw-winner', [], address1);
    console.log("draw winner response: " + Cl.prettyPrint(drawResponse.result));
    expect(drawResponse.result).toBeOk(Cl.principal(address2).or(Cl.principal(address3)));

    const lotteryType = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-type', [], address1);
    expect(lotteryType.result).toBe(Cl.stringAscii("none"));
  });

  it('verifies drawing a winner in participant-based lottery', () => {
    simnet.callPublicFn('lottery-contract', 'start-participant-lottery', [Cl.uint(2)], address1);
    simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address2);
    simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address3);

    const drawResponse = simnet.callPublicFn('lottery-contract', 'draw-winner', [], address1);
    console.log("draw winner response: " + Cl.prettyPrint(drawResponse.result));
    expect(drawResponse.result).toBeOk(Cl.principal(address2).or(Cl.principal(address3)));

    const lotteryType = simnet.callReadOnlyFn('lottery-contract', 'get-lottery-type', [], address1);
    expect(lotteryType.result).toBe(Cl.stringAscii("none"));
  });

  it('verifies lottery cannot be started while one is in progress', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address1);
    
    const startResponse = simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(50)], address1);
    console.log("start lottery while in progress response: " + Cl.prettyPrint(startResponse.result));
    expect(startResponse.result).toBeErr(Cl.uint(108)); // ERR_LOTTERY_IN_PROGRESS
  });

  it('verifies non-owner cannot start a lottery', () => {
    const startResponse = simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address2);
    console.log("non-owner start lottery response: " + Cl.prettyPrint(startResponse.result));
    expect(startResponse.result).toBeErr(Cl.uint(100)); // ERR_OWNER_ONLY
  });

  it('verifies ticket cannot be bought after lottery ends', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(10)], address1);
    simnet.mineEmptyBlocks(10);

    const buyResponse = simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address2);
    console.log("buy ticket after lottery ends response: " + Cl.prettyPrint(buyResponse.result));
    expect(buyResponse.result).toBeErr(Cl.uint(102)); // ERR_LOTTERY_ENDED
  });

  it('verifies winner cannot be drawn before lottery ends', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address1);
    simnet.callPublicFn('lottery-contract', 'buy-ticket', [], address2);

    const drawResponse = simnet.callPublicFn('lottery-contract', 'draw-winner', [], address1);
    console.log("draw winner before lottery ends response: " + Cl.prettyPrint(drawResponse.result));
    expect(drawResponse.result).toBeErr(Cl.uint(103)); // ERR_LOTTERY_NOT_ENDED
  });

  it('verifies contract balance increases when tickets are bought', () => {
    simnet.callPublicFn('lottery-contract', 'start-lottery', [Cl.uint(100)], address1);
    
    const initialBalance = simnet.callReadOnlyFn('lottery', 'get-balance', [], address1);
    simnet.callPublicFn('lottery', 'buy-ticket', [], address2);
    const finalBalance = simnet.callReadOnlyFn('lottery', 'get-balance', [], address1);

    const initialBalanceNumber = Number(Cl.prettyPrint(initialBalance.result).replace('u', ''));
    const finalBalanceNumber = Number(Cl.prettyPrint(finalBalance.result).replace('u', ''));

    expect(finalBalanceNumber).toBe(initialBalanceNumber + 1000000); // ticket price
  });
});
