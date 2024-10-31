
;; title: lottery contract on stacks blockchain
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
(define-constant ERR_INVALID_DURATION (err u106))
(define-constant ERR_INVALID_PARTICIPANT_LIMIT (err u107))
(define-constant ERR_LOTTERY_IN_PROGRESS (err u108))
(define-constant ERR_INVALID_LOTTERY_ID (err u109))

;; data vars
;;
(define-data-var ticket-price uint u1000000)
(define-data-var lottery-end-condition uint u0) ;; 0 for time based, 1 for participant based
(define-data-var lottery-end-block uint u0)
(define-data-var participants (list 100 principal) (list))
(define-data-var lottery-type (string-ascii 20) "time-based")
(define-data-var current-lottery-id uint u0)


;; data maps
;;
;; Store lottery results with round information
(define-map lottery-history uint {
    winner: principal,
    prize-amount: uint,
    participant-count: uint,
    end-block: uint,
    lottery-type: (string-ascii 20)
})

;; public functions
;;
(define-public (start-lottery (duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_OWNER_ONLY)
        (asserts! (is-eq (var-get lottery-type) "none") ERR_LOTTERY_IN_PROGRESS)
        (asserts! (and (> duration u0) (<= duration u10000)) ERR_INVALID_DURATION)
        (var-set lottery-type "time-based")
        (var-set lottery-end-condition u0)
        (var-set lottery-end-block (+ block-height duration))
        (var-set participants (list))
        (var-set current-lottery-id (+ (var-get current-lottery-id) u1))
        (ok true)
    )
)

;; function to start a participant based lottery
(define-public (start-participant-lottery (participant-limit uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR_OWNER_ONLY)
        (asserts! (is-eq (var-get lottery-type) "none") ERR_LOTTERY_IN_PROGRESS)
        (asserts! (and (> participant-limit u0) (<= participant-limit u100)) ERR_INVALID_PARTICIPANT_LIMIT)
        (var-set lottery-type "participant-based")
        (var-set lottery-end-condition participant-limit)
        (var-set lottery-end-block u0)
        (var-set participants (list))
        (var-set current-lottery-id (+ (var-get current-lottery-id) u1))
        (ok true)
    )
)

;; function to buy a ticket
(define-public (buy-ticket)
    (let 
        (
            (caller tx-sender)
            (current-participants (var-get participants))
        )
        (asserts! (not (is-eq (var-get lottery-type) "none")) ERR_LOTTERY_NOT_ENDED)
        (asserts!
            (if 
                (is-eq (var-get lottery-type) "time-based")
                (< block-height (var-get lottery-end-block))
                (<= (+ (len current-participants) u1) (var-get lottery-end-condition))
            )
            ERR_LOTTERY_ENDED
        )
        (asserts! (is-eq (stx-transfer? (var-get ticket-price) caller (as-contract tx-sender)) (ok true)) ERR_NOT_ENOUGH_FUNDS)
        (var-set participants (unwrap! (as-max-len? (append current-participants caller) u100) ERR_LOTTERY_ENDED))
        (ok true)
    )
)

;; function to draw a winner
(define-public (draw-winner)
    (let
        (
            (participants-list (var-get participants))
            (participants-count (len participants-list))
            (current-id (var-get current-lottery-id))
        )
        (asserts!
            (if
                (is-eq (var-get lottery-type) "time-based")
                (>= block-height (var-get lottery-end-block))
                (>= participants-count (var-get lottery-end-condition))
            )
            ERR_LOTTERY_NOT_ENDED
        )
        (asserts! (> participants-count u0) ERR_NO_PARTICIPANTS)
        (let
            (
                (seed (unwrap! (get-block-info? time (- block-height u1)) ERR_FAILED_TO_GET_BLOCK_INFO))
                (winner (unwrap-panic (element-at participants-list (mod seed participants-count))))
                (prize (stx-get-balance (as-contract tx-sender)))
            )
            ;; Store lottery results before transferring prize
            (map-set lottery-history current-id {
                winner: winner,
                prize-amount: prize,
                participant-count: participants-count,
                end-block: block-height,
                lottery-type: (var-get lottery-type)
            })

            (try! (as-contract (stx-transfer? prize tx-sender winner)))
            (var-set participants (list))
            (var-set lottery-type "none")
            (ok winner)
        )
    )
    
)

;; function for owner to withdraw funds
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

(define-read-only (get-lottery-type)
    (var-get lottery-type)
)

(define-read-only (get-lottery-end-condition)
    (var-get lottery-end-condition)
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

(define-read-only (get-current-lottery-id)
    (var-get current-lottery-id)
)

;; Get information about a specific lottery round
(define-read-only (get-lottery-info (lottery-id uint))
    (map-get? lottery-history lottery-id)
)

;; New function to get winner of a specific lottery
(define-read-only (get-lottery-winner (lottery-id uint))
    (let 
        (
            (lottery-data (map-get? lottery-history lottery-id))
        )
        (if (is-some lottery-data)
            (ok (get winner (unwrap-panic lottery-data)))
            ERR_INVALID_LOTTERY_ID
        )
    )
)

;; New function to get detailed winner information of a specific lottery
(define-read-only (get-lottery-winner-info (lottery-id uint))
    (let 
        (
            (lottery-data (map-get? lottery-history lottery-id))
        )
        (if (is-some lottery-data)
            (ok {
                winner: (get winner (unwrap-panic lottery-data)),
                prize: (get prize-amount (unwrap-panic lottery-data)),
                lottery-type: (get lottery-type (unwrap-panic lottery-data)),
                end-block: (get end-block (unwrap-panic lottery-data))
            })
            ERR_INVALID_LOTTERY_ID
        )
    )
)

;; private functions
;;

