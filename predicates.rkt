#lang racket/base
(require racket/contract racket/match racket/list xml racket/set)
(require (prefix-in html: "library/html.rkt"))
(require "world.rkt" "readability.rkt" "file-tools.rkt")

(module+ test (require rackunit))


(provide (all-defined-out)
         (all-from-out "file-tools.rkt"))



;; is it an xexpr tag?
(define/contract (xexpr-tag? x)
  (any/c . -> . boolean?)
  (symbol? x)) 

;; is it an xexpr attributes?
(define/contract (xexpr-attr? x)
  (any/c . -> . boolean?)
  (match x
    ; list of symbol + string pairs
    [(list (list (? symbol? key) (? string? value)) ...) #t]
    [else #f]))

(module+ test  
  (check-true (xexpr-attr? empty))
  (check-true (xexpr-attr? '((key "value"))))
  (check-true (xexpr-attr? '((key "value") (foo "bar"))))
  (check-false (xexpr-attr? '((key "value") "foo" "bar"))) ; content, not attr
  (check-false (xexpr-attr? '(key "value"))) ; not a nested list
  (check-false (xexpr-attr? '(("key" "value")))) ; two strings
  (check-false (xexpr-attr? '((key value))))) ; two symbols


;; is it xexpr content?
(define/contract (xexpr-element? x)
  (any/c . -> . boolean?)
  (or (string? x) (tagged-xexpr? x)))

;; Not a great idea to use "plural" (i.e. listlike) contracts.
;; Instead of foobars? use (listof foobar?) as contract
;; Reason is that listof will show you the specific element that fails
;; whereas foobars? will just announce the result for the whole list.
;; Since contracts are intended to tell you why your input is defective,
;; the (listof foobar?) behavior is better.
;; outside of contracts, instead of testing (foobars? list),
;; test (andmap foobar? list)

(define/contract (xexpr-elements? x)
  (any/c . -> . boolean?)
  (match x
    ;; this is more strict than xexpr definition in xml module
    ;; don't allow symbols or numbers to be part of content
    [(list elem ...) (andmap xexpr-element? elem)]
    [else #f]))

(module+ test  
  (check-true (xexpr-elements? '("p" "foo" "123")))
  (check-false (xexpr-elements? "foo")) ; not a list
  (check-false (xexpr-elements? '("p" "foo" 123))) ; includes number
  (check-false (xexpr-elements? '(p "foo" "123"))) ; includes symbol
  (check-false (xexpr-elements? '(((key "value")) "foo" "bar"))) ; includes attr
  (check-false (xexpr-elements? '("foo" "bar" ((key "value")))))) ; malformed


;; is it a named x-expression?
;; todo: rewrite this recurively so errors can be pinpointed (for debugging)
(define/contract (tagged-xexpr? x)
  (any/c . -> . boolean?)
  (and (xexpr? x) ; meets basic xexpr contract
       (match x
         [(list (? symbol? name) rest ...) ; is a list starting with a symbol
          (or (andmap xexpr-element? rest) ; the rest is content or ...
              (and (xexpr-attr? (car rest)) (andmap xexpr-element? (cdr rest))))] ; attr + content 
         [else #f])))

(module+ test  
  (check-true (tagged-xexpr? '(p "foo" "bar")))
  (check-true (tagged-xexpr? '(p ((key "value")) "foo" "bar")))
  (check-false (tagged-xexpr? "foo")) ; not a list with symbol
  (check-false (tagged-xexpr? '(p "foo" "bar" ((key "value"))))) ; malformed
  (check-false (tagged-xexpr? '("p" "foo" "bar"))) ; no name
  (check-false (tagged-xexpr? '(p 123)))) ; content is a number


;; test for well-formed meta
(define/contract (meta-xexpr? x)
  (any/c . -> . boolean?)
  (match x
    [`(meta ,(? string? key) ,(? string? value)) #t]
    [else #f]))

(module+ test
  (check-true (meta-xexpr? '(meta "key" "value")))
  (check-false (meta-xexpr? '(meta "key" "value" "foo")))
  (check-false (meta-xexpr? '(meta))))


;; initial set of block tags: from html
(define block-tags html:block-tags)

(define/contract (append-block-tag tag)
  (xexpr-tag? . -> . void?)
  (set! block-tags (cons tag block-tags)))

;; is the tagged-xexpr a block element (as opposed to inline)
;; tags are inline unless they're registered as block tags.
(define/contract (block-xexpr? x)
  (any/c . -> . boolean?)
  ;; (car x) = shorthand for tag of xexpr
  ((tagged-xexpr? x) . and . ((car x) . in? . block-tags)))

(module+ test
  (check-true (block-xexpr? '(p "foo")))
  (check-true (block-xexpr? '(div "foo")))
  (check-false (block-xexpr? '(em "foo")))
  (check-false (block-xexpr? '(barfoo "foo"))))


;; count incidence of elements in a list
;; returns hash where key is element, value is incidence
;; todo: move this? Ideally it would be in tools,
;; but that would create a circular dependency.
(define/contract (count-incidence x)
  (list? . -> . hash?)
  (define counter (make-hash))
  (for ([item (flatten x)]) 
    (hash-set! counter item (add1 (hash-ref counter item 0))))
  counter)

(module+ test
  (check-equal? (hash-ref (count-incidence '(a b c d b c)) 'b) 2)
  (check-equal? (hash-ref (count-incidence '(a b c d b c)) 'a) 1))

;; exploit uniqueness constraint of set data structure
(define/contract (elements-unique? x #:loud [loud #f])
  ((any/c) (#:loud boolean?) . ->* . boolean?)
  (define result 
    (cond 
      [(list? x) (= (len (apply set x)) (len x))]
      [(vector? x) (elements-unique? (->list x))]
      [(string? x) (elements-unique? (string->list x))]
      [else #t]))
  (if (and (not result) loud)
      (let* ([duplicate-keys (filter-not empty? (hash-map (count-incidence x) 
                                                          (λ(k v) (if (> v 1) k '()))))])
        (error (string-append (if (= (len duplicate-keys) 1) 
                                  "Item isn’t"
                                  "Items aren’t") " unique:") duplicate-keys))
      result))

(module+ test
  (check-true (elements-unique? '(1 2 3)))
  (check-false (elements-unique? '(1 2 2)))
  (check-true (elements-unique? (->vector '(1 2 3))))
  (check-false (elements-unique? (->vector '(1 2 2))))
  (check-true (elements-unique? "fob"))
  (check-false (elements-unique? "foo")))


;; certain ptree requirements are enforced at compile-time.
;; (such as pnodes must be valid strings, and unique.)
;; otherwise this becomes a rather expensive contract
;; because every function in ptree.rkt uses it.
;; note that a ptree is just a bunch of recursively nested ptrees.
(define/contract (ptree? x)
  (any/c . -> . boolean?)
  (and (match x
         ;; a tagged-xexpr with one attr ('parent)
         ;; whose subelements recursively meet the same test.
         [(list (? pnode? tag) (? ptree-attr? attr) elements ...) 
          (andmap ptree? elements)]
         [else #f])))

(module+ test
  (check-true (ptree? '(foo ((parent "bar")))))
  (check-false (ptree? '(foo)))
  (check-false (ptree? '(foo ((parent "bar")(hee "haw")))))
  (check-true (ptree? '(foo ((parent "bar")) (hee ((parent "foo"))))))
  (check-false (ptree? '(foo ((parent "bar")) (hee ((uncle "foo")))))))

;; ptree attr must be ((parent "value"))
(define/contract (ptree-attr? x)
  (any/c . -> . boolean?)
  (match x
    ;; todo: how can I use POLLEN_MAP_PARENT_KEY
    [`((parent ,(? string?))) #t]
    [else #f]))

(module+ test
  (check-true (ptree-attr? '((parent "bar"))))
  (check-false (ptree-attr? '((parent "bar") '(foo "bar"))))
  (check-false (ptree-attr? '())))


;; ptree location must represent a possible valid filename
(define/contract (pnode? x #:loud [loud #f])
  ((any/c) (#:loud boolean?) . ->* . boolean?)
  ;; todo: how to express the fact that the ptree-location must be 
  ;; a valid base name for a file?
  ;; however, don't restrict it to existing files 
  ;; (author may want to use ptree as wireframe)
  (define result 
    (or  (eq? x #f) ; OK for map-key to be #f
         (and (or (symbol? x) (string? x)) 
              ;; todo: should test be same as valid module name?
              (->boolean (regexp-match #px"^[-_A-Za-z0-9]+$" (->string x))))))
  (if (and (not result) loud)
      (error "Not a valid ptree key:" x)
      result))

(module+ test
  (check-true (pnode? #f))
  (check-true (pnode? "foo-bar"))
  (check-true (pnode? "Foo_Bar_0123"))
  (check-true (pnode? 'foo-bar))
  (check-false (pnode? "foo-bar.p"))
  (check-false (pnode? "/Users/MB/foo-bar"))
  (check-false (pnode? ""))
  (check-false (pnode? " ")))


;; recursive whitespace test
(define/contract (whitespace? x)
  (any/c . -> . boolean?)
  (cond
    [(or (vector? x) (list? x) (set? x)) (andmap whitespace? (->list x))]
    [(or (symbol? x) (string? x)) (->boolean (regexp-match #px"^\\s+$" (->string x)))]
    [else #f]))

(module+ test
  (check-true (whitespace? " "))
  (check-false (whitespace? "foo"))
  (check-false (whitespace? 'foo))
  (check-false (whitespace? #\Ø))
  (check-false (whitespace? " ")) ; a nonbreaking space. todo: why is this so?
  (check-true (whitespace? "\n \n"))
  (check-true (whitespace? (list "\n" " " "\n")))
  (check-true (whitespace? (list "\n" " " "\n" (list "\n" "\n")))))


