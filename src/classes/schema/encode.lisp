(defpackage #:apispec/classes/schema/encode
  (:use #:cl)
  (:shadowing-import-from #:apispec/classes/schema/core
                          #:make-schema
                          #:schema-nullable-p
                          #:boolean
                          #:object
                          #:object-properties
                          #:property-name
                          #:property-type
                          #:parse-schema-definition)
  (:import-from #:jonathan)
  (:export #:encode-data))
(in-package #:apispec/classes/schema/encode)

(defgeneric encode-data (value schema)
  (:method (value schema)
    (jojo:with-output-to-string*
      (jojo:%to-json (if (and (null value)
                              (schema-nullable-p schema))
                         :null
                         value))))
  (:method (value (schema symbol))
    (encode-data value (make-schema schema)))
  (:method (value (schema cons))
    (encode-data value
                 (multiple-value-bind (type args)
                     (parse-schema-definition schema)
                   (apply #'make-schema type args)))))

(defmethod encode-data (value (schema boolean))
  (jojo:with-output-to-string*
    (jojo:%to-json (if value
                       t
                       :false))))

(defmethod encode-data (value (schema object))
  (jojo:with-output-to-string*
    (jojo:with-object
      (loop for prop in (object-properties schema)
            for (key . field-value) = (find (property-name prop)
                                            value
                                            :key #'car
                                            :test #'equal)
            when key
            do (jojo:write-key (cl:string key))
            (jojo:%write-char #\:)
            (jojo:%write-string (encode-data field-value (property-type prop)))))))
