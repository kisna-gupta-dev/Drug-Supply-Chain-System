# 🧪 Drug Supply Chain using Smart Contracts

A secure, transparent, and decentralized drug supply chain system built on Ethereum smart contracts. The system ensures authenticity and traceability of pharmaceutical batches from **manufacturer → distributor → retailer**, and supports return/refund workflows, reselling, and frozen access management.

---

## 🚀 Features

- 🔐 **Role-based Access Control** (Manufacturer, Distributor, Retailer)
- 📦 **Batch Lifecycle Management**
  - Creation by Manufacturer
  - Purchase by Distributor
  - Sale to Retailer
- 🔄 **Return and Refund Workflow**
  - Return requests by Distributor/Retailer
  - Manual or Chainlink Keepers-based auto-approval
- 🔁 **Resell Functionality** for unsold or excess batches
- 📤 **QR Code Integration**
  - Decentralized data stored on IPFS
  - QR-based traceability
- ❄️ **Freeze/Unfreeze Accounts** by Admin
- 💸 **Overpayment Refund Logic**
- ⛓️ Fully deployed using **Solidity** and **OpenZeppelin Contracts**

---


## 🧱 Smart Contract Structure

- **Roles**
  - `MANUFACTURER_ROLE`
  - `DISTRIBUTOR_ROLE`
  - `RETAILER_ROLE`
- **Core Structs**
  - `Batch` – Batch details and metadata
  - `ReturnRequest` – Tracks return/refund requests
- **Mappings**
  - `batchIdToBatch` – Track batches
  - `returnRequests` – Return request data
  - `isFrozen` – Frozen status

---

## 📦 Functionality Breakdown

### 🔨 Admin:
- `addManufacturer()`, `addDistributor()`, `addRetailer()`
- `frozeAddress()`, `unfreezeAddress()`
- `removeManufacturer()`, `removeDistributor()`, `removeRetailer()`

### 🏭 Manufacturer:
- `createBatch()`

### 📦 Distributor:
- `buyBatchDistributor()`
- `eligibleToResell()`, `buyResellBatch()`
- `requestReturn()`

### 🛍 Retailer:
- `buyBatchRetailer()`
- `requestReturn()`

### 🔄 Return/Refund:
- `requestReturn()` – Request batch return
- `approveRequest()` – Approve refund request (or automated via Chainlink Keepers)

---

## 💡 How It Works

1. **Manufacturer** creates a batch and generates a QR code linked to IPFS-stored metadata.
2. **Distributor** buys the batch and sets resale price for retailers.
3. **Retailer** purchases the batch and gets full traceability.
4. If defective or unsold:
   - Return can be initiated and refunded
   - Reselling to another distributor is also possible

---

## 🔗 IPFS + QR Code

- Batch info like `drugName`, `expiryDate`, `MRP`, and `ownership history` is uploaded to IPFS.
- A **QR code** pointing to the IPFS link is generated and shared for scanning/validation.

---

## 🧪 Local Development

```bash
# 1. Clone Repo
git clone https://github.com/your-username/drug-supply-chain.git
cd drug-supply-chain

# 2. Install Dependencies
npm install

# 3. Compile Contracts
npx hardhat compile

# 4. Run Tests
npx hardhat test
