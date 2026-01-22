(define-non-fungible-token woodcraft-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-custom-order-not-found (err u105))
(define-constant err-invalid-royalty (err u106))
(define-constant err-auction-not-found (err u107))
(define-constant err-auction-expired (err u108))
(define-constant err-bid-too-low (err u109))
(define-constant err-auction-not-expired (err u110))
(define-constant err-loan-not-found (err u111))
(define-constant err-loan-active (err u112))
(define-constant err-loan-expired (err u113))
(define-constant err-insufficient-collateral (err u114))

(define-data-var next-token-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-order-id uint u1)
(define-data-var next-auction-id uint u1)
(define-data-var platform-fee-percent uint u250)

(define-map token-metadata uint {
    artist: principal,
    name: (string-ascii 50),
    description: (string-ascii 500),
    image-url: (string-ascii 500),
    location: (string-ascii 100),
    wood-source: (string-ascii 100),
    creation-date: uint,
    royalty-percent: uint
})

(define-map marketplace-listings uint {
    token-id: uint,
    seller: principal,
    price: uint,
    active: bool
})

(define-map custom-orders uint {
    client: principal,
    artisan: principal,
    description: (string-ascii 500),
    price: uint,
    deposit-paid: uint,
    completed: bool,
    deadline: uint
})

(define-map artisan-votes {artisan: principal, voter: principal} bool)
(define-map artisan-vote-count principal uint)
(define-map weekly-votes principal uint)

(define-map auctions uint {
    token-id: uint,
    seller: principal,
    reserve-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    active: bool
})

(define-map auction-bids {auction-id: uint, bidder: principal} uint)

(define-map nft-loans uint {
    borrower: principal,
    token-id: uint,
    loan-amount: uint,
    interest-rate: uint,
    due-date: uint,
    repaid: bool
})

(define-data-var next-loan-id uint u1)

(define-public (mint-woodcraft
    (recipient principal)
    (name (string-ascii 50))
    (description (string-ascii 500))
    (image-url (string-ascii 500))
    (location (string-ascii 100))
    (wood-source (string-ascii 100))
    (royalty-percent uint))
    (let ((token-id (var-get next-token-id)))
        (asserts! (<= royalty-percent u1000) err-invalid-royalty)
        (try! (nft-mint? woodcraft-nft token-id recipient))
        (map-set token-metadata token-id {
            artist: tx-sender,
            name: name,
            description: description,
            image-url: image-url,
            location: location,
            wood-source: wood-source,
            creation-date: stacks-block-height,
            royalty-percent: royalty-percent
        })
        (var-set next-token-id (+ token-id u1))
        (ok token-id)))

(define-public (list-for-sale (token-id uint) (price uint))
    (let ((listing-id (var-get next-listing-id)))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? woodcraft-nft token-id)) err-not-token-owner)
        (map-set marketplace-listings listing-id {
            token-id: token-id,
            seller: tx-sender,
            price: price,
            active: true
        })
        (var-set next-listing-id (+ listing-id u1))
        (ok listing-id)))

(define-public (buy-woodcraft (listing-id uint))
    (let ((listing (unwrap! (map-get? marketplace-listings listing-id) err-listing-not-found))
          (token-id (get token-id listing))
          (seller (get seller listing))
          (price (get price listing))
          (metadata (unwrap! (map-get? token-metadata token-id) err-listing-not-found)))
        (asserts! (get active listing) err-listing-not-found)
        (let ((royalty-amount (/ (* price (get royalty-percent metadata)) u10000))
              (platform-fee (/ (* price (var-get platform-fee-percent)) u10000))
              (seller-amount (- price (+ royalty-amount platform-fee))))
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
            (try! (as-contract (stx-transfer? royalty-amount tx-sender (get artist metadata))))
            (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
            (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
            (try! (nft-transfer? woodcraft-nft token-id seller tx-sender))
            (map-set marketplace-listings listing-id (merge listing {active: false}))
            (ok token-id))))

(define-public (cancel-listing (listing-id uint))
    (let ((listing (unwrap! (map-get? marketplace-listings listing-id) err-listing-not-found)))
        (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
        (map-set marketplace-listings listing-id (merge listing {active: false}))
        (ok true)))

(define-public (create-custom-order 
    (artisan principal)
    (description (string-ascii 500))
    (price uint)
    (deadline uint))
    (let ((order-id (var-get next-order-id))
          (deposit (/ price u2)))
        (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
        (map-set custom-orders order-id {
            client: tx-sender,
            artisan: artisan,
            description: description,
            price: price,
            deposit-paid: deposit,
            completed: false,
            deadline: deadline
        })
        (var-set next-order-id (+ order-id u1))
        (ok order-id)))

(define-public (complete-custom-order (order-id uint))
    (let ((order (unwrap! (map-get? custom-orders order-id) err-custom-order-not-found)))
        (asserts! (is-eq tx-sender (get artisan order)) err-not-token-owner)
        (asserts! (not (get completed order)) err-custom-order-not-found)
        (let ((remaining-payment (- (get price order) (get deposit-paid order))))
            (try! (as-contract (stx-transfer? (get deposit-paid order) tx-sender (get artisan order))))
            (try! (stx-transfer? remaining-payment (get client order) (as-contract tx-sender)))
            (try! (as-contract (stx-transfer? remaining-payment tx-sender (get artisan order))))
            (map-set custom-orders order-id (merge order {completed: true}))
            (ok true))))

(define-public (vote-for-artisan (artisan principal))
    (let ((vote-key {artisan: artisan, voter: tx-sender}))
        (asserts! (is-none (map-get? artisan-votes vote-key)) err-already-voted)
        (map-set artisan-votes vote-key true)
        (map-set artisan-vote-count artisan 
            (+ (default-to u0 (map-get? artisan-vote-count artisan)) u1))
        (map-set weekly-votes artisan 
            (+ (default-to u0 (map-get? weekly-votes artisan)) u1))
        (ok true)))

(define-public (reset-weekly-votes)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)))

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u1000) err-invalid-royalty)
        (var-set platform-fee-percent new-fee)
        (ok true)))

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id))

