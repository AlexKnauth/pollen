#lang racket/base

(provide (prefix-out world: (all-defined-out)))

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

(define decodable-extensions (list markup-source-ext pagetree-source-ext))

(define default-pagetree "index.ptree")
(define pagetree-root-node 'pagetree-root)

(define template-source-prefix "-")
(define expression-delimiter #\◊)
(define template-field-delimiter expression-delimiter)

(define default-template-prefix "main")
(define fallback-template "fallback.html.pt")
(define template-meta-key "template")

(define main-pollen-export 'doc) ; don't forget to change fallback template too
(define meta-pollen-export 'metas)

(define pollen-require "pollen-require.rkt")

(define missing-file-boilerplace "#lang pollen\n\n")

(define newline "\n")
(define linebreak-separator newline)
(define paragraph-separator "\n\n")

(define output-subdir 'public)

(define racket-path "/usr/bin/racket")

(define command-file "polcom")

(define reserved-paths
  (map string->path (list command-file "poldash.css" "compiled")))


(define current-project-root (make-parameter (current-directory)))

(define current-server-port (make-parameter 8088))

(define dashboard-name "index.pmap")
(define dashboard-css "poldash.css")

(define current-module-root (make-parameter #f))
(define current-server-extras-path (make-parameter #f))

(define check-project-requires-in-render? (make-parameter #t))
