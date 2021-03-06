(defpackage #:apispec/body/parser/multipart
  (:use #:cl)
  (:import-from #:apispec/body/parser/json
                #:parse-json-stream)
  (:import-from #:apispec/body/parser/urlencoded
                #:parse-urlencoded-stream)
  (:import-from #:apispec/utils
                #:slurp-stream
                #:detect-charset)
  (:import-from #:fast-http
                #:make-multipart-parser)
  (:import-from #:flexi-streams)
  (:import-from #:babel)
  (:import-from #:alexandria
                #:starts-with-subseq)
  (:import-from #:cl-utilities
                #:with-collectors)
  (:export #:parse-multipart-stream
           #:parse-multipart-string
           #:*multipart-force-stream*))
(in-package #:apispec/body/parser/multipart)

(defvar *multipart-force-stream* t)

(defun parse-multipart-stream (stream content-type content-length)
  (check-type stream stream)
  (check-type content-type string)
  (check-type content-length (or integer null))
  (let ((results (with-collectors (collect-body collect-headers)
                   (let ((parser (make-multipart-parser
                                   content-type
                                   (lambda (name headers field-meta body)
                                     (declare (ignore field-meta))
                                     (collect-body (cons name
                                                         (if *multipart-force-stream*
                                                             body
                                                             (let ((content-type (gethash "content-type" headers)))
                                                               (cond
                                                                 ((starts-with-subseq "application/json" (string-downcase content-type))
                                                                  (parse-json-stream body content-type nil))
                                                                 ((starts-with-subseq "application/x-www-form-urlencoded" (string-downcase content-type))
                                                                  (parse-urlencoded-stream body nil))
                                                                 ((starts-with-subseq "multipart/" (string-downcase content-type))
                                                                  (parse-multipart-stream body content-type nil))
                                                                 ((starts-with-subseq "application/octet-stream" (string-downcase content-type))
                                                                  body)
                                                                 (t
                                                                  (babel:octets-to-string (slurp-stream body nil)
                                                                                          :encoding (detect-charset content-type))))))))
                                     (collect-headers (cons name headers))))))
                     (if content-length
                         (let ((buffer (make-array content-length :element-type '(unsigned-byte 8))))
                           (read-sequence buffer stream)
                           (funcall parser buffer))
                         (loop with buffer = (make-array 1024 :element-type '(unsigned-byte 8))
                               for read-bytes = (read-sequence buffer stream)
                               do (funcall parser (subseq buffer 0 read-bytes))
                               while (= read-bytes 1024)))))))
    (if (every (lambda (pair) (null (car pair))) results)
        (if (null (rest results))
            ;; Single multipart chunk
            (cdr (first results))
            (mapcar #'cdr results))
        results)))

(defun parse-multipart-string (string content-type)
  (parse-multipart-stream
    (flex:make-in-memory-input-stream (babel:string-to-octets string))
    content-type
    (length string)))
