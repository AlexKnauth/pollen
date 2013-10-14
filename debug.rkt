#lang racket/base
(require racket/date)
(require racket/string)
(require racket/format)


(provide (all-defined-out))

; todo: contracts, tests, docs

(require (prefix-in williams: (planet williams/describe/describe)))

(define (describe x)
  (williams:describe x)
  x)

; debug utilities
(define months (list "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))

(define last-message-time #f)
(define (seconds-since-last-message)
  (define now (current-seconds))
  (define then last-message-time)
  (set! last-message-time now)
  (if then      
    (- now then)
    "--"))


(define (message . items)
  (define (zero-fill str count)
    (set! str (~a str))
    (if (> (string-length str) count)
        str
        (string-append (make-string (- count (string-length str)) #\0) str)))
  
  (define (make-date-string)
    (define date (current-date))
    (define date-fields (map (λ(x) (zero-fill x 2)) 
                             (list
                              ; (date-day date)
                              ; (list-ref months (sub1 (date-month date)))
                              (if (<= (date-hour date) 12)
                                  (date-hour date) ; am hours + noon hour
                                  (modulo (date-hour date) 12)) ; pm hours after noon hour
                              (date-minute date)
                              (date-second date)
                              ;   (if (< (date-hour date) 12) "am" "pm")
                              (seconds-since-last-message)
                              )))  
    (apply format "[~a:~a:~a ~as]" date-fields))
  (displayln (string-join `(,(make-date-string) ,@(map (λ(x)(if (string? x) x (~v x))) items))) (current-error-port)))


; report the current value of the variable, then return it
(define-syntax-rule (report var)
  (begin 
    (message 'var "=" var) 
    var))