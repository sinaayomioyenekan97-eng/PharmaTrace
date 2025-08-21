import { describe, it, expect, beforeEach } from "vitest";

interface Batch {
  manufacturer: string;
  name: string;
  composition: string;
  expiration: bigint;
  productionDate: bigint;
  status: bigint;
  createdAt: bigint;
  updatedAt: bigint;
}

interface AuditLog {
  action: string;
  actor: string;
  timestamp: bigint;
  metadata: string;
}

const mockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  batchCounter: 0n,
  drugBatches: new Map<string, Batch>(),
  batchAuditLog: new Map<string, AuditLog>(),
  blockHeight: 1000n,

  isAdmin(caller: string): boolean {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    return { value: pause };
  },

  validateMetadata(metadata: string): boolean {
    return metadata.length > 0 && metadata.length <= 256;
  },

  validateStatus(status: bigint): boolean {
    return [0n, 1n, 2n, 3n, 4n].includes(status);
  },

  registerBatch(
    caller: string,
    name: string,
    composition: string,
    expiration: bigint,
    productionDate: bigint
  ) {
    if (this.paused) return { error: 104 };
    if (caller === "SP000000000000000000002Q6VF78") return { error: 107 };
    if (!this.validateMetadata(name) || !this.validateMetadata(composition))
      return { error: 105 };
    if (expiration <= this.blockHeight) return { error: 108 };
    if (productionDate > this.blockHeight) return { error: 108 };

    const batchId = this.batchCounter + 1n;
    const batchKey = `${batchId}`;
    if (this.drugBatches.has(batchKey)) return { error: 102 };

    this.drugBatches.set(batchKey, {
      manufacturer: caller,
      name,
      composition,
      expiration,
      productionDate,
      status: 0n,
      createdAt: this.blockHeight,
      updatedAt: this.blockHeight,
    });

    this.batchAuditLog.set(`${batchId}-0`, {
      action: "batch-registered",
      actor: caller,
      timestamp: this.blockHeight,
      metadata: "Initial batch registration",
    });

    this.batchCounter = batchId;
    return { value: batchId };
  },

  updateBatchStatus(caller: string, batchId: bigint, newStatus: bigint) {
    if (this.paused) return { error: 104 };
    if (batchId <= 0n) return { error: 101 };
    if (!this.validateStatus(newStatus)) return { error: 106 };
    if (newStatus === 4n) return { error: 106 };

    const batchKey = `${batchId}`;
    const batch = this.drugBatches.get(batchKey);
    if (!batch) return { error: 103 };
    if (caller !== batch.manufacturer) return { error: 100 };

    this.drugBatches.set(batchKey, { ...batch, status: newStatus, updatedAt: this.blockHeight });

    const logIndex = this.getLastLogIndex(batchId) + 1n;
    this.batchAuditLog.set(`${batchId}-${logIndex}`, {
      action: "status-updated",
      actor: caller,
      timestamp: this.blockHeight,
      metadata: `Status changed to ${newStatus}`,
    });

    return { value: true };
  },

  recallBatch(caller: string, batchId: bigint, reason: string) {
    if (this.paused) return { error: 104 };
    if (batchId <= 0n) return { error: 101 };
    if (!this.validateMetadata(reason)) return { error: 105 };

    const batchKey = `${batchId}`;
    const batch = this.drugBatches.get(batchKey);
    if (!batch) return { error: 103 };
    if (caller !== batch.manufacturer) return { error: 100 };

    this.drugBatches.set(batchKey, { ...batch, status: 4n, updatedAt: this.blockHeight });

    const logIndex = this.getLastLogIndex(batchId) + 1n;
    this.batchAuditLog.set(`${batchId}-${logIndex}`, {
      action: "batch-recalled",
      actor: caller,
      timestamp: this.blockHeight,
      metadata: reason,
    });

    return { value: true };
  },

  getLastLogIndex(batchId: bigint): bigint {
    let index = 0n;
    while (this.batchAuditLog.has(`${batchId}-${index}`)) {
      index++;
    }
    return index - 1n;
  },

  getBatchDetails(batchId: bigint) {
    const batch = this.drugBatches.get(`${batchId}`);
    return batch ? { value: batch } : { error: 103 };
  },

  getAuditLog(batchId: bigint, logIndex: bigint) {
    const log = this.batchAuditLog.get(`${batchId}-${logIndex}`);
    return log ? { value: log } : { error: 103 };
  },
};

