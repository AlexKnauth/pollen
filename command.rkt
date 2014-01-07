#lang racket

;; todo: add command to check validity of installation

(require (for-syntax "readability.rkt" "world.rkt"))

(define-syntax (handle-pollen-command syntax-context)
  (datum->syntax syntax-context
                 (let* ([args (current-command-line-arguments)]
                        [arg (if (> (len args) 0) (get args 0) "")])
                   (display (format "~a: " POLLEN_COMMAND_FILE))
                   (case arg
                     [("start") `(require "server.rkt")]
                     [("render") `(begin
                                        ;; todo: take extensions off the comand line
                                        (displayln "Render preproc & ptree files ...")
                                        (require "render.rkt" "file-tools.rkt" "world.rkt")
                                        (apply render-with-session (append-map project-files-with-ext (list POLLEN_PREPROC_EXT POLLEN_TREE_EXT))))]
                     [("clone") (let ([target-path 
                                       (if (> (len args) 1)
                                           (->path (get args 1))
                                           (build-path (find-system-path 'desk-dir) (->path "clone")))])
                                  `(begin
                                     (displayln "Clone & prune ...")
                                     (require racket/file)
                                     (require "tools.rkt")
                                     
                                     (define (pollen-related-file? file)
                                       (ormap (λ(proc) (proc file)) (list
                                                                     pollen-source? 
                                                                     preproc-source? 
                                                                     template-source?
                                                                     ptree-source?
                                                                     pollen-script?
                                                                     magic-directory?
                                                                     racket-file?)))
                                     
                                     (define (delete-it path)
                                       (when (directory-exists? path)
                                         (delete-directory/files path))
                                       (when (file-exists? path)
                                         (delete-file path)))
                                     
                                     (let ([source-dir (current-directory)]
                                           [target-dir ,target-path])
                                       (when (directory-exists? target-dir)
                                         (delete-directory/files target-dir))
                                       (copy-directory/files source-dir target-dir)
                                       (map delete-it (find-files pollen-related-file? target-dir))
                                       (displayln (format "Completed to ~a" ,target-path))
                                       )))]
                     [("") `(displayln "No command given")]
                     ;; treat other input as a possible file name for rendering
                     [else (let ([possible-file (->path arg)])
                             (if (file-exists? possible-file)
                                 `(begin
                                    (require (planet mb/pollen/render))
                                    (render ,possible-file))
                                 `(displayln (format "No command defined for '~a'" ,arg))))]))))

(handle-pollen-command)
