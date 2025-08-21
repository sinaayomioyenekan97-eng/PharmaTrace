;; Drug Registry Contract
;; Clarity v2
;; Manages registration, updates, and verification of pharmaceutical drug batches

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-BATCH-ID u101)
(define-constant ERR-BATCH-EXISTS u102)
(define-constant ERR-BATCH-NOT-FOUND u103)
(define-constant ERR-PAUSED u104)
(define-constant ERR-INVALID-METADATA u105)
(define-constant ERR-INVALID-STATUS u106)
(define-constant ERR-ZERO-ADDRESS u107)
(define-constant ERR-INVALID-TIMESTAMP u108)

;; Contract metadata
(define-constant CONTRACT-NAME "PharmaTrace Drug Registry")
(define-constant MAX-METADATA-LEN u256) ;; Max length for metadata strings

;; Batch status enum
(define-constant STATUS-PENDING u0)
(define-constant STATUS-MANUFACTURED u1)
(define-constant STATUS-DISTRIBUTED u2)
(define-constant STATUS-RETAILED u3)
(define-constant STATUS-RECALLED u4)

;; Admin and contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var batch-counter uint u0)

;; Data structures
(define-map drug-batches
  { batch-id: uint }
  {
    manufacturer: principal,
    name: (string-ascii 64),
    composition: (string-ascii 256),
    expiration: uint,
    production-date: uint,
    status: uint,
    created-at: uint,
    updated-at: uint
  }
)

(define-map batch-audit-log
  { batch-id: uint, log-index: uint }
  {
    action: (string-ascii 64),
    actor: principal,
    timestamp: uint,
    metadata: (string-ascii 256)
  }
)

(define-map audit-log-count
  { batch-id: uint }
  { log-count: uint }
)

;; Private helper: is-admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: ensure not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: validate metadata
(define-private (validate-metadata (metadata (string-ascii 256)))
  (and (> (len metadata) u0) (<= (len metadata) MAX-METADATA-LEN))
)

;; Private helper: validate status
(define-private (validate-status (status uint))
  (or (is-eq status STATUS-PENDING)
      (is-eq status STATUS-MANUFACTURED)
      (is-eq status STATUS-DISTRIBUTED)
      (is-eq status STATUS-RETAILED)
      (is-eq status STATUS-RECALLED))
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Pause/unpause the contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Register a new drug batch
(define-public (register-batch
  (name (string-ascii 64))
  (composition (string-ascii 256))
  (expiration uint)
  (production-date uint))
  (begin
    (ensure-not-paused)
    (asserts! (not (is-eq tx-sender 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (asserts! (validate-metadata name) (err ERR-INVALID-METADATA))
    (asserts! (validate-metadata composition) (err ERR-INVALID-METADATA))
    (asserts! (> expiration block-height) (err ERR-INVALID-TIMESTAMP))
    (asserts! (<= production-date block-height) (err ERR-INVALID-TIMESTAMP))
    (let
      ((batch-id (+ (var-get batch-counter) u1)))
      (asserts! (is-none (map-get? drug-batches { batch-id: batch-id })) (err ERR-BATCH-EXISTS))
      (map-set drug-batches
        { batch-id: batch-id }
        {
          manufacturer: tx-sender,
          name: name,
          composition: composition,
          expiration: expiration,
          production-date: production-date,
          status: STATUS-PENDING,
          created-at: block-height,
          updated-at: block-height
        }
      )
      (map-set batch-audit-log
        { batch-id: batch-id, log-index: u0 }
        {
          action: "batch-registered",
          actor: tx-sender,
          timestamp: block-height,
          metadata: "Initial batch registration"
        }
      )
      (map-set audit-log-count { batch-id: batch-id } { log-count: u1 })
      (var-set batch-counter batch-id)
      (ok batch-id)
    )
  )
)

;; Update batch status
(define-public (update-batch-status (batch-id uint) (new-status uint))
  (begin
    (ensure-not-paused)
    (asserts! (> batch-id u0) (err ERR-INVALID-BATCH-ID))
    (asserts! (validate-status new-status) (err ERR-INVALID-STATUS))
    (match (map-get? drug-batches { batch-id: batch-id })
      batch
      (begin
        (asserts! (is-eq tx-sender (get manufacturer batch)) (err ERR-NOT-AUTHORIZED))
        (asserts! (< new-status STATUS-RECALLED) (err ERR-INVALID-STATUS)) ;; Recall is a separate function
        (map-set drug-batches
          { batch-id: batch-id }
          (merge batch { status: new-status, updated-at: block-height })
        )
        (let
          ((current-log-count (default-to u0 (get log-count (map-get? audit-log-count { batch-id: batch-id })))))
          (map-set batch-audit-log
            { batch-id: batch-id, log-index: current-log-count }
            {
              action: "status-updated",
              actor: tx-sender,
              timestamp: block-height,
              metadata: (concat "Status changed to " (int-to-ascii new-status))
            }
          )
          (map-set audit-log-count { batch-id: batch-id } { log-count: (+ current-log-count u1) })
        )
        (ok true)
      )
      (err ERR-BATCH-NOT-FOUND)
    )
  )
)

;; Recall a batch
(define-public (recall-batch (batch-id uint) (reason (string-ascii 256)))
  (begin
    (ensure-not-paused)
    (asserts! (> batch-id u0) (err ERR-INVALID-BATCH-ID))
    (asserts! (validate-metadata reason) (err ERR-INVALID-METADATA))
    (match (map-get? drug-batches { batch-id: batch-id })
      batch
      (begin
        (asserts! (is-eq tx-sender (get manufacturer batch)) (err ERR-NOT-AUTHORIZED))
        (map-set drug-batches
          { batch-id: batch-id }
          (merge batch { status: STATUS-RECALLED, updated-at: block-height })
        )
        (let
          ((current-log-count (default-to u0 (get log-count (map-get? audit-log-count { batch-id: batch-id })))))
          (map-set batch-audit-log
            { batch-id: batch-id, log-index: current-log-count }
            {
              action: "batch-recalled",
              actor: tx-sender,
              timestamp: block-height,
              metadata: reason
            }
          )
          (map-set audit-log-count { batch-id: batch-id } { log-count: (+ current-log-count u1) })
        )
        (ok true)
      )
      (err ERR-BATCH-NOT-FOUND)
    )
  )
)

;; Private helper: get last log index
(define-private (get-last-log-index (batch-id uint))
  (default-to u0 (get log-count (map-get? audit-log-count { batch-id: batch-id })))
)

;; Read-only: get batch details
(define-read-only (get-batch-details (batch-id uint))
  (match (map-get? drug-batches { batch-id: batch-id })
    batch
    (ok batch)
    (err ERR-BATCH-NOT-FOUND)
  )
)

;; Read-only: get batch audit log
(define-read-only (get-audit-log (batch-id uint) (log-index uint))
  (match (map-get? batch-audit-log { batch-id: batch-id, log-index: log-index })
    log
    (ok log)
    (err ERR-BATCH-NOT-FOUND)
  )
)

;; Read-only: get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Read-only: get batch counter
(define-read-only (get-batch-counter)
  (ok (var-get batch-counter))
)