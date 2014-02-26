#lang web-server
(require web-server/servlet-env 
         web-server/dispatch)
(require "server-routes.rkt" 
         "debug.rkt" 
         "world.rkt"
         "file-tools.rkt"
         "cache.rkt")

(define-values (pollen-servlet _)
  (dispatch-rules
   [((string-arg) ... (? (λ(x) (x . has-ext? . world:ptree-source-ext)))) route-dashboard]
   [((string-arg) ... "in" (string-arg)) route-in]
   [((string-arg) ... "out" (string-arg)) route-out]
   [((string-arg) ... "xexpr" (string-arg)) route-xexpr]
   [else route-default]))

(message (format "Welcome to Pollen ~a" world:pollen-version) (format "(Racket ~a)" (version)))
(message (format "Project root is ~a" (world:current-project-root)))

(define server-name (format "http://localhost:~a" world:server-port))
(message (format "Project server is ~a" server-name) "(Ctrl-C to exit)")
(message (format "Project dashboard is ~a/~a" server-name world:dashboard-name))

(message "Ready to rock")

(world:current-module-root (apply build-path (drop-right (explode-path (current-contract-region)) 1)))
(world:current-server-extras-path (build-path (world:current-module-root) "pollen-server-extras"))

(parameterize ([world:current-module-root (world:current-module-root)]
               [world:current-server-extras-path (world:current-server-extras-path)]
               [current-cache (make-cache)])
  (serve/servlet pollen-servlet
                 #:port world:server-port
                 #:listen-ip #f
                 #:servlet-regexp #rx"" ; respond to top level
                 #:command-line? #t
                 #:file-not-found-responder route-404
                 #:extra-files-paths (list (world:current-server-extras-path) (world:current-project-root))))