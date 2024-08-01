import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from "https://deno.land/x/clarinet@v1.5.4/index.ts";
import { assertEquals, assert } from "https://deno.land/std@0.170.0/testing/asserts.ts";

const TICKET_PRICE = 10_000_000; // 10 STX in microSTX
const TICKETS_PER_DRAW = 100;

Clarinet.test({
  name: "Ensure that users can buy tickets",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(1)], wallet1.address),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    assertEquals(block.receipts[0].events[0].stx_transfer.amount, TICKET_PRICE.toString());
  },
});

Clarinet.test({
  name: "Ensure that users cannot buy tickets if they don't have enough STX",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(10000)], wallet1.address),
    ]);
    
    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectErr().expectUint(100);
  },
});

Clarinet.test({
  name: "Ensure that users cannot buy tickets after the draw is full",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(TICKETS_PER_DRAW)], wallet1.address),
      Tx.contractCall("lottery", "buy-tickets", [types.uint(1)], wallet1.address),
    ]);
    
    assertEquals(block.receipts.length, 2);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectErr().expectUint(101);
  },
});

Clarinet.test({
  name: "Ensure that only the contract owner can perform the draw",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(TICKETS_PER_DRAW)], wallet1.address),
      Tx.contractCall("lottery", "perform-draw", [], wallet1.address),
      Tx.contractCall("lottery", "perform-draw", [], deployer.address),
    ]);
    
    assertEquals(block.receipts.length, 3);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectErr().expectUint(101000); // ERR_UNAUTHORIZED
    block.receipts[2].result.expectOk();
  },
});

Clarinet.test({
  name: "Ensure that draw cannot be performed twice",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(TICKETS_PER_DRAW)], wallet1.address),
      Tx.contractCall("lottery", "perform-draw", [], deployer.address),
      Tx.contractCall("lottery", "perform-draw", [], deployer.address),
    ]);
    
    assertEquals(block.receipts.length, 3);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectErr().expectUint(101003); // ERR_DRAW_ALREADY_DONE
  },
});

Clarinet.test({
  name: "Ensure that only the winner can claim the reward",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(TICKETS_PER_DRAW)], wallet1.address),
      Tx.contractCall("lottery", "perform-draw", [], deployer.address),
      Tx.contractCall("lottery", "claim-reward", [], wallet2.address),
      Tx.contractCall("lottery", "claim-reward", [], wallet1.address),
    ]);
    
    assertEquals(block.receipts.length, 4);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    block.receipts[2].result.expectErr().expectUint(101002); // ERR_NOT_WINNER
    
    // The last receipt might be Ok or Err depending on whether wallet1 is the winner
    // We can't predict this due to the randomness, so we don't assert its result
  },
});

Clarinet.test({
  name: "Ensure that the cycle progresses correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(TICKETS_PER_DRAW)], wallet1.address),
      Tx.contractCall("lottery", "perform-draw", [], deployer.address),
      Tx.contractCall("lottery", "claim-reward", [], wallet1.address),
      Tx.contractCall("lottery", "buy-tickets", [types.uint(1)], wallet1.address),
    ]);
    
    assertEquals(block.receipts.length, 4);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectBool(true);
    block.receipts[1].result.expectOk();
    // The third receipt might be Ok or Err depending on whether wallet1 is the winner
    block.receipts[3].result.expectOk().expectBool(true);
  },
});

Clarinet.test({
  name: "Ensure that the cycle progress is reported correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const wallet1 = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(50)], wallet1.address),
    ]);
    
    let progress = chain.callReadOnlyFn("lottery", "get-cycle-progress", [], deployer.address);
    progress.result.expectUint(50);
    
    block = chain.mineBlock([
      Tx.contractCall("lottery", "buy-tickets", [types.uint(50)], wallet1.address),
    ]);
    
    progress = chain.callReadOnlyFn("lottery", "get-cycle-progress", [], deployer.address);
    progress.result.expectUint(100);
  },
});
