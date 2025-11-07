A decentralized NFT marketplace for authentic woodcraft artisans built on Stacks blockchain using Clarity smart contracts.

## 🎯 Problem Solved

Talented woodworkers struggle to access premium buyers and their crafts are often resold at huge markups with no value returning to them.

## ✨ Features

- 🎨 **NFT Minting**: Each woodcraft is minted as an NFT with comprehensive metadata
- 💰 **Built-in Royalties**: Artists earn from every resale automatically
- 🛒 **Direct Marketplace**: Buy and sell woodcraft NFTs directly
- 🤝 **Custom Orders**: Fund artisans for custom work via smart contracts
- 🗳️ **Artisan Spotlight**: Community voting system to highlight local artisans
- 💰 **NFT Collateralized Loans**: Borrow against your woodcraft NFTs with interest-based repayment
- 🏠 **NFT Rental System**: Rent out your woodcraft NFTs for temporary use with time-based access control

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet)
- Node.js and npm

### Installation

```bash
git clone <your-repo>
cd woodcraft-marketplace
clarinet check
npm install
npm test
```

## 📋 Contract Functions

### 🎨 Minting

```clarity
(mint-woodcraft recipient name description image-url location wood-source royalty-percent)
```

Mint a new woodcraft NFT with metadata including artist, location, and wood source.

### 🛒 Marketplace

```clarity
(list-for-sale token-id price)
(buy-woodcraft listing-id)
(cancel-listing listing-id)
```

List woodcraft for sale, purchase listings, or cancel your own listings.

### 🤝 Custom Orders

```clarity
(create-custom-order artisan description price deadline)
(complete-custom-order order-id)
```

Create custom work orders with escrow payments and completion tracking.

### 🗳️ Voting System

```clarity
(vote-for-artisan artisan)
(reset-weekly-votes)
```

Vote for your favorite artisans and track weekly spotlight rankings.

### 💰 NFT Loans

```clarity
(borrow-against-nft token-id loan-amount interest-rate duration-blocks)
(repay-loan loan-id)
(liquidate-loan loan-id)
```

Borrow STX against your woodcraft NFTs with interest-based repayment terms.

### 🏠 NFT Rental

```clarity
(list-for-rental token-id rental-price duration-blocks)
(rent-nft rental-id)
(return-nft rental-id)
```

List your woodcraft NFTs for rental, rent available NFTs, and return rented NFTs after the rental period.

## 📊 Read-Only Functions

- `get-token-metadata` - Get NFT metadata
- `get-listing` - Get marketplace listing details
- `get-custom-order` - Get custom order information
- `get-artisan-votes` - Get total votes for an artisan
- `get-weekly-votes` - Get weekly votes for spotlight
- `get-token-owner` - Get current token owner
- `get-loan` - Get loan details
- `get-next-loan-id` - Get next available loan ID
- `get-rental` - Get rental details
- `get-next-rental-id` - Get next available rental ID

## 💼 Usage Examples

### Mint Your First Woodcraft

```clarity
(contract-call? .woodcraft-marketplace mint-woodcraft
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  "Handcrafted Oak Table"
  "Beautiful dining table made from reclaimed oak"
  "https://example.com/image.jpg"
  "Portland, Oregon"
  "Reclaimed Oregon Oak"
  u500)
```

### List for Sale

```clarity
(contract-call? .woodcraft-marketplace list-for-sale u1 u1000000)
```

### Buy a Woodcraft

```clarity
(contract-call? .woodcraft-marketplace buy-woodcraft u1)
```

### Create Custom Order

```clarity
(contract-call? .woodcraft-marketplace create-custom-order
   'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
   "Custom cedar jewelry box with intricate carvings"
   u500000
   u144)
```

### Borrow Against NFT

```clarity
(contract-call? .woodcraft-marketplace borrow-against-nft u1 u1000000 u500 u1440)
```

Borrow 1,000,000 microSTX against NFT #1 with 5% interest over 1440 blocks (approximately 1 day).

### Rent an NFT

```clarity
(contract-call? .woodcraft-marketplace list-for-rental u1 u50000 u1440)
(contract-call? .woodcraft-marketplace rent-nft u1)
```

List NFT #1 for rental at 50,000 microSTX for 1440 blocks, then rent it.

## 🔧 Configuration

- **Platform Fee**: 2.5% (adjustable by contract owner)
- **Maximum Royalty**: 10%
- **Custom Order Deposit**: 50% upfront

## 🛡️ Security Features

- Owner-only administrative functions
- Royalty validation (max 10%)
- Secure escrow for custom orders
- Duplicate vote prevention
- NFT collateralized lending with interest calculation

## 🏗️ Project Structure

```
├── contracts/
│   └── Woodcraft-Artisans-Tokenized-Marketplace.clar
├── tests/
├── Clarinet.toml
└── README.md
```

## 🧪 Testing

```bash
npm test
```

## 📄 License

MIT License - Build the future of artisan marketplaces!

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Write tests for new features
4. Submit pull request

## 🌟 Roadmap

- [ ] IPFS integration for metadata
- [ ] Mobile app interface
- [ ] Multi-chain support
- [ ] Artisan verification system
- [ ] Batch minting capabilities
- [x] NFT collateralized loans
- [x] NFT rental system

---

*Empowering woodcraft artisans through blockchain technology* 🌲✨
