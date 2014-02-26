#lang racket/base
(require (for-syntax racket/base))
(require racket/path racket/bool racket/rerequire racket/contract)
(require "tools.rkt" "world.rkt" "decode.rkt" sugar txexpr "cache.rkt")

(module+ test (require rackunit))


(define+provide/contract (pnode? x)
  (any/c . -> . boolean?)
  (try (not (whitespace? (->string x)))
       (except [exn:fail? (λ(e) #f)])))

(define+provide/contract (pnode?/error x)
  (any/c . -> . boolean?)
  (or (pnode? x) (error "Not a valid pnode:" x)))

(module+ test
  (check-true (pnode? "foo-bar"))
  (check-true (pnode? "Foo_Bar_0123"))
  (check-true (pnode? 'foo-bar))
  (check-true (pnode? "foo-bar.p"))
  (check-true (pnode? "/Users/MB/foo-bar"))
  (check-false (pnode? #f))
  (check-false (pnode? ""))
  (check-false (pnode? " ")))


(define+provide/contract (ptree? x)
  (any/c . -> . boolean?)
  (and (txexpr? x) (andmap (λ(i) (or (pnode? i) (ptree? i))) x)))

(module+ test
  (check-true (ptree? '(foo)))
  (check-true (ptree? '(foo (hee))))
  (check-true (ptree? '(foo (hee (uncle "foo"))))))


;; implement the caching with two hashes rather than composite key of (cons file mod-date)
;; so that cached copies don't pile up indefinitely
(define ptree-cache (make-hash))
(define ptree-source-mod-dates (make-hash))

(define (not-modified-since-last-pass? ptree-source-path)
  (and (hash-has-key? ptree-source-mod-dates ptree-source-path) 
       ((file-or-directory-modify-seconds ptree-source-path) . = . (hash-ref ptree-source-mod-dates ptree-source-path))))

(define+provide/contract (file->ptree p)
  (pathish? . -> . ptree?)
  (cached-require (->path p) MAIN_POLLEN_EXPORT))

(define+provide/contract (directory->ptree dir)
  (directory-pathish? . -> . ptree?)
  (let ([files (map remove-ext (filter (λ(x) (has-ext? x MARKUP_SOURCE_EXT)) (directory-list dir)))])
    (ptree-root->ptree (cons PTREE_ROOT_NODE files))))

;; Try loading from ptree file, or failing that, synthesize ptree.
(define+provide/contract (make-project-ptree project-dir)
  (directory-pathish? . -> . ptree?)
  (define ptree-source (build-path project-dir DEFAULT_PTREE))
  (cached-require ptree-source 'main))


(module+ test
  (let ([sample-main `(POLLEN_TREE_ROOT_NAME "foo" "bar" (one (two "three")))])
    (check-equal? (ptree-root->ptree sample-main) 
                  `(POLLEN_TREE_ROOT_NAME "foo" "bar" (one (two "three"))))))


(define+provide/contract (parent pnode [ptree (current-ptree)])
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? pnode?)) 
  (and pnode
       (if (member (->string pnode) (map (λ(x) (->string (if (list? x) (car x) x))) (cdr ptree)))
           (->string (car ptree))
           (ormap (λ(x) (parent pnode x)) (filter list? ptree)))))


(module+ test
  (define test-ptree-main `(ptree-main "foo" "bar" (one (two "three"))))
  (define test-ptree (ptree-root->ptree test-ptree-main))
  (check-equal? (parent 'three test-ptree) "two")
  (check-equal? (parent "three" test-ptree) "two")
  (check-false (parent #f test-ptree))
  (check-false (parent 'nonexistent-name test-ptree)))


(define+provide/contract (children pnode [ptree (current-ptree)])
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? (listof pnode?)))  
  (and pnode 
       (if (equal? (->string pnode) (->string (car ptree)))
           (map (λ(x) (->string (if (list? x) (car x) x))) (cdr ptree))
           (ormap (λ(x) (children pnode x)) (filter list? ptree)))))

(module+ test
  (check-equal? (children 'one test-ptree) (list "two"))
  (check-equal? (children 'two test-ptree) (list "three"))
  (check-false (children 'three test-ptree))
  (check-false (children #f test-ptree))
  (check-false (children 'fooburger test-ptree)))


(define+provide/contract (siblings pnode [ptree (current-ptree)])
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? (listof string?)))  
  (children (parent pnode ptree) ptree))


(module+ test
  (check-equal? (siblings 'one test-ptree) '("foo" "bar" "one"))
  (check-equal? (siblings 'foo test-ptree) '("foo" "bar" "one"))
  (check-equal? (siblings 'two test-ptree) '("two"))
  (check-false (siblings #f test-ptree))
  (check-false (siblings 'invalid-key test-ptree)))



;; flatten tree to sequence
(define+provide/contract (ptree->list [ptree (current-ptree)])
  (ptree? . -> . (listof string?))
  ; use cdr to get rid of root tag at front
  (map ->string (cdr (flatten ptree)))) 

(module+ test
  (check-equal? (ptree->list test-ptree) '("foo" "bar" "one" "two" "three")))



(define+provide/contract (adjacents side pnode [ptree (current-ptree)])
  ((symbol? (or/c false? pnode?)) (ptree?) . ->* . (or/c false? (listof pnode?)))
  (and pnode
       (let* ([proc (if (equal? side 'left) takef takef-right)]
              [result (proc (ptree->list ptree) (λ(x) (not (equal? (->string pnode) (->string x)))))])
         (and (not (empty? result)) result))))


(define+provide/contract (left-adjacents pnode [ptree (current-ptree)]) 
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? (listof pnode?)))
  (adjacents 'left pnode ptree))

(module+ test
  (check-equal? (left-adjacents 'one test-ptree) '("foo" "bar"))
  (check-equal? (left-adjacents 'three test-ptree) '("foo" "bar" "one" "two"))
  (check-false (left-adjacents 'foo test-ptree)))

(define+provide/contract (right-adjacents pnode [ptree (current-ptree)]) 
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? (listof pnode?)))
  (adjacents 'right pnode ptree))

(define+provide/contract (previous pnode [ptree (current-ptree)])
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? pnode?))
  (let ([result (left-adjacents pnode ptree)])
    (and result (last result))))

(module+ test
  (check-equal? (previous 'one test-ptree) "bar")
  (check-equal? (previous 'three test-ptree) "two")
  (check-false (previous 'foo test-ptree)))


(define+provide/contract (next pnode [ptree (current-ptree)])
  (((or/c false? pnode?)) (ptree?) . ->* . (or/c false? pnode?))
  (let ([result (right-adjacents pnode ptree)])
    (and result (first result))))

(module+ test
  (check-equal? (next 'foo test-ptree) "bar")
  (check-equal? (next 'one test-ptree) "two")
  (check-false (next 'three test-ptree)))



;; this is a helper function to permit unit tests
(define+provide (pnode->url/paths pnode url-list)
  ;; check for duplicates because some sources might have already been rendered
  (define output-paths (remove-duplicates (map ->output-path url-list) equal?))
  (define matching-paths (filter (λ(x) (equal? (->string x) (->string pnode))) output-paths))
  
  (cond
    [((len matching-paths) . = . 1) (->string (car matching-paths))]
    [((len matching-paths) . > . 1) (error "More than one matching URL for" pnode)]
    [else #f]))

(module+ test
  (define files '("foo.html" "bar.html" "bar.html.p" "zap.html" "zap.xml"))
  (check-equal? (pnode->url/paths 'foo.html files) "foo.html")
  (check-equal? (pnode->url/paths 'bar.html files) "bar.html")
  ;;  (check-equal? (name->url 'zap files) 'error) ;; todo: how to test error?
  (check-false (pnode->url/paths 'hee files)))


(define+provide/contract (pnode->url pnode [url-context (current-url-context)])
  ((pnode?) (pathish?) . ->* . (or/c false? pnode?))
  (parameterize ([current-url-context url-context])
    (pnode->url/paths pnode (directory-list (current-url-context)))))




;; this sets default input for following functions
(define+provide/contract (ptree-root->ptree tx)
  ;; (not/c ptree) prevents ptrees from being accepted as input
  ((and/c txexpr?) . -> . ptree?)
  tx)


(module+ test
  (set! test-ptree-main `(,PTREE_ROOT_NODE "foo" "bar" (one (two "three"))))
  (check-equal? (ptree-root->ptree test-ptree-main) 
                `(,PTREE_ROOT_NODE "foo" "bar" (one (two "three")))))


(define+provide/contract (pnodes-unique?/error x)
  (any/c . -> . boolean?)
  (define members (filter-not whitespace? (flatten x)))
  (and (andmap pnode?/error members)
       (members-unique?/error (map ->string members))))

(define+provide/contract (ptree-source-decode . elements)
  (() #:rest pnodes-unique?/error . ->* . ptree?)
  (ptree-root->ptree (decode (cons PTREE_ROOT_NODE elements)
                             #:xexpr-elements-proc (λ(xs) (filter-not whitespace? xs)))))


(define current-ptree (make-parameter `(,PTREE_ROOT_NODE)))
(define current-url-context (make-parameter (CURRENT_PROJECT_ROOT)))
(provide current-ptree current-url-context)


;; used to convert here-path into here
(define+provide/contract (path->pnode path)
  (pathish? . -> . pnode?)
  (->string (->output-path (find-relative-path (CURRENT_PROJECT_ROOT) (->path path)))))


#|
(module+ main
  (displayln "Running module main")
  (set-current-ptree (make-project-ptree (->path "/Users/MB/git/bpt/")))
  (set-current-url-context "/Users/MB/git/bpt/")
  (ptree-previous (ptree-previous 'what-is-typography.html))
  (name->url "how-to-pay-for-this-book.html"))
|#