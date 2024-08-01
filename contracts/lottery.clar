;; title: STX Lottery
;; version: 1.2
;; summary: A lottery system using STX with multiple entry tickets
;; description: Users can buy tickets for 10 STX each. The draw occurs when 100 tickets are sold.

;; constants
(define-constant OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u101000))
(define-constant TICKET_PRICE u10000000) ;; 10 STX in microSTX
(define-constant TICKETS_PER_DRAW u100)
(define-constant ERR_CYCLE_INCOMPLETE (err u101001))
(define-constant ERR_NOT_WINNER (err u101002))
(define-constant ERR_DRAW_ALREADY_DONE (err u101003))

;; data vars
(define-data-var current-cycle uint u1)
(define-data-var tickets-sold uint u0)
(define-data-var lottery-pool uint u0)
(define-data-var winning-address (optional principal) none)
(define-data-var draw-done bool false)

;; data maps
(define-map participant-tickets 
  { cycle: uint, participant: principal } 
  uint
)

;; public functions
(define-public (buy-tickets (number-of-tickets uint))
  (let
    (
      (total-cost (* number-of-tickets TICKET_PRICE))
      (current-cycle-var (var-get current-cycle))
    )
    (asserts! (>= (stx-get-balance tx-sender) total-cost) (err u100)) ;; Ensure sender has enough STX
    (asserts! (< (var-get tickets-sold) TICKETS_PER_DRAW) (err u101)) ;; Ensure draw hasn't started
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    (map-set participant-tickets 
      { cycle: current-cycle-var, participant: tx-sender }
      (+ (default-to u0 (map-get? participant-tickets { cycle: current-cycle-var, participant: tx-sender })) number-of-tickets)
    )
    (var-set tickets-sold (+ (var-get tickets-sold) number-of-tickets))
    (var-set lottery-pool (+ (var-get lottery-pool) total-cost))
    (ok true)
  )
)


(define-public (claim-reward)
  (let
    (
      (winner (var-get winning-address))
    )
    (asserts! (var-get draw-done) ERR_CYCLE_INCOMPLETE)
    (asserts! (is-eq (some tx-sender) winner) ERR_NOT_WINNER)
    (let
      (
        (prize (var-get lottery-pool))
      )
      (var-set lottery-pool u0)
      (var-set winning-address none)
      (var-set current-cycle (+ (var-get current-cycle) u1))
      (var-set tickets-sold u0)
      (var-set draw-done false)
      (as-contract (stx-transfer? prize tx-sender tx-sender))
    )
  )
)

;; read only functions
(define-read-only (get-cycle-progress)
  (let
    (
      (tickets-sold-var (var-get tickets-sold))
    )
    (/ (* tickets-sold-var u100) TICKETS_PER_DRAW)
  )
)

(define-read-only (get-participant-tickets (participant principal))
  (default-to u0 (map-get? participant-tickets { cycle: (var-get current-cycle), participant: participant }))
)

(define-private (get-random)
  (let
    (
      (block-hash (unwrap-panic (get-block-info? id-header-hash (- block-height u1))))
    )
    (mod (string-to-uint256 block-hash) (var-get tickets-sold))
  )
)
;; private functions
(define-private (select-winner)
  (let
    (
      (random-ticket (get-random))
      (participants (map-to-list participant-tickets))
    )
    (find-winner random-ticket u0 participants)
  )
)

(define-private (find-winner (random-ticket uint) (acc uint) (participants (list 100 {key: {cycle: uint, participant: principal}, value: uint})))
  (match participants
    cons entry rest
      (let
        (
          (participant-tickets (get value entry))
          (new-acc (+ acc participant-tickets))
        )
        (if (> new-acc random-ticket)
          (get participant (get key entry))
          (find-winner random-ticket new-acc rest)
        )
      )
    (get participant (get key (unwrap! (element-at participants u0) tx-sender)))
  )
)

(define-public (perform-draw)
  (let
    (
      (tickets-sold-var (var-get tickets-sold))
    )
    (asserts! (is-eq tx-sender OWNER) ERR_UNAUTHORIZED)
    (asserts! (>= tickets-sold-var TICKETS_PER_DRAW) ERR_CYCLE_INCOMPLETE)
    (asserts! (not (var-get draw-done)) ERR_DRAW_ALREADY_DONE)
    (let
      (
        (winner (select-winner))
      )
      (var-set winning-address (some winner))
      (var-set draw-done true)
      (ok winner)
    )
  )
)
