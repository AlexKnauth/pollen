#lang racket/base
(require racket/contract racket/list racket/match)
(require (planet mb/pollen/tools) (planet mb/pollen/decode))

(provide (all-defined-out))

(module+ test (require rackunit))


;; register custom block tags
(register-block-name 'bloq)
(register-block-name 'fooble)


;; handle meta tags
(define/contract (meta-proc meta)
  (meta-xexpr? . -> . named-xexpr?)
  `(meta ((name ,(second meta))(content ,(third meta)))))

(module+ test
  (check-equal? (meta-proc '(meta "key" "value")) '(meta ((name "key")(content "value")))))

;; is x a paragraph break?
(define/contract (paragraph-break? x #:pattern [paragraph-pattern #px"^\n\n+$"])
  ((any/c) (#:pattern pregexp?) . ->* . boolean?)
  (and (string? x) (->boolean (regexp-match paragraph-pattern x))))

(module+ test
  (check-false (paragraph-break? "foo"))
  (check-false (paragraph-break? "\n"))
  (check-false (paragraph-break? "\n \n"))
  (check-true (paragraph-break? "\n \n" #:pattern #px"^\n \n$"))
  (check-true (paragraph-break? "\n\n"))
  (check-true (paragraph-break? "\n\n\n")))


(define/contract (convert-linebreaks xc #:newline [newline "\n"])
  ((xexpr-content?) (#:newline string?) . ->* . xexpr-content?)
  ;; todo: should this test be not block + not whitespace?
  (define not-block? (λ(i) (not (block-xexpr? i))))
  (filter-not empty?
              (for/list ([i (len xc)])
                (let ([item (get xc i)])
                  (cond
                    ;; skip first and last
                    [(or (= i 0) (= i (sub1 (len xc)))) item]
                    [(equal? item newline)                   
                     (match (get xc (- i 1) (+ i 2)) ; a three-element slice with x[i] in the middle
                       ;; only convert if neither adjacent tag is a block
                       ;; (because blocks automatically force a newline before & after)
                       [(list (? not-block?) newline (? not-block?)) '(br)]
                       [else empty])] ; otherwise delete
                    [else item])))))

(module+ test
  (check-equal? (convert-linebreaks '("foo" "\n" "bar")) '("foo" (br) "bar"))
  (check-equal? (convert-linebreaks '("\n" "foo" "\n" "bar" "\n")) '("\n" "foo" (br) "bar" "\n"))
  (check-equal? (convert-linebreaks '((p "foo") "\n" (p "bar"))) '((p "foo") (p "bar")))
  (check-equal? (convert-linebreaks '("foo" "\n" (p "bar"))) '("foo" (p "bar")))
  (check-equal? (convert-linebreaks '("foo" "moo" "bar")) '("foo" "moo" "bar"))
  (check-equal? (convert-linebreaks '("foo" "moo" "bar") #:newline "moo") '("foo" (br) "bar"))
  (check-equal? (convert-linebreaks '("foo" "\n\n" "bar")) '("foo" "\n\n" "bar")))

;; prepare content for paragraph testing
(define/contract (prep-paragraph-flow xc)
  (xexpr-content? . -> . xexpr-content?)
  (convert-linebreaks (merge-newlines (trim xc whitespace?))))

(module+ test
  (check-equal? (prep-paragraph-flow '("\n" "foo" "\n" "\n" "bar" "\n" "ino" "\n"))
                '("foo" "\n\n" "bar" (br) "ino")))

;; apply paragraph tag
(define/contract (wrap-paragraph xc #:tag [tag 'p]) 
  ((xexpr-content?) (#:tag symbol?) . ->* . block-xexpr?)
  (match xc
    [(list (? block-xexpr? bx)) bx] ; leave a single block xexpr alone
    [else (make-named-xexpr tag empty xc)])) ; otherwise wrap in p tag

(module+ test
  (check-equal? (wrap-paragraph '("foo" "bar")) '(p "foo" "bar"))
  (check-equal? (begin (register-block-name 'para) (wrap-paragraph #:tag 'para '("foo" "bar"))) 
                '(para "foo" "bar"))
  (check-equal? (wrap-paragraph '((p "bar" "foo"))) '(p "bar" "foo"))
  (check-equal? (wrap-paragraph '((div "bar" "foo") "Hi" )) '(p (div "bar" "foo") "Hi")))


;; detect paragraphs
;; todo: unit tests
(define/contract (xexpr-content-proc content)
  (xexpr-content? . -> . xexpr-content?)
  (let ([content (prep-paragraph-flow content)]) 
    (if (ormap paragraph-break? content) ; need this condition to prevent infinite recursion
        (map wrap-paragraph (splitf-at* content paragraph-break?)) ; split into ¶¶
        content)))


;; insert nbsp between last two words
(define/contract (nonbreaking-last-space x #:nbsp-char [nbsp #\ ])
  ((named-xexpr?) (#:nbsp-char char?) . ->* . named-xexpr?)
  (define minimum-word-length (add1 5)) ; add1 to account for final punctuation
  ; todo: parameterize this, as it will be different for each project
  (define tags-to-pay-attention-to '(p aside)) ; only apply to paragraphs
  
  (define (replace-last-space str)
    (if (#\space . in . str)
        (let ([reversed-str-list (reverse (string->list str))])
          (define-values (last-word-chars other-chars) 
            (splitf-at reversed-str-list (λ(i) (not (eq? i #\space)))))
          (list->string (reverse (append last-word-chars 
                                         ; OK for long words to be on their own line.
                                         (if (< (len last-word-chars) minimum-word-length)
                                             ; first char of other-chars will be the space, so use cdr
                                             (cons nbsp (cdr other-chars))
                                             other-chars)))))
        str))
  
  (define (find-last-word-space x) ; recursively traverse xexpr
    (cond
      [(string? x) (replace-last-space x)] 
      [(named-xexpr? x) 
       (let-values([(name attr content) (break-named-xexpr x)])
         (if (> (length content) 0) ; content is list of xexprs
             (let-values ([(all-but-last last) (split-at content (sub1 (length content)))]) 
               (make-named-xexpr name attr `(,@all-but-last ,(find-last-word-space (car last)))))
             x))]
      [else x]))
  
  (if ((car x) . in . tags-to-pay-attention-to)
      (find-last-word-space x)
      x))

