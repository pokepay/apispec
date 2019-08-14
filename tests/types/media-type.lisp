(defpackage #:apispec/tests/types/media-type
  (:use #:cl
        #:rove
        #:apispec/types/media-type)
  (:import-from #:apispec/types/schema
                #:schema
                #:binary
                #:object)
  (:import-from #:apispec/types/header
                #:header)
  (:import-from #:apispec/types/encoding
                #:encoding)
  (:import-from #:babel
                #:string-to-octets)
  (:import-from #:flexi-streams
                #:make-in-memory-input-stream)
  (:import-from #:cl-interpol))
(in-package #:apispec/tests/types/media-type)

(named-readtables:in-readtable :interpol-syntax)

(deftest parse-tests
  (testing "application/octet-stream"
    (let* ((media-type (make-instance 'media-type
                                      :schema (schema binary)))
           (data (babel:string-to-octets "Hello, API"))
           (stream (flex:make-in-memory-input-stream data)))
      (ok (equal (parse-with-media-type stream media-type "application/octet-stream")
                 data))))
  (testing "application/x-www-form-urlencoded"
    (let* ((media-type (make-instance 'media-type
                                      :schema (schema (object
                                                        (("id" integer)
                                                         ("address" string))))))
           (data (babel:string-to-octets "id=1&address=Tokyo,%20Japan"))
           (stream (flex:make-in-memory-input-stream data)))
      (ok (equal (parse-with-media-type stream media-type "application/x-www-form-urlencoded")
                 '(("id" . 1) ("address" . "Tokyo, Japan"))))))
  (testing "multipart"
    (let* ((media-type (make-instance 'media-type
                                      :schema (schema (object
                                                        (("id" integer)
                                                         ("address" string)
                                                         ("historyMetadata" object))))
                                      :encoding `(("historyMetadata"
                                                   . ,(make-instance 'encoding
                                                                     :content-type "application/json")))))
           (content-type "multipart/form-data; boundary=\"---------------------------186454651713519341951581030105\"")
           (data (babel:string-to-octets
                   (concatenate 'string
                                #?"-----------------------------186454651713519341951581030105\r\n"
                                #?"Content-Disposition: form-data; name=\"id\"\r\n"
                                #?"Content-Type: text/plain\r\n"
                                #?"\r\n"
                                #?"1\r\n"
                                #?"-----------------------------186454651713519341951581030105\r\n"
                                #?"Content-Disposition: form-data; name=\"address\"\r\n"
                                #?"Content-Type: text/plain\r\n"
                                #?"\r\n"
                                #?"東京都台東区上野２丁目７−１２\r\n"
                                #?"-----------------------------186454651713519341951581030105\r\n"
                                #?"Content-Disposition: form-data; name=\"historyMetadata\"\r\n"
                                #?"Content-Type: application/json\r\n"
                                #?"\r\n"
                                #?"{\"type\":\"culture\"}\r\n"
                                #?"-----------------------------186454651713519341951581030105--\r\n")))
           (stream (flex:make-in-memory-input-stream data)))
      (ok (equal (parse-with-media-type stream media-type content-type)
                 '(("id" . 1)
                   ("address" . "東京都台東区上野２丁目７−１２")
                   ("historyMetadata" . (("type" . "culture")))))))))