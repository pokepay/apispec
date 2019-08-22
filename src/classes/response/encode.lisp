(defpackage #:apispec/classes/response/encode
  (:use #:cl
        #:apispec/utils
        #:apispec/classes/response/errors)
  (:import-from #:apispec/classes/response/class
                #:response
                #:responses
                #:response-content
                #:response-headers)
  (:import-from #:apispec/classes/media-type
                #:media-type-schema)
  (:import-from #:apispec/classes/schema
                #:validate-data
                #:schema-error)
  (:import-from #:apispec/classes/header
                #:header-schema)
  (:import-from #:apispec/body
                #:encode-data
                #:body-encode-error)
  (:import-from #:cl-ppcre)
  (:import-from #:alexandria
                #:starts-with-subseq)
  (:import-from #:assoc-utils
                #:aget)
  (:export #:response-not-defined
           #:find-response
           #:find-media-type
           #:encode-response))
(in-package #:apispec/classes/response/encode)

(defun find-response (responses status)
  (check-type responses responses)
  (or (aget responses (princ-to-string status))
      (aget responses (format nil "~DXX" (floor (/ status 100))))
      (aget responses "default")
      (error 'response-not-defined
             :code status)))

(defun find-media-type (response content-type)
  (check-type response response)
  (check-type content-type string)
  (cdr (or (find-if (lambda (media-type-string)
                      (starts-with-subseq media-type-string content-type))
                    (response-content response)
                    :key #'car)
           (find-if (lambda (media-type-string)
                      (and (not (string= media-type-string "*/*"))
                           (match-content-type media-type-string content-type)))
                    (response-content response)
                    :key #'car)
           (find "*/*" (response-content response)
                 :key #'car
                 :test #'string=)
           (error 'response-not-defined
                  :content-type content-type))))

(defun default-content-type (data)
  (cond
    ((association-list-p data 'string t)
     "application/json")
    ((typep data '(vector (unsigned-byte 8)))
     "application/octet-stream")
    (t "text/plain")))

(defun encode-response (status headers data responses)
  (check-type status (integer 100 599))
  (assert (association-list-p headers 'string t))
  (check-type responses responses)
  (let* ((content-type (aget headers "content-type"))
         (content-type (or (and (stringp content-type)
                                (ppcre:scan-to-strings "[^;\\s]+" content-type))
                           (default-content-type data)))
         (response (find-response responses status)))
    (list status
          (loop for (header-name . header-value) in headers
                for response-header = (aget (response-headers response)
                                            (string-downcase header-name))
                if header-value
                append (list (intern (string-upcase header-name) :keyword)
                             (if response-header
                                 (progn
                                   (handler-case
                                       (validate-data header-value (header-schema response-header))
                                     (schema-error ()
                                       (error 'response-header-validation-failed
                                              :name header-name
                                              :value header-value
                                              :header response-header)))
                                   (if (or (listp header-value)
                                           (vectorp header-value))
                                       (format nil "~{~A~^, ~}" (coerce header-value 'list))
                                       header-value))
                                 header-value)))
          (if (null (response-content response))
              (if data
                  (error 'response-body-not-allowed
                         :code status)
                  nil)
              (let ((media-type (find-media-type response content-type)))
                (list (let ((schema (or (and media-type
                                             (media-type-schema media-type))
                                        t)))
                        (handler-case
                            (encode-data data schema content-type)
                          (body-encode-error (e)
                            (error 'response-validation-failed
                                   :value data
                                   :schema schema
                                   :content-type content-type
                                   :reason (princ-to-string e)))))))))))