;; todo: make some tougher tests, it gets flaky with edge cases
(module+ test
  (check-equal? (nonbreaking-last-space '(p "Hi there")) '(p "Hi there")) ; nbsp in between last two words
  (check-equal? (nonbreaking-last-space '(p "Hi there") #:nbsp-char #\Ø) '(p "HiØthere")) ; but let's make it visible
  (check-equal? (nonbreaking-last-space '(p "Hi here" (em "ho there")) #:nbsp-char #\Ø) '(p "Hi here" (em "hoØthere")))) 


; wrap initial quotes for hanging punctuation
; todo: improve this
; does not handle <p>“<em>thing</em> properly
(define/contract (wrap-hanging-quotes nx)
  (named-xexpr? . -> . named-xexpr?)
  (define two-char-string? (λ(i) (and (string? i) (>= (len i) 2))))
  (define-values (name attr content) (break-named-xexpr nx))
  (define new-car-content
    (match (car content)
      [(? two-char-string? str)
       (define str-first (get str 0))
       (define str-rest (get str 1 'end))
       (cond
         [(str-first . in . '("\"" "“"))
          ;; can wrap with any inline tag
          ;; so that linebreak detection etc still works
          `(hang-double-quote ,(->string #\“) ,str-rest)]
         [(str-first . in . '("\'" "‘")) 
          `(hang-single-quote ,(->string #\‘) ,str-rest)]
         [else str])]
      [(? named-xexpr? nx) (wrap-hanging-quotes nx)]
      [else (car content)]))
  (make-named-xexpr name attr (cons new-car-content (cdr content))))


(module+ test
  (check-equal? (wrap-hanging-quotes '(p "\"Hi\" there")) '(p (hang-double-quote "“" "Hi\" there")))
  (check-equal? (wrap-hanging-quotes '(p "'Hi' there")) '(p (hang-single-quote "‘" "Hi' there"))))


(define (block-xexpr-proc bx)
  (named-xexpr? . -> . named-xexpr?)
  (wrap-hanging-quotes (nonbreaking-last-space bx)))


;; insert typographic niceties
;; ligatures are handled in css
(define (typogrify str)
  (string? . -> . string?)
  ;; make set of functions for replacers
  (define (make-replacer query replacement)
    (λ(str) (regexp-replace* query str replacement)))
  
  ;; just store the query strings + replacement strings
  (define dashes 
    ;; fix em dashes first, else they'll be mistaken for en dashes
    ;; [\\s ] is whitespace + nonbreaking space
    '((#px"[\\s ]*(---|—)[\\s ]*" "—") ; em dash
      (#px"[\\s ]*(--|–)[\\s ]*" "–"))) ; en dash
  
  (define smart-quotes
    '((#px"(?<=\\w)'(?=\\w)" "’") ; apostrophe
      (#px"(?<!\\w)'(?=\\w)" "‘") ; single_at_beginning
      (#px"(?<=\\S)'(?!\\w)" "’") ; single_at_end
      (#px"(?<!\\w)\"(?=\\w)" "“") ; double_at_beginning
      (#px"(?<=\\S)\"(?!\\w)" "”"))) ; double_at_end
  
  
  ;; put replacers in desired order here
  (let* ([typogrifiers (append dashes smart-quotes)]
         [queries (map first typogrifiers)]
         [replacements (map second typogrifiers)])
    (define replacers (map make-replacer queries replacements)) 
    ;; compose goes from last to first, so reverse order
    ((apply compose1 (reverse replacers)) str)))


(module+ test
  (check-equal? (typogrify "I had --- maybe 13 -- 20 --- hob-nobs.") "I had—maybe 13–20—hob-nobs.")
  (check-equal? (typogrify "\"Why,\" she could've asked, \"are we in O‘ahu watching 'Mame'?\"") 
                "“Why,” she could’ve asked, “are we in O‘ahu watching ‘Mame’?”"))


(define (string-proc str)
  (string? . -> . string?)
  (typogrify str))


(define (root . items)
  (named-xexpr? . -> . named-xexpr?)
  (decode (cons 'root items)
          ;          #:exclude-xexpr-names 'em
          ;          #:xexpr-name-proc [xexpr-name-proc (λ(x)x)]
          ;          #:xexpr-attr-proc [xexpr-attr-proc (λ(x)x)]
          #:xexpr-content-proc xexpr-content-proc
          #:block-xexpr-proc block-xexpr-proc
          ;          #:inline-xexpr-proc [inline-xexpr-proc (λ(x)x)]
          #:string-proc string-proc
          #:meta-proc meta-proc
          ))


(define foo "bar")