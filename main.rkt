#lang racket/base

(provide (except-out (all-from-out racket/base) #%module-begin)
         (rename-out [new-module-begin #%module-begin]))

(define-syntax-rule (new-module-begin body-exprs ...)
  (#%module-begin
   (module inner pollen/lang/doclang_raw
     ;; first three lines are positional arguments for doclang_raw
     ;; doclang_raw is a version of scribble/doclang with the decoder disabled
     main-raw ; id of export
     (λ(x) x) ; post-process function
     () ; prepended exprs
     
     (require pollen/lang/inner-lang-helper)
     (require-and-provide-project-require-files) ; only works if current-directory is set correctly
     
     ;; Change behavior of undefined identifiers with #%top
     (require pollen/top)
     (provide (all-from-out pollen/top))
     
     ;; Get project values
     (require pollen/world)
     (provide (all-from-out pollen/world))
     
     ;; Build 'inner-here-path and 'inner-here
     (define (here-path->here here-path)
       (path->string (path-replace-suffix (pollen-find-relative-path (CURRENT_PROJECT_ROOT) here-path) "")))
     (define inner-here-path (get-here-path))
     (define inner-here (here-path->here inner-here-path))
     
     (provide (all-defined-out))
     
     body-exprs ...)
   
   (require 'inner)
   
   ;; Split out the metas.   
   (require txexpr)   
   (define (split-metas-to-hash tx)
     ;; return tx without metas, and meta hash
     (define is-meta-element? (λ(x) (and (txexpr? x) (equal? 'meta (car x)))))
     (define-values (main-without-metas meta-elements) 
       (splitf-txexpr tx is-meta-element?))
     (define meta-element->assoc (λ(x) (let ([key (car (caadr x))][value (cadr (caadr x))]) (cons key value))))
     (define metas (make-hash (map meta-element->assoc meta-elements)))
     (values main-without-metas metas))
   
   (define main-txexpr `(placeholder-root 
                         ,@(cons (meta 'here: inner-here) 
                                 (cons (meta 'here-path: inner-here-path) 
                                       ;; cdr strips initial linebreak, but make sure main-raw isn't blank
                                       (if (and (list? main-raw) (> 0 (length main-raw))) (cdr main-raw) main-raw))))) 
   (define-values (main-without-metas metas) (split-metas-to-hash main-txexpr))
   
   
   ;; set up the 'main export
   (require pollen/decode)
   (define here-ext (car (regexp-match #px"\\w+$" inner-here-path)))
   (define wants-decoder? (member here-ext (map to-string DECODABLE_EXTENSIONS)))
   (define main (apply (cond
                         [(equal? here-ext "ptree") (λ xs (decode (cons PTREE_ROOT_NODE xs)
                             #:xexpr-elements-proc (λ(xs) (filter (compose1 not (bound/c whitespace?)) xs))))]
                         ;; 'root is the hook for the decoder function.
                         ;; If it's not a defined identifier, it just hits #%top and becomes `(root ,@body ...)
                         [wants-decoder? root]
                         ;; for preprocessor output, just make a string.
                         [else (λ xs (apply string-append (map to-string xs)))])
                       (cdr main-without-metas))) ;; cdr strips placeholder-root tag
   
   
   ;; derive 'here & 'here-path from the hash (because they might have been overridden in the source) 
   (define here (hash-ref metas 'here))
   (define here-path (hash-ref metas 'here-path))
   
   (provide metas main here here-path
            ;; hide the exports that were only for internal use.
            (except-out (all-from-out 'inner) inner-here inner-here-path main-raw #%top))
   
   ;; for output in DrRacket
   (module+ main
     (if wants-decoder? 
         (print main) 
         (display main)))))