describe("PharmaTrace Drug Registry", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.batchCounter = 0n;
    mockContract.drugBatches = new Map();
    mockContract.batchAuditLog = new Map();
    mockContract.blockHeight = 1000n;
  });

  it("should register a new batch", () => {
    const result = mockContract.registerBatch(
      "ST2CY5...",
      "Aspirin",
      "Acetylsalicylic acid 500mg",
      2000n,
      500n
    );
    expect(result).toEqual({ value: 1n });
    const batch = mockContract.drugBatches.get("1");
    expect(batch).toEqual({
      manufacturer: "ST2CY5...",
      name: "Aspirin",
      composition: "Acetylsalicylic acid 500mg",
      expiration: 2000n,
      productionDate: 500n,
      status: 0n,
      createdAt: 1000n,
      updatedAt: 1000n,
    });
    const log = mockContract.batchAuditLog.get("1-0");
    expect(log).toEqual({
      action: "batch-registered",
      actor: "ST2CY5...",
      timestamp: 1000n,
      metadata: "Initial batch registration",
    });
  });

  it("should prevent registration with invalid metadata", () => {
    const result = mockContract.registerBatch(
      "ST2CY5...",
      "",
      "Acetylsalicylic acid 500mg",
      2000n,
      500n
    );
    expect(result).toEqual({ error: 105 });
  });

  it("should update batch status", () => {
    mockContract.registerBatch("ST2CY5...", "Aspirin", "Acetylsalicylic acid 500mg", 2000n, 500n);
    const result = mockContract.updateBatchStatus("ST2CY5...", 1n, 1n);
    expect(result).toEqual({ value: true });
    const batch = mockContract.drugBatches.get("1");
    expect(batch?.status).toBe(1n);
    const log = mockContract.batchAuditLog.get("1-1");
    expect(log?.action).toBe("status-updated");
  });

  it("should prevent unauthorized status updates", () => {
    mockContract.registerBatch("ST2CY5...", "Aspirin", "Acetylsalicylic acid 500mg", 2000n, 500n);
    const result = mockContract.updateBatchStatus("ST3NB...", 1n, 1n);
    expect(result).toEqual({ error: 100 });
  });

  it("should recall a batch", () => {
    mockContract.registerBatch("ST2CY5...", "Aspirin", "Acetylsalicylic acid 500mg", 2000n, 500n);
    const result = mockContract.recallBatch("ST2CY5...", 1n, "Contamination detected");
    expect(result).toEqual({ value: true });
    const batch = mockContract.drugBatches.get("1");
    expect(batch?.status).toBe(4n);
    const log = mockContract.batchAuditLog.get("1-1");
    expect(log?.metadata).toBe("Contamination detected");
  });

  it("should prevent operations when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.registerBatch(
      "ST2CY5...",
      "Aspirin",
      "Acetylsalicylic acid 500mg",
      2000n,
      500n
    );
    expect(result).toEqual({ error: 104 });
  });

  it("should retrieve batch details", () => {
    mockContract.registerBatch("ST2CY5...", "Aspirin", "Acetylsalicylic acid 500mg", 2000n, 500n);
    const result = mockContract.getBatchDetails(1n);
    expect(result.value).toBeDefined();
    expect(result.value?.name).toBe("Aspirin");
  });

  it("should handle invalid batch ID", () => {
    const result = mockContract.getBatchDetails(999n);
    expect(result).toEqual({ error: 103 });
  });
});