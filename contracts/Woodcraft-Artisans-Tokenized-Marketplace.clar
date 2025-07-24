(define-non-fungible-token woodcraft-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-custom-order-not-found (err u105))
(define-constant err-invalid-royalty (err u106))

(define-data-var next-token-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-order-id uint u1)
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
