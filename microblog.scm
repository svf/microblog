#!/usr/bin/env csi -script

;;; microblog.scm — a minimal plaintext microblog in Chicken Scheme
;;;
;;; Usage:
;;;   csi -script microblog.scm <file> [post text ...]
;;;   csi -script microblog.scm <file>          ; reads post text from stdin
;;;
;;; File format:
;;;   Everything above the first line that is exactly "---" is the HEADER
;;;   and is never touched.  Everything below it is the entry log.
;;;   Each entry is a single line:
;;;
;;;       YYYY-MM-DD HH:MM:SS | your post text here
;;;
;;;   New entries are prepended so the log is always newest-first.
;;;
;;; Syncing:
;;;   scp  blog.txt  user@host:public/blog.txt
;;;   rsync -az blog.txt  user@host:public/
;;;   sftp> put blog.txt
;;;
;;; Creating a new blog file:
;;;   The first time you run the program against a non-existent file it is
;;;   created with a minimal default header.  Edit the header by hand; the
;;;   program will never touch anything above ---.

(import (chicken io)
        (chicken time)
        (chicken time posix)
        (chicken string)
        (chicken process-context)
        (chicken port)
        (chicken file))

;;; ──────────────────────────────────────────────── string utilities (no srfi) ──

(define (string-trim-right str)
  (let loop ((i (- (string-length str) 1)))
    (cond
      ((< i 0) "")
      ((char-whitespace? (string-ref str i)) (loop (- i 1)))
      (else (substring str 0 (+ i 1))))))

(define (string-join strs sep)
  (if (null? strs)
      ""
      (let loop ((rest (cdr strs)) (acc (car strs)))
        (if (null? rest)
            acc
            (loop (cdr rest) (string-append acc sep (car rest)))))))

;;; ─────────────────────────────────────────────────────────────── constants ──

(define +separator+ "---")

(define +default-header+
  (list "Microblog"
        "Edit this header freely — it will never be altered by the program."
        +separator+))

;;; ──────────────────────────────────────────────────────────────── file I/O ──

(define (read-lines path)
  (call-with-input-file path
    (lambda (port)
      (let loop ((acc '()))
        (let ((line (read-line port)))
          (if (eof-object? line)
              (reverse acc)
              (loop (cons line acc))))))))

(define (write-lines path lines)
  (call-with-output-file path
    (lambda (port)
      (for-each (lambda (line)
                  (display line port)
                  (newline port))
                lines))))

;;; ─────────────────────────────────────────────────────────────── parsing ───

;; Split a list of lines into (header . entries) at the first "---" line.
;; If no separator exists, treat everything as the header and entries as '().
(define (split-at-separator lines)
  (let loop ((before '()) (rest lines))
    (cond
      ((null? rest)
       (cons (reverse before) '()))
      ((string=? (car rest) +separator+)
       (cons (reverse before) (cdr rest)))
      (else
       (loop (cons (car rest) before) (cdr rest))))))

;;; ──────────────────────────────────────────────────────────── timestamp ────

(define (zero-pad n)
  (if (< n 10)
      (string-append "0" (number->string n))
      (number->string n)))

(define (current-timestamp)
  (let* ((t     (seconds->local-time (current-seconds)))
         (sec   (vector-ref t 0))
         (min   (vector-ref t 1))
         (hour  (vector-ref t 2))
         (day   (vector-ref t 3))
         (month (+ 1 (vector-ref t 4)))
         (year  (+ 1900 (vector-ref t 5))))
    (string-append
     (number->string year) "-" (zero-pad month) "-" (zero-pad day)
     " "
     (zero-pad hour) ":" (zero-pad min) ":" (zero-pad sec))))

;;; ────────────────────────────────────────────────────────────────── main ───

(define (die msg)
  (display msg (current-error-port))
  (newline (current-error-port))
  (exit 1))

(define (usage!)
  (die (string-append
        "Usage: microblog.scm <blog-file> [post text ...]\n"
        "       microblog.scm <blog-file>    # reads post from stdin\n"
        "\n"
        "  The blog file is created with a default header if it does not exist.\n"
        "  Lines above --- are the header and are never modified.\n"
        "  New entries are prepended below --- in newest-first order.")))

(define (get-post-text rest-args)
  (if (null? rest-args)
      ;; Interactive / piped input
      (begin
        (when (terminal-port? (current-input-port))
          (display "Post: ")
          (flush-output))
        (let ((line (read-line)))
          (if (eof-object? line)
              (die "No post text supplied.")
              (string-trim-right line))))
      ;; Args joined with spaces
      (string-join rest-args " ")))

(define (main)
  (let ((args (command-line-arguments)))
    (when (null? args) (usage!))
    (let* ((file      (car args))
           (rest-args (cdr args))
           (post-text (get-post-text rest-args))
           ;; Load existing file or start from the default header skeleton
           (raw-lines (if (file-exists? file)
                          (read-lines file)
                          +default-header+))
           (parts     (split-at-separator raw-lines))
           (header    (car parts))
           (entries   (cdr parts))
           ;; Build the new entry line
           (new-entry (string-append (current-timestamp) " | " post-text))
           ;; Reassemble: header | --- | new entry | old entries
           (output    (append header
                              (list +separator+)
                              (list new-entry)
                              entries)))
      (write-lines file output)
      (display (string-append "posted: " new-entry "\n")))))

(main)
