
;; title: Lottery Winner NFT Contract 
;; version:
;; summary:
;; description: A smart contract that allows the lottery winners to mint an NFT

;; traits
;;
(use-trait lottery-trait {
    get-lottery-winner: (fn (uint) (response principal uint)),
    get-lottery-prize: (fn (uint) (response uint uint))
})

(define-constant MAIN_LOTTERY_CONTRACT .lottery-contract)

;; SIP-009 NFT trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; token definitions
;;

;; constants
;;
(define-constant contract-owner tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u101))
(define-constant ERR_INVALID_TOKEN_ID (err u102))
(define-constant ERR_NOT_WINNER (err u103))
(define-constant ERR_ALREADY_MINTED (err u104))
(define-constant BASE_URI "https://api.lottery.example/winner/")

;; data vars
;;
(define-data-var last-token-id uint u0)
(define-data-var last-lottery-id uint u0)

;; data maps
;;
;; define map to store the winner tokens
(define-map tokens 
    uint  ;; token-id
    {
        owner: principal,
        token-uri: (string-utf8 256),
        lottery-id: uint,
        prize-amount: uint
    }
)

;; Track which lottery winners have minted
(define-map lottery-minted
    uint  ;; lottery-id
    bool  ;; minted status
)

;; public functions
;;
;; Mint NFT for lottery winner
(define-public (mint-winner-nft (lottery-id uint))
    (let 
        (
            (new-token-id (+ (var-get last-token-id) u1))
            (winner-info (unwrap! (contract-call? LOTTERY_CONTRACT get-lottery-winner lottery-id) ERR_NOT_AUTHORIZED))
            (prize-amount (unwrap! (contract-call? LOTTERY_CONTRACT get-lottery-prize lottery-id) ERR_NOT_AUTHORIZED))
        )
        ;; Check if caller is the winner
        (asserts! (is-eq tx-sender winner-info) ERR_NOT_WINNER)
        
        ;; Check if NFT was already minted for this lottery
        (asserts! (is-none (map-get? lottery-minted lottery-id)) ERR_ALREADY_MINTED)
        
        ;; Update token ID counter
        (var-set last-token-id new-token-id)
        (var-set last-lottery-id lottery-id)
        
        ;; Mark lottery as minted
        (map-set lottery-minted lottery-id true)
        
        ;; Store token information
        (map-set tokens new-token-id {
            owner: winner-info,
            token-uri: (generate-token-uri new-token-id lottery-id prize-amount),
            lottery-id: lottery-id,
            prize-amount: prize-amount
        })
        
        (ok new-token-id)
    )
)

;; Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let 
        ((token (unwrap! (map-get? tokens token-id) ERR_INVALID_TOKEN_ID)))
        ;; Make sure the sender owns the token
        (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get owner token) sender) ERR_NOT_AUTHORIZED)
        
        ;; Update token owner
        (map-set tokens token-id 
            (merge token { owner: recipient }))
            
        (ok true)
    )
)

;; private functions
;;

;; Read-only functions