(define-read-only (get-listing (listing-id uint))
    (map-get? marketplace-listings listing-id))

(define-read-only (get-custom-order (order-id uint))
    (map-get? custom-orders order-id))

(define-read-only (get-artisan-votes (artisan principal))
    (default-to u0 (map-get? artisan-vote-count artisan)))

(define-read-only (get-weekly-votes (artisan principal))
    (default-to u0 (map-get? weekly-votes artisan)))

(define-read-only (get-platform-fee)
    (var-get platform-fee-percent))

(define-read-only (get-next-token-id)
    (var-get next-token-id))

(define-read-only (get-next-listing-id)
    (var-get next-listing-id))

(define-read-only (get-next-order-id)
    (var-get next-order-id))

(define-read-only (get-token-owner (token-id uint))
    (nft-get-owner? woodcraft-nft token-id))

(define-read-only (has-voted (artisan principal) (voter principal))
    (is-some (map-get? artisan-votes {artisan: artisan, voter: voter})))

(define-public (start-auction (token-id uint) (reserve-price uint) (duration-blocks uint))
    (let ((auction-id (var-get next-auction-id)))
        (asserts! (is-eq (some tx-sender) (nft-get-owner? woodcraft-nft token-id)) err-not-token-owner)
        (map-set auctions auction-id {
            token-id: token-id,
            seller: tx-sender,
            reserve-price: reserve-price,
            highest-bid: u0,
            highest-bidder: none,
            end-block: (+ stacks-block-height duration-blocks),
            active: true
        })
        (var-set next-auction-id (+ auction-id u1))
        (ok auction-id)))

(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let ((auction (unwrap! (map-get? auctions auction-id) err-auction-not-found)))
        (asserts! (get active auction) err-auction-not-found)
        (asserts! (< stacks-block-height (get end-block auction)) err-auction-expired)
        (asserts! (> bid-amount (get highest-bid auction)) err-bid-too-low)
        (asserts! (>= bid-amount (get reserve-price auction)) err-bid-too-low)
        (let ((previous-bidder (get highest-bidder auction))
              (previous-bid (get highest-bid auction)))
            (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
            (match previous-bidder
                bidder (try! (as-contract (stx-transfer? previous-bid tx-sender bidder)))
                true)
            (map-set auction-bids {auction-id: auction-id, bidder: tx-sender} bid-amount)
            (map-set auctions auction-id (merge auction {
                highest-bid: bid-amount,
                highest-bidder: (some tx-sender)
            }))
            (ok true))))

(define-public (finalize-auction (auction-id uint))
    (let ((auction (unwrap! (map-get? auctions auction-id) err-auction-not-found))
          (token-id (get token-id auction))
          (seller (get seller auction))
          (highest-bid (get highest-bid auction))
          (metadata (unwrap! (map-get? token-metadata token-id) err-auction-not-found)))
        (asserts! (get active auction) err-auction-not-found)
        (asserts! (>= stacks-block-height (get end-block auction)) err-auction-not-expired)
        (match (get highest-bidder auction)
            winner (let ((royalty-amount (/ (* highest-bid (get royalty-percent metadata)) u10000))
                        (platform-fee (/ (* highest-bid (var-get platform-fee-percent)) u10000))
                        (seller-amount (- highest-bid (+ royalty-amount platform-fee))))
                       (try! (as-contract (stx-transfer? royalty-amount tx-sender (get artist metadata))))
                       (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
                       (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
                       (try! (nft-transfer? woodcraft-nft token-id seller winner))
                       (map-set auctions auction-id (merge auction {active: false}))
                       (ok (some winner)))
            (begin
                (map-set auctions auction-id (merge auction {active: false}))
                (ok none)))))

(define-public (cancel-auction (auction-id uint))
    (let ((auction (unwrap! (map-get? auctions auction-id) err-auction-not-found)))
        (asserts! (is-eq tx-sender (get seller auction)) err-not-token-owner)
        (asserts! (get active auction) err-auction-not-found)
        (asserts! (is-eq (get highest-bid auction) u0) err-auction-not-found)
        (map-set auctions auction-id (merge auction {active: false}))
        (ok true)))

(define-read-only (get-auction (auction-id uint))
    (map-get? auctions auction-id))

(define-read-only (get-auction-bid (auction-id uint) (bidder principal))
    (map-get? auction-bids {auction-id: auction-id, bidder: bidder}))

(define-read-only (get-next-auction-id)
    (var-get next-auction-id))

(define-public (burn-woodcraft (token-id uint))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? woodcraft-nft token-id)) err-not-token-owner)
    (try! (nft-burn? woodcraft-nft token-id tx-sender))
    (map-delete token-metadata token-id)
    (ok true)))

