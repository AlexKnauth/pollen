#lang racket/base
(require "readability.rkt")
(require racket/contract racket/match)
(require (only-in racket/path filename-extension))
(require (only-in racket/format ~a))
(require (only-in xml xexpr?))
(provide (all-defined-out))

;; setup for test cases
(module+ test
  (require rackunit)
  (define foo-path-strings '("foo" "foo.txt" "foo.bar" "foo.bar.txt"))
  (define-values (foo-path foo.txt-path foo.bar-path foo.bar.txt-path) (apply values (map string->path foo-path-strings)))
  ;; test the sample paths before using them for other tests
  (define foo-paths (list foo-path foo.txt-path foo.bar-path foo.bar.txt-path))
  (for-each check-equal? (map path->string foo-paths) foo-path-strings))


;; does path have a certain extension
(define/contract (has-ext? path ext)
  (path? symbol? . -> . boolean?)
  (define ext-of-path (filename-extension path))
  (and ext-of-path (equal? (bytes->string/utf-8 ext-of-path) (as-string ext))))

(module+ test
  (check-false (has-ext? foo-path 'txt)) 
  (check-true (has-ext? foo.txt-path 'txt))
  (check-true (has-ext? foo.bar.txt-path 'txt))
  (check-false (has-ext? foo.bar.txt-path 'doc))) ; wrong extension


;; take one extension off path
(define/contract (remove-ext path)
  (path? . -> . path?)
  (path-replace-suffix path ""))

(module+ test  
  (check-equal? (remove-ext foo-path) foo-path)
  (check-equal? (remove-ext foo.txt-path) foo-path)
  (check-equal? (remove-ext foo.bar.txt-path) foo.bar-path)
  (check-not-equal? (remove-ext foo.bar.txt-path) foo-path)) ; does not remove all extensions


;; take all extensions off path
(define/contract (remove-all-ext path)
  (path? . -> . path?)
  (define path-with-removed-ext (remove-ext path))
  (if (equal? path path-with-removed-ext)
      path
      (remove-all-ext path-with-removed-ext)))

(module+ test  
  (check-equal? (remove-all-ext foo-path) foo-path)
  (check-equal? (remove-all-ext foo.txt-path) foo-path)
  (check-not-equal? (remove-all-ext foo.bar.txt-path) foo.bar-path) ; removes more than one ext
  (check-equal? (remove-all-ext foo.bar.txt-path) foo-path))


;; is it an xexpr attributes?
(define/contract (xexpr-attr? x)
  (any/c . -> . boolean?)
  (match x
    ; list of symbol + string pairs
    [(list (list (? symbol? key) (? string? value)) ...) #t]
    [else #f]))

(module+ test  
  (check-true (xexpr-attr? '((key "value"))))
  (check-true (xexpr-attr? '((key "value") (foo "bar"))))
  (check-false (xexpr-attr? '((key "value") "foo" "bar"))) ; content, not attr
  (check-false (xexpr-attr? '(key "value"))) ; not a nested list
  (check-false (xexpr-attr? '(("key" "value")))) ; two strings
  (check-false (xexpr-attr? '((key value))))) ; two symbols


;; is it xexpr content?
(define/contract (xexpr-content? x)
  (any/c . -> . boolean?)
  (match x
    ;; this is more strict than xexpr definition in xml module
    ;; don't allow symbols or numbers to be part of content
    [(list elem ...) (andmap (λ(e) (or (string? e) (named-xexpr? e))) elem)]
    [else #f]))

(module+ test  
  (check-true (xexpr-content? '("p" "foo" "123")))
  (check-false (xexpr-content? "foo")) ; not a list
  (check-false (xexpr-content? '("p" "foo" 123))) ; includes number
  (check-false (xexpr-content? '(p "foo" "123"))) ; includes symbol
  (check-false (xexpr-content? '(((key "value")) "foo" "bar"))) ; includes attr
  (check-false (xexpr-content? '("foo" "bar" ((key "value")))))) ; malformed


;; is it a named x-expression?
;; todo: rewrite this recurively so errors can be pinpointed (for debugging)
(define/contract (named-xexpr? x)
  (any/c . -> . boolean?)
  (and (xexpr? x) ; meets basic xexpr contract
       (match x
         [(list (? symbol? name) rest ...) ; is a list starting with a symbol
          (or (xexpr-content? rest) ; the rest is content or ...
              (and (xexpr-attr? (car rest)) (xexpr-content? (cdr rest))))] ; attr + content 
         [else #f])))

(module+ test  
  (check-true (named-xexpr? '(p "foo" "bar")))
  (check-true (named-xexpr? '(p ((key "value")) "foo" "bar")))
  (check-false (named-xexpr? "foo")) ; not a list with symbol
  (check-false (named-xexpr? '(p "foo" "bar" ((key "value"))))) ; malformed
  (check-false (named-xexpr? '("p" "foo" "bar"))) ; no name
  (check-false (named-xexpr? '(p 123)))) ; content is a number
