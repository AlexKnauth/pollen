#lang racket/base
(require racket/contract racket/list)
(require txexpr sugar "debug.rkt" "predicates.rkt" "world.rkt")
(provide (all-from-out "debug.rkt" "predicates.rkt" racket/list))

;; setup for test cases
(module+ test (require rackunit))


;; convert list of meta tags to a hash for export from pollen document.
;; every meta is form (meta "key" "value") (enforced by contract)
;; later metas with the same name will override earlier ones.
(define+provide/contract (make-meta-hash mxs)
  ((listof meta-xexpr?) . -> . hash?)
  (apply hash (append-map get-elements mxs)))

(module+ test
  (check-equal? (make-meta-hash '((meta "foo" "bar")(meta "hee" "haw")))
                (hash "foo" "bar" "hee" "haw"))
  (check-equal? (make-meta-hash '((meta "foo" "bar")(meta "foo" "haw")))
                (hash "foo" "haw")))



;; function to split tag out of txexpr
(define+provide/contract (split-tag-from-xexpr tag tx)
  (txexpr-tag? txexpr? . -> . (values (listof txexpr-element?) txexpr? ))
  (define matches '())
  (define (extract-tag x)
    (cond
      [(and (txexpr? x) (equal? tag (car x)))
       ; stash matched tag but return empty value
       (begin
         (set! matches (cons x matches))
         empty)]
      [(txexpr? x) (let-values([(tag attr body) (txexpr->values x)]) 
                           (make-txexpr tag attr (extract-tag body)))]
      [(txexpr-elements? x) (filter-not empty? (map extract-tag x))]
      [else x]))
  (define tx-extracted (extract-tag tx)) ;; do this first to fill matches
  (values (reverse matches) tx-extracted)) 


(module+ test
  (define xx '(root (meta "foo" "bar") "hello" "world" (meta "foo2" "bar2") 
                    (em "goodnight" "moon" (meta "foo3" "bar3"))))
  (check-equal? (call-with-values (λ() (split-tag-from-xexpr 'meta xx)) list) 
                (list '((meta "foo" "bar") (meta "foo2" "bar2") (meta "foo3" "bar3")) 
                      '(root "hello" "world" (em "goodnight" "moon")))))