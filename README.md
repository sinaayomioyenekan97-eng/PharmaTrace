# PharmaTrace

A blockchain-powered platform for enhancing transparency, authenticity, and traceability in the pharmaceutical supply chain, combating drug counterfeiting and ensuring patient safety — all on-chain.

---

## Overview

PharmaTrace consists of five main smart contracts that together form a decentralized, transparent, and secure ecosystem for pharmaceutical manufacturers, distributors, pharmacies, and patients:

1. **Drug Registry Contract** – Registers and manages unique drug batches with immutable metadata.
2. **Supply Chain Tracker Contract** – Tracks the movement of drugs through the supply chain with verifiable logs.
3. **Authenticity Verifier Contract** – Enables verification of drug authenticity via QR codes or NFC scans.
4. **Stakeholder Access Contract** – Manages permissions and roles for different participants in the ecosystem.
5. **Oracle Integration Contract** – Connects with off-chain data sources for real-time updates and verifications.

---

## Features

- **Immutable drug registration** for batch details and provenance  
- **Real-time supply chain tracking** from manufacturer to end-user  
- **Instant authenticity checks** for patients and pharmacies  
- **Role-based access control** to ensure data privacy and security  
- **Oracle-fed updates** for environmental conditions and regulatory compliance  

---

## Smart Contracts

### Drug Registry Contract
- Register new drug batches with details like manufacturer, expiration, and composition
- Immutable storage of batch metadata
- Query functions for batch history and status

### Supply Chain Tracker Contract
- Log transfers between stakeholders (e.g., manufacturer to distributor)
- Enforce chain-of-custody rules to prevent unauthorized handling
- Event emissions for each transfer to enable off-chain monitoring

### Authenticity Verifier Contract
- Generate unique verification codes for each batch
- Verify authenticity through on-chain checks against registry data
- Anti-counterfeit mechanisms like one-time use verifications

### Stakeholder Access Contract
- Assign roles (e.g., manufacturer, distributor, patient) with specific permissions
- Manage access to sensitive data via cryptographic proofs
- Revocation and update functions for roles

### Oracle Integration Contract
- Secure integration with external oracles for data like temperature logs or regulatory approvals
- Trigger on-chain updates based on off-chain events
- Validation mechanisms to ensure oracle data integrity

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started)
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/pharmatrace.git
   ```
3. Run tests:
    ```bash
    npm test
    ```
4. Deploy contracts:
    ```bash
    clarinet deploy
    ```

## Usage

Each smart contract operates independently but integrates with others for a complete pharmaceutical traceability experience.
Refer to individual contract documentation for function calls, parameters, and usage examples.

## License

MIT License