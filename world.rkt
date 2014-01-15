#lang racket/base

(provide (all-defined-out))

(define POLLEN_VERSION "0.001")

(define POLLEN_PREPROC_EXT 'p)
(define POLLEN_SOURCE_EXT 'pd)
(define TEMPLATE_FILE_PREFIX "-")
(define POLLEN_EXPRESSION_DELIMITER #\◊)
(define TEMPLATE_FIELD_DELIMITER POLLEN_EXPRESSION_DELIMITER)

(define DEFAULT_TEMPLATE_PREFIX "-main")
(define FALLBACK_TEMPLATE_NAME "-temp-fallback-template.html")
(define TEMPLATE_META_KEY "template")

(define POLLEN_TREE_EXT 'ptree)
(define DEFAULT_POLLEN_TREE "main.ptree")
(define POLLEN_TREE_PARENT_NAME 'parent)
(define POLLEN_TREE_ROOT_NAME 'ptree-root)

(define MAIN_POLLEN_EXPORT 'main)
;(define META_POLLEN_TAG 'metas)
;(define META_POLLEN_EXPORT 'metas)

(define EXTRAS_DIR (string->path "pollen-require"))

(define MISSING_FILE_BOILERPLATE "#lang pollen\n\n")

(define LINE_BREAK "\n")
(define PARAGRAPH_BREAK "\n\n")

(define OUTPUT_SUBDIR 'public)

(require racket/string racket/port racket/system)
;; todo: is path to racket already available as an environment variable?
;; e.g., (find-system-path 'xxx)?
;;(define RACKET_PATH (string-trim (with-output-to-string (λ() (system "which racket")))))
(define RACKET_PATH "/usr/bin/racket")

(define POLLEN_ROOT 'main)
(define POLLEN_COMMAND_FILE "polcom")

; get the starting directory, which is the parent of 'run-file
(define POLLEN_PROJECT_DIR
  (let-values ([(dir ignored also-ignored)
                (split-path (find-system-path 'run-file))])
    (if (equal? dir 'relative)
        (string->path ".")
        dir)))


(require "readability.rkt")
(define RESERVED_PATHS
  (map ->path (list POLLEN_COMMAND_FILE EXTRAS_DIR)))