(define-public (borrow-against-nft (token-id uint) (loan-amount uint) (interest-rate uint) (duration-blocks uint))
  (let ((loan-id (var-get next-loan-id)))
    (asserts! (is-eq (some tx-sender) (nft-get-owner? woodcraft-nft token-id)) err-not-token-owner)
    (asserts! (> loan-amount u0) err-insufficient-funds)
    (asserts! (<= interest-rate u1000) err-invalid-royalty)
    (try! (nft-transfer? woodcraft-nft token-id tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? loan-amount tx-sender tx-sender)))
    (map-set nft-loans loan-id {
      borrower: tx-sender,
      token-id: token-id,
      loan-amount: loan-amount,
      interest-rate: interest-rate,
      due-date: (+ stacks-block-height duration-blocks),
      repaid: false
    })
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)))

(define-public (repay-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? nft-loans loan-id) err-loan-not-found))
        (interest-amount (/ (* (get loan-amount loan) (get interest-rate loan)) u10000))
        (total-repayment (+ (get loan-amount loan) interest-amount)))
    (asserts! (is-eq tx-sender (get borrower loan)) err-not-token-owner)
    (asserts! (not (get repaid loan)) err-loan-active)
    (asserts! (<= stacks-block-height (get due-date loan)) err-loan-expired)
    (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
    (try! (as-contract (nft-transfer? woodcraft-nft (get token-id loan) tx-sender (get borrower loan))))
    (map-set nft-loans loan-id (merge loan {repaid: true}))
    (ok true)))

(define-public (liquidate-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? nft-loans loan-id) err-loan-not-found)))
    (asserts! (> stacks-block-height (get due-date loan)) err-auction-expired)
    (asserts! (not (get repaid loan)) err-loan-active)
    (map-set nft-loans loan-id (merge loan {repaid: true}))
    (ok true)))

(define-read-only (get-loan (loan-id uint))
  (map-get? nft-loans loan-id))

(define-read-only (get-next-loan-id)
  (var-get next-loan-id))

(define-data-var next-rental-id uint u1)

(define-data-var reward-rate uint u1)

(define-map staked-nfts uint {
  token-id: uint,
  owner: principal,
  stake-time: uint,
  accumulated-rewards: uint
})

(define-map nft-rentals uint {
  token-id: uint,
  owner: principal,
  renter: (optional principal),
  rental-price: uint,
  duration-blocks: uint,
  start-block: (optional uint),
  active: bool
})

(define-public (list-for-rental (token-id uint) (rental-price uint) (duration-blocks uint))
  (let ((rental-id (var-get next-rental-id)))
    (asserts! (is-eq (some tx-sender) (nft-get-owner? woodcraft-nft token-id)) err-not-token-owner)
    (map-set nft-rentals rental-id {
      token-id: token-id,
      owner: tx-sender,
      renter: none,
      rental-price: rental-price,
      duration-blocks: duration-blocks,
      start-block: none,
      active: true
    })
    (var-set next-rental-id (+ rental-id u1))
    (ok rental-id)))

(define-public (rent-nft (rental-id uint))
  (let ((rental (unwrap! (map-get? nft-rentals rental-id) err-listing-not-found)))
    (asserts! (get active rental) err-listing-not-found)
    (asserts! (is-none (get renter rental)) err-listing-not-found)
    (try! (stx-transfer? (get rental-price rental) tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? (get rental-price rental) tx-sender (get owner rental))))
    (try! (nft-transfer? woodcraft-nft (get token-id rental) (get owner rental) tx-sender))
    (map-set nft-rentals rental-id (merge rental {
      renter: (some tx-sender),
      start-block: (some stacks-block-height),
      active: false
    }))
    (ok true)))

(define-public (return-nft (rental-id uint))
  (let ((rental (unwrap! (map-get? nft-rentals rental-id) err-listing-not-found)))
    (asserts! (is-eq tx-sender (unwrap! (get renter rental) err-not-token-owner)) err-not-token-owner)
    (asserts! (>= stacks-block-height (+ (unwrap! (get start-block rental) err-listing-not-found) (get duration-blocks rental))) err-auction-not-expired)
    (try! (nft-transfer? woodcraft-nft (get token-id rental) tx-sender (get owner rental)))
    (map-set nft-rentals rental-id (merge rental {renter: none, start-block: none, active: true}))
    (ok true)))

(define-read-only (get-rental (rental-id uint))
  (map-get? nft-rentals rental-id))

(define-read-only (get-next-rental-id)
  (var-get next-rental-id))
