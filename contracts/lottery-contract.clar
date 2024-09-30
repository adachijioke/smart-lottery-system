
;; title: lottery contract for stacks
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant contract-owner tx-sender)
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_ENOUGH_FUNDS (err u101))
(define-constant ERR_LOTTERY_ENDED (err u102))
(define-constant ERR_LOTTERY_NOT_ENDED (err u103))
(define-constant ERR_NO_PARTICIPANTS (err u104))
(define-constant ERR_FAILED_TO_GET_BLOCK_INFO (err u105))

;; data vars
;;
(define-data-var ticket-price uint u1000000)
(define-data-var lottery-end-block uint u0)
(define-data-var participants (list 100 principal) (list))

;; data maps
;;

;; public functions
;;
(define-public (start-lottery (duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_OWNER_ONLY)
        (var-set lottery-end-block (+ block-height duration))
        (ok true)
    )
)

(define-public (buy-ticket)
    (let ((caller tx-sender))
        (asserts! (< block-height (var-get lottery-end-block)) ERR_LOTTERY_ENDED)
        (asserts! (is-eq (stx-transfer? (var-get ticket-price) caller (as-contract tx-sender)) (ok true)) ERR_NOT_ENOUGH_FUNDS)
        (var-set participants (unwrap! (as-max-len? (append (var-get participants) caller) u100) ERR_LOTTERY_ENDED))
        (ok true)
    )
)

(define-public (draw-winner)
    (let
        (
            (participants-list (var-get participants))
            (participants-count (len participants-list))
        )
        (asserts! (>= block-height (var-get lottery-end-block)) ERR_LOTTERY_NOT_ENDED)
        (asserts! (> participants-count u0) ERR_NO_PARTICIPANTS)

        (let
            (   
                (seed (unwrap! (get-block-info? time (- block-height u1)) ERR_FAILED_TO_GET_BLOCK_INFO))
                (winner (unwrap-panic (element-at participants-list (mod seed participants-count))))
                (prize (stx-get-balance (as-contract tx-sender)))
            )
            (try! (as-contract (stx-transfer? prize tx-sender winner)))
            (var-set participants (list))
            (var-set lottery-end-block (+ block-height u144))
            (ok winner)
        )
    )
    
)

(define-public (withdraw-funds)
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_OWNER_ONLY)
        (as-contract (stx-transfer? (stx-get-balance (as-contract tx-sender)) tx-sender contract-owner))
    )
)

;; read only functions
;;
(define-read-only (get-ticket-price)
    (var-get ticket-price)
)

(define-read-only (get-lottery-end-block)
    (var-get lottery-end-block)
)

(define-read-only (get-participants) 
    (var-get participants)
)

(define-read-only (get-balance)
    (stx-get-balance (as-contract tx-sender))
)

;; private functions
;;

