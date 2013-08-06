#lang racket/base
(require racket/contract)
(require (only-in racket/list empty? range))
(require (only-in racket/format ~a))
(require (only-in racket/string string-join))
(require (only-in racket/vector vector-member))
(module+ test (require rackunit))
(require "debug.rkt")

(provide (all-defined-out))

;; general way of coercing to string
(define/contract (as-string x)
  (any/c . -> . string?)
  (cond 
    [(string? x) x]
    [(empty? x) ""]
    [(symbol? x) (symbol->string x)]
    [(number? x) (number->string x)]
    [(path? x) (path->string x)]
    [(char? x) (~a x)]
    [else (error (format "Can't make ~a into string" x))]))

(module+ test
  (check-equal? (as-string "foo") "foo")
  (check-equal? (as-string '()) "")
  (check-equal? (as-string 'foo) "foo")
  (check-equal? (as-string 123) "123")
  (define file-name-as-text "foo.txt")
  (check-equal? (as-string (string->path file-name-as-text)) file-name-as-text)
  (check-equal? (as-string #\¶) "¶"))


;; general way of coercing to symbol
(define (as-symbol thing)
  ; todo: on bad input, it will pop a string error rather than symbol error
  (string->symbol (as-string thing))) 


;; general way of coercing to a list
(define (as-list x)
  (any/c . -> . list?)
  (cond 
    [(list? x) x]
    [(vector? x) (vector->list x)]
    [else (list x)])) 

(module+ test
  (check-equal? (as-list '(1 2 3)) '(1 2 3))
  (check-equal? (as-list (list->vector '(1 2 3))) '(1 2 3))
  (check-equal? (as-list "foo") (list "foo")))


;; general way of coercing to boolean
(define (as-boolean x)
  (any/c . -> . boolean?)
  ;; in Racket, everything but #f is true
  (if x #t #f))

(module+ test
  (check-true (as-boolean #t))
  (check-false (as-boolean #f))
  (check-true (as-boolean "#f")) 
  (check-true (as-boolean "foo"))
  (check-true (as-boolean '()))
  (check-true (as-boolean '(1 2 3))))



;; general way of asking for length
(define (len x)
  (any/c . -> . integer?)
  (cond
    [(list? x) (length x)]
    [(string? x) (string-length x)]
    [(symbol? x) (len (as-string x))]
    [(vector? x) (vector-length x)]
    [(hash? x) (len (hash-keys x))]
    [else #f]))

(module+ test
  (check-equal? (len '(1 2 3)) 3)
  (check-not-equal? (len '(1 2)) 3) ; len 2
  (check-equal? (len "foo") 3)
  (check-not-equal? (len "fo") 3) ; len 2
  (check-equal? (len 'foo) 3)
  (check-not-equal? (len 'fo) 3) ; len 2
  (check-equal? (len (list->vector '(1 2 3))) 3)
  (check-not-equal? (len (list->vector '(1 2))) 3) ; len 2
  (check-equal? (len (make-hash '((a . 1) (b . 2) (c . 3)))) 3)
  (check-not-equal? (len (make-hash '((a . 1) (b . 2)))) 3)) ; len 2



;; general way of fetching an item from a container
(define/contract (get container item [up-to #f])
  ((any/c any/c) ((λ(i)(or (integer? i) (and (symbol? i) (equal? i 'end))))) 
                 . ->* . any/c)
  
  (define (sliceable-container? container)
    (ormap (λ(proc) (proc container)) (list list? string? vector?)))
  
  (when (sliceable-container? container)
    (set! up-to
          (cond 
            ;; treat negative lengths as offset from end (Python style)
            [(and (integer? up-to) (< up-to 0)) (+ (len container) up-to)]
            ;; 'end slices to the end
            [(equal? up-to 'end) (len container)]
            ;; default to slice length of 1 (i.e, single-item retrieval)
            [(equal? up-to #f) (add1 item)]
            [else up-to])))
  
  (define result (cond
                   ;; for sliceable containers, make a slice
                   [(list? container) (for/list ([i (range item up-to)]) 
                                        (list-ref container i))]
                   [(vector? container) (for/vector ([i (range item up-to)])
                                          (vector-ref container i))] 
                   [(string? container) (substring container item up-to)]
                   [(symbol? container) (as-symbol (get (as-string container) item up-to))] 
                   ;; for hash, just get item
                   [(hash? container) (hash-ref container item)]
                   [else #f]))
  
  ;; don't return single-item results inside a list
  (if (and (sliceable-container? result) (= (len result) 1))
      (car (as-list result))
      result))

(module+ test
  (check-equal? (get '(0 1 2 3 4 5) 2) 2)
  (check-equal? (get '(0 1 2 3 4 5) 0 2) '(0 1))
  (check-equal? (get '(0 1 2 3 4 5) 2 -1) '(2 3 4))
  (check-equal? (get '(0 1 2 3 4 5) 2 'end) '(2 3 4 5))
  (check-equal? (get (list->vector '(0 1 2 3 4 5)) 2) 2)
  (check-equal? (get (list->vector'(0 1 2 3 4 5)) 0 2) (list->vector '(0 1)))
  (check-equal? (get (list->vector'(0 1 2 3 4 5)) 2 -1) (list->vector '(2 3 4)))
  (check-equal? (get (list->vector'(0 1 2 3 4 5)) 2 'end) (list->vector '(2 3 4 5)))
  (check-equal? (get "purple" 2) "r")
  (check-equal? (get "purple" 0 2) "pu")
  (check-equal? (get "purple" 2 -1) "rpl")
  (check-equal? (get "purple" 2 'end) "rple")
  (check-equal? (get 'purple 2) 'r)
  (check-equal? (get 'purple 0 2) 'pu)
  (check-equal? (get 'purple 2 -1) 'rpl)
  (check-equal? (get 'purple 2 'end) 'rple)
  (check-equal? (get (make-hash '((a . 1) (b . 2) (c  . 3))) 'a) 1))

;; general way of testing for membership (à la Python 'in')
(define/contract (in container item)
  (any/c any/c . -> . any/c)
  (cond
    [(list? container) (member item container)] ; returns #f or sublist beginning with item
    [(vector? container) (vector-member item container)] ; returns #f or zero-based item index
    [(hash? container) 
     (and (hash-has-key? container item) (get container item))] ; returns #f or hash value
    [(string? container) (let ([result (in (map as-string (string->list container)) (as-string item))])
                           (if result
                               (string-join result "")
                               #f))] ; returns #f or substring beginning with item
    [(symbol? container) (let ([result (in (as-string container) (as-string item))])
                           (if result
                               (as-symbol result)
                               result))] ; returns #f or subsymbol (?!) beginning with item
    [else #f]))

(module+ test
  (check-equal? (in '(1 2 3) 2) '(2 3))
  (check-false (in '(1 2 3) 4))
  (check-equal? (in (list->vector '(1 2 3)) 2) 1)
  (check-false (in (list->vector '(1 2 3)) 4))
  (check-equal? (in (make-hash '((a . 1) (b . 2) (c  . 3))) 'a) 1)
  (check-false (in (make-hash '((a . 1) (b . 2) (c  . 3))) 'x))
  (check-equal? (in "foobar" "o") "oobar")
  (check-false (in "foobar" "z"))
  (check-equal? (in 'foobar 'o) 'oobar)
  (check-false (in 'foobar 'z))
  (check-false (in #\F "F")))