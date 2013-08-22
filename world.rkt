#lang racket/base

(define POLLEN_PREPROC_EXT 'pp)
(define POLLEN_SOURCE_EXT 'p)
(define TEMPLATE_FILE_PREFIX #\-)
(define POLLEN_EXPRESSION_DELIMITER #\◊)
(define TEMPLATE_FIELD_DELIMITER POLLEN_EXPRESSION_DELIMITER)

(define DEFAULT_TEMPLATE "-main.html")
(define FALLBACK_TEMPLATE_NAME "-temp-fallback-template.html")
(define TEMPLATE_META_KEY "template")

(define POLLEN_MAP_EXT 'pmap)
(define DEFAULT_POLLEN_MAP "main.pmap")
(define POLLEN_MAP_PARENT_KEY 'parent)

(define MAIN_POLLEN_EXPORT 'main)
;(define META_POLLEN_TAG 'metas)
;(define META_POLLEN_EXPORT 'metas)

(define EXTRAS_DIR (string->path "requires"))

(define MISSING_FILE_BOILERPLATE "#lang planet mb/pollen\n\n")

(define LINE_BREAK "\n")
(define PARAGRAPH_BREAK "\n\n")

(define OUTPUT_SUBDIR 'public)

(define RACKET_PATH "/Applications/Racket/bin/racket")

(define POLLEN_ROOT 'main)

; todo: this doesn't work as hoped
;(define-syntax POLLEN_ROOT_TAG
;  (λ(stx) (datum->syntax stx 'main)))

; get the starting directory, which is the parent of 'run-file
(define START_DIR
  (let-values ([(dir ignored also-ignored)
                (split-path (find-system-path 'run-file))])
    (if (equal? dir 'relative)
        (string->path ".")
        dir)))

(provide (all-defined-out))