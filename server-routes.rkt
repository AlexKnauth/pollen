#lang racket/base
(require racket/list racket/contract racket/rerequire racket/file racket/format xml racket/match racket/set)
(require (only-in net/url url-query url->path url->string))
(require (only-in web-server/http/request-structs request-uri request-client-ip))
(require "world.rkt" "render.rkt" "readability.rkt" "predicates.rkt" "debug.rkt")

(module+ test (require rackunit))

;;; Routes for the server module
;;; separated out for ease of testing
;;; because it's tedious to start the server just to check a route.

(provide (all-defined-out))

;; extract main xexpr from a path
(define/contract (file->xexpr path #:render [wants-render #t])
  ((complete-path?) (#:render boolean?) . ->* . tagged-xexpr?)
  (when wants-render (render path))
  (dynamic-rerequire path) ; stores module mod date; reloads if it's changed
  (dynamic-require path 'main))

;; todo: rewrite this test, obsolete since filename convention changed
;;(module+ test
;;  (check-equal? (file->xexpr (build-path (current-directory) "tests/server-routes/foo.p") #:render #f) '(root "\n" "foo")))

;; read contents of file to string
;; just file->string with a render option
(define/contract (slurp path #:render [wants-render #t])
  ((complete-path?) (#:render boolean?) . ->* . string?) 
  (when wants-render (render path))
  (file->string path))

(module+ test
  (check-equal? (slurp (build-path (current-directory) "tests/server-routes/bar.html") #:render #f) "<html><body><p>bar</p></body></html>"))


;; add a wrapper to tagged-xexpr that displays it as monospaced text
;; for "view source"ish functions
;; takes either a string or an xexpr
(define/contract (format-as-code x)
  (xexpr? . -> . tagged-xexpr?)
  `(div ((style "white-space:pre-wrap;font-family:AlixFB,monospaced")) ,x))

(module+ test
  (check-equal? (format-as-code '(p "foo")) '(div ((style "white-space:pre-wrap;font-family:AlixFB,monospaced")) (p "foo"))))

;; server routes
;; these all produce an xexpr, which is handled upstream by response/xexpr

;; server route that returns html
;; todo: what is this for?
(define/contract (route-html path)
  (complete-path? . -> . xexpr?)
  (file->xexpr path))

;; server route that returns raw html, formatted as code
;; for viewing source without using "view source"
(define/contract (route-raw path)
  (complete-path? . -> . xexpr?)
  (format-as-code (slurp path #:render #f)))

;; server route that returns xexpr (before conversion to html)
(define/contract (route-xexpr path)
  (complete-path? . -> . xexpr?)
  (format-as-code (~v (file->xexpr path))))



(define (route-dashboard dir)
  (define empty-cell (cons #f #f))
  (define (make-link-cell href+text)
    (match-define (cons href text) href+text) 
    (filter-not void? `(td ,(when text 
                              (if href 
                                  `(a ((href ,href)) ,text)
                                  text)))))
  (define (make-path-row fn)
    (define filename (->string fn))
    (define (file-in-dir? fn) (file-exists? (build-path dir fn)))
    (define possible-sources (filter file-in-dir? (list (->preproc-source-path filename) (->pollen-source-path filename))))
    (define source (and (not (empty? possible-sources)) (->string (car possible-sources))))
    `(tr ,@(map make-link-cell 
                (append (list 
                         ;; folder traversal cell
                         (if (directory-exists? (build-path dir filename)) ; links subdir to its dashboard
                             (cons (format "~a/~a" filename DASHBOARD_NAME) "dash")
                             empty-cell)
                         (cons filename filename) ; main cell 
                         (if source ; source cell (if needed)
                             (cons source (format "~a source" (get-ext source)))
                             empty-cell)
                         (cond ; raw cell (if needed)
                           [(directory-exists? (build-path dir filename)) (cons #f "(folder)")]
                           [(has-binary-ext? filename) (cons #f "(binary)")]
                           [else (cons (format "raw/~a" filename) "output")]))
                        
                        (if source
                            (list
                             (if (has-ext? source POLLEN_DECODER_EXT) ; xexpr cell for pollen decoder files
                                 (cons (format "xexpr/~a" source) "xexpr")
                                 empty-cell)
                             (cons (format "force/~a" filename) filename)) ; force refresh cell
                            (make-list 2 empty-cell))))))
  
  (define (unique-sorted-output-paths xs)
    (sort (set->list (list->set (map ->output-path xs))) #:key ->string string<?))
  
  (define (ineligible-path? x) (or (not (visible? x)) (member x RESERVED_PATHS)))  
  
  (define project-paths (filter-not ineligible-path? (directory-list dir)))
  
  ;; todo: add link to parent directory
  `(html
    (head (link ((rel "stylesheet") (type "text/css") (href "/poldash.css"))))
    (body
     (table 
      ,@(map make-path-row (unique-sorted-output-paths project-paths))))))


(define (get-query-value url key)
  ; query is parsed as list of pairs, key is symbol, value is string
  ; '((key . "value") ... )
  (let ([result (memf (λ(x) (equal? (car x) key)) (url-query url))])
    (and result (cdar result)))) ; second value of first result


; default route
(define (route-default req)  
  (define request-url (request-uri req))
  (define path (reroot-path (url->path request-url) PROJECT_ROOT))
  (define force (equal? (get-query-value request-url 'force) "true"))
  (with-handlers ([exn:fail? (λ(e) (message "Render is skipping" (url->string request-url) "because of error\n" (exn-message e)))])
    (render path #:force force)))


(module+ main
  (route-dashboard "foobar"))