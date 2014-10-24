#lang racket/base
(require (for-syntax racket/base) racket/require)

(module world-main racket/base
  (provide (all-defined-out))
  (define pollen-version "0.001")
  
  (define preproc-source-ext 'pp)
  (define markup-source-ext 'pm)
  (define markdown-source-ext 'pmd)
  (define null-source-ext 'p)
  (define pagetree-source-ext 'ptree)
  (define template-source-ext 'pt)
  (define scribble-source-ext 'scrbl)
  
  (define mode-auto 'auto)
  (define mode-preproc 'pre)
  (define mode-markup 'markup)
  (define mode-markdown 'markdown)
  (define mode-pagetree 'ptree)
  (define mode-template 'template)
  
  (define cache-filename "pollen.cache")
  
  (define decodable-extensions (list markup-source-ext pagetree-source-ext))
  
  (define default-pagetree "index.ptree")
  (define pagetree-root-node 'pagetree-root)
  
  (define command-marker #\◊)
  (define template-command-marker #\∂)
  
  (define default-template-prefix "template")
  (define fallback-template-prefix "fallback")
  (define template-meta-key "template")
  
  (define main-pollen-export 'doc) ; don't forget to change fallback template too
  (define meta-pollen-export 'metas)
  
  (define directory-require "directory-require.rkt")
  
  (define newline "\n")
  (define linebreak-separator newline)
  (define paragraph-separator "\n\n")
  
  (define paths-excluded-from-dashboard
    (map string->path (list "poldash.css" "compiled")))
  
  
  (define current-project-root (make-parameter (current-directory)))
  
  (define default-port 8080)
  (define current-server-port (make-parameter default-port))
  
  (define dashboard-css "poldash.css")
  
  (define server-extras-dir "server-extras")
  (define current-server-extras-path (make-parameter #f))
  
  (define check-directory-requires-in-render? (make-parameter #t))
  
  (define clone-directory-name "clone"))

(define-syntax (overriding-require+provide-with-prefix stx)
  (syntax-case stx () [(_ main override out-prefix)
                       (let ([path-to-override (path->string (build-path (current-directory) (syntax->datum #'override)))])
                         (if (file-exists? path-to-override)
                             (with-syntax ([override (datum->syntax stx `(file ,(datum->syntax stx path-to-override)))])
                               #'(begin 
                                   (require (combine-in override (subtract-in main override)))
                                   (provide (prefix-out out-prefix (combine-out (all-from-out main) (all-from-out override))))))
                             #'(begin 
                                 (require main)
                                 (provide (prefix-out out-prefix (all-from-out main))))))]))


(overriding-require+provide-with-prefix 'world-main "directory-world.rkt" world:)

