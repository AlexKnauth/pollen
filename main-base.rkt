#lang racket/base
(require (for-syntax racket/base racket/syntax) pollen/world)

(provide (all-defined-out) (all-from-out pollen/world))

(define-syntax (make-new-module-begin stx)
  (syntax-case stx ()
    [(_ mode-arg)
     (with-syntax ([new-module-begin (format-id stx "new-module-begin")])
       #'(define-syntax (new-module-begin stx-arg)
           (syntax-case stx-arg ()
             [(_ body-exprs (... ...))
              (syntax-protect 
               #'(#%module-begin
                  (module inner pollen/lang/doclang-raw
                    ;; doclang_raw is a version of scribble/doclang with the decoder disabled
                    ;; first three lines are positional arguments for doclang-raw
                    doc-raw ; id of export
                    (λ(x) x) ; post-process function
                    () ; prepended exprs
                    
                    ;; Change behavior of undefined identifiers with #%top
                    ;; Get project values from world
                    (require pollen/top pollen/world)
                    (provide (all-from-out pollen/top pollen/world))
                    
                    ;; for anything defined in pollen source file
                    (provide (all-defined-out))
                    
                    body-exprs (... ...))
                  
                  (require 'inner)
                  
                  
                  ;; if reader-here-path is undefined, it will become a proc courtesy of #%top
                  ;; therefore that's how we can detect if it's undefined
                  (define here-path (if (procedure? reader-here-path) "anonymous-module" reader-here-path))

                  
                  ;; set the parser mode based on reader mode
                  ;; todo: this won't work with inline submodules
                  (define parser-mode 
                    (if (not (procedure? reader-mode))
                      (if (equal? reader-mode world:mode-auto)
                          (let* ([file-ext-pattern (pregexp "\\w+$")]
                                 [here-ext (string->symbol (car (regexp-match file-ext-pattern here-path)))])
                            (cond
                              [(equal? here-ext world:pagetree-source-ext) world:mode-pagetree]
                              [(equal? here-ext world:markup-source-ext) world:mode-markup]
                              [(equal? here-ext world:markdown-source-ext) world:mode-markdown]
                              [else world:mode-preproc]))
                          reader-mode)
                      mode-arg))
                  
                  
                  ;; Split out the metas.   
                  (require txexpr)   
                  (define (split-metas-to-hash tx) ; helper function
                    ;; return tx without metas, and meta hash
                    (define is-meta-element? (λ(x) (and (txexpr? x) (equal? 'meta (car x)))))
                    (define-values (doc-without-metas meta-elements) 
                      (splitf-txexpr tx is-meta-element?))
                    (define meta-element->assoc (λ(x) (let ([key (car (caadr x))][value (cadr (caadr x))]) (cons key value))))
                    (define metas (make-hash (map meta-element->assoc meta-elements)))
                    (values doc-without-metas metas))
                  
                  
                  (define doc-txexpr 
                    (let ([doc-raw (if (equal? parser-mode world:mode-markdown)
                                       (apply (compose1 (dynamic-require 'markdown 'parse-markdown) string-append) doc-raw)
                                       doc-raw)])
                      `(placeholder-root 
                        ,@(cons (meta 'here-path: here-path) 
                                ;; cdr strips initial linebreak, but make sure doc-raw isn't blank
                                (if (and (list? doc-raw) (> 0 (length doc-raw))) (cdr doc-raw) doc-raw))))) 
                  
                  (define-values (doc-without-metas metas) (split-metas-to-hash doc-txexpr))
                  
                  
                  ;; set up the 'doc export
                  (require pollen/decode)
                  (define doc (apply (cond
                                       [(equal? parser-mode world:mode-pagetree) (λ xs ((dynamic-require 'pollen/pagetree 'decode-pagetree) xs))]
                                       ;; 'root is the hook for the decoder function.
                                       ;; If it's not a defined identifier, it just hits #%top and becomes `(root ,@body ...)
                                       [(or (equal? parser-mode world:mode-markup)
                                            (equal? parser-mode world:mode-markdown)) root]
                                       ;; for preprocessor output, just make a string.
                                       [else (λ xs (apply string-append (map to-string xs)))])
                                     (cdr doc-without-metas))) ;; cdr strips placeholder-root tag
                  
                  
                  (provide metas doc
                           ;; hide the exports that were only for internal use.
                           (except-out (all-from-out 'inner) doc-raw #%top))
                  
                  ;; for output in DrRacket
                  (module+ main
                    (if (equal? parser-mode world:mode-preproc)
                        (display doc)
                        (print doc)))))])))]))
