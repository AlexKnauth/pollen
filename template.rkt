#lang racket/base
(require (for-syntax racket/base))
(require racket/string xml xml/path sugar/define sugar/container sugar/coerce)
(require "file.rkt" txexpr "world.rkt" "cache.rkt" "pagetree.rkt" "debug.rkt")

(provide (all-from-out sugar/coerce))


(define/contract+provide (metas->here metas)
  (hash? . -> . pagenode?)
  (path->pagenode (select-from-metas 'here-path metas)))


(define (pagenode->path pagenode)
  (build-path (world:current-project-root) (symbol->string pagenode)))


(define+provide/contract (select key value-source)
  (coerce/symbol? (or/c hash? txexpr? pagenode? pathish?) . -> . (or/c #f txexpr-element?))
  (define metas-result (and (not (txexpr? value-source)) (select-from-metas key value-source)))
  (or metas-result
      (let ([doc-result (select-from-doc key value-source)])
        (and doc-result (car doc-result)))))


(define+provide/contract (select* key value-source)
  (coerce/symbol? (or/c hash? txexpr? pagenode? pathish?) . -> . (or/c #f txexpr-elements?))
  (define metas-result (and (not (txexpr? value-source)) (select-from-metas key value-source)))
  (define doc-result (select-from-doc key value-source))
  (define result (append (or (and metas-result (list metas-result)) null) (or doc-result null)))
  (and (not (null? result)) result))


(define+provide/contract (select-from-metas key metas-source)
  (coerce/symbol? (or/c hash? pagenode? pathish?) . -> . (or/c #f txexpr-element?))
  (define metas (cond
                  [(hash? metas-source) metas-source]
                  [else (get-metas metas-source)]))
  (and (hash-has-key? metas key) (hash-ref metas key)))


(define+provide/contract (select-from-doc key doc-source)
  (coerce/symbol? (or/c txexpr? pagenode? pathish?) . -> . (or/c #f txexpr-elements?))
  (define doc (cond
                [(txexpr? doc-source) doc-source]
                [else (get-doc doc-source)]))
  (define result (se-path*/list (list key) doc))
  (and (not (null? result)) result))


(define (get-metas pagenode-or-path)
  ;  ((or/c pagenode? pathish?) . -> . hash?)
  (define source-path (->source-path (cond
                                       [(pagenode? pagenode-or-path) (pagenode->path pagenode-or-path)]
                                       [else pagenode-or-path])))
  (if source-path
      (cached-require source-path world:meta-pollen-export)
      (error (format "get-metas: no source found for '~a' in directory ~a" pagenode-or-path (current-directory)))))


(define (get-doc pagenode-or-path)
  ;  ((or/c pagenode? pathish?) . -> . (or/c txexpr? string?))
  (define source-path (->source-path (cond
                                       [(pagenode? pagenode-or-path) (pagenode->path pagenode-or-path)]
                                       [else pagenode-or-path])))
  (if source-path
      (cached-require source-path world:main-pollen-export)
      (error (format "get-doc: no source found for '~a' in directory ~a" pagenode-or-path (current-directory)))))


(define (trim-outer-tag html)
  (define matches (regexp-match #px"<.*?>(.*)</.*?>" html))
  (define paren-match (cadr matches))
  paren-match)

(define+provide/contract (->html x #:tag [tag #f] #:attrs [attrs #f] #:splice [splice? #f])
  ((xexpr?) (#:tag (or/c #f txexpr-tag?) #:attrs (or/c #f txexpr-attrs?) #:splice boolean?) . ->* . string?)

  (when (and (not (txexpr? x)) attrs (not tag))
      (error '->html "can't use attribute list '~a without a #:tag argument" attrs))
      
  (if (or tag (txexpr? x))
      (let ()
        (define html-tag (or tag (get-tag x)))
        (define html-attrs (or attrs (and (txexpr? x) (get-attrs x)) null))
        (define html-elements (or (and (txexpr? x) (get-elements x)) (list x)))
        (define html (xexpr->html (make-txexpr html-tag html-attrs html-elements)))
        (if splice?
            (trim-outer-tag html)
            html))
      (xexpr->html x)))  

(provide when/block)
(define-syntax (when/block stx)
  (syntax-case stx ()
    [(_ condition body ...)
     #'(if condition (string-append* 
                      (with-handlers ([exn:fail? (λ(exn) (error (format "within when/block, ~a" (exn-message exn))))])
                        (map ->string (list body ...)))) 
           "")]))