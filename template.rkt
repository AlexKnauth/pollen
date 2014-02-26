#lang racket/base
(require racket/contract racket/string xml xml/path)
(require "tools.rkt" "ptree.rkt" "cache.rkt" sugar txexpr)

;; setup for test cases
(module+ test (require rackunit racket/path))

(provide (all-defined-out))
(require sugar/scribble sugar/coerce)
(provide (all-from-out sugar/scribble sugar/coerce))


;; todo: docstrings for this subsection

(define/contract (puttable-item? x)
  (any/c . -> . boolean?)
  (or (txexpr? x) 
      (has-markup-source? x) 
      (and (pnode? x) (pnode->url x) (has-markup-source? (pnode->url x)))))

(module+ test
  (check-false (puttable-item? #t))
  (check-false (puttable-item? #f)))

(define/contract (query-key? x)
  (any/c . -> . boolean?)
  (or (string? x) (symbol? x)))

(define/contract (put x)
  (puttable-item? . -> . txexpr?)
  (cond
    ;; Using put has no effect on txexprs. It's here to make the idiom smooth.
    [(txexpr? x) x] 
    [(has-markup-source? x) (cached-require (->markup-source-path x) 'main)]
    [(has-markup-source? (pnode->url x)) (cached-require (->markup-source-path (pnode->url x)) 'main)]))

#|(module+ test
  (check-equal? (put '(foo "bar")) '(foo "bar"))
  (check-equal? (put "tests/template/put.pd") 
                '(root "\n" "\n" (em "One") " paragraph" "\n" "\n" "Another " (em "paragraph") "\n" "\n")))
|#


(define/contract (find query px)
  (query-key? (or/c #f puttable-item?) . -> . (or/c #f txexpr-element?))
  (define result (and px (or (find-in-metas px query) (find-in-main px query))))
  (and result (car result))) ;; return false or first element

#|
(module+ test 
  (parameterize ([current-directory "tests/template"])
    (check-false (find "nonexistent-key" "put"))
    (check-equal? (find "foo" "put") "bar")
    (check-equal? (find "em" "put") "One"))
  (check-equal? (find "foo" #f) #f))
|#

(define/contract (find-in-metas px key)
  (puttable-item? query-key? . -> . (or/c #f txexpr-elements?))
  (and (has-markup-source? px)
       (let ([metas (cached-require (->markup-source-path px) 'metas)]
             [key (->string key)])
         (and (key . in? . metas ) (->list (get metas key))))))

#|(module+ test
  (parameterize ([current-directory "tests/template"])
    (check-equal? (find-in-metas "put" "foo") (list "bar"))
    (let* ([metas (cached-require (->markup-source-path 'put) 'metas)]
           [here (find-in-metas 'put 'here)])     
      (check-equal? here (list "tests/template/put")))))
|#

(define/contract (find-in-main px query) 
  (puttable-item? (or/c query-key? (listof query-key?)) 
                  . -> . (or/c  #f txexpr-elements?))
  (let* ([px (put px)]
         ;; make sure query is a list of symbols (required by se-path*/list)
         [query (map ->symbol (->list query))]
         [results (se-path*/list query px)])
    ;; if results exist, send back xexpr as output
    (and (not (empty? results)) results)))

#|
(module+ test
  (parameterize ([current-directory "tests/template"])
    (check-false (find-in-main "put" "nonexistent-key"))
    (check-equal? (find-in-main "put" "em") (list "One" "paragraph"))))
|#

;; turns input into xexpr-elements so they can be spliced into template
;; (as opposed to dropped in as a full txexpr)
;; by returning a list, pollen rules will automatically merge into main flow
;; todo: explain why
;; todo: do I need this?
(define/contract (splice x)
  ((or/c txexpr? txexpr-elements? string?) . -> . txexpr-elements?)
  (cond
    [(txexpr? x) (get-elements x)]
    [(txexpr-elements? x) x]
    [(string? x) (->list x)]))

(module+ test
  (check-equal? (splice '(p "foo" "bar")) (list "foo" "bar"))
  (check-equal? (splice (list "foo" "bar")) (list "foo" "bar"))
  (check-equal? (splice "foo") (list "foo")))


(define/contract (make-html x)
  ((or/c txexpr? txexpr-elements? txexpr-element?) . -> . string?)
  (cond
    [(txexpr? x) (xexpr->string x)]
    [else (let ([x (->list x)])
            (string-join (map xexpr->string x) ""))]))

; generate *-as-html versions of functions
(define-values (put-as-html splice-as-html)
  (apply values (map (λ(proc) (λ(x) (make-html (proc x)))) (list put splice))))





