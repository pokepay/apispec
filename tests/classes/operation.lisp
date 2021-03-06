(defpackage #:apispec/tests/classes/operation
  (:use #:cl
        #:rove
        #:apispec/classes/operation)
  (:import-from #:apispec/classes/schema
                #:schema
                #:object)
  (:import-from #:apispec/classes/parameter
                #:parameter)
  (:import-from #:apispec/classes/response
                #:response)
  (:import-from #:apispec/classes/media-type
                #:media-type)
  (:import-from #:lack.request
                #:request-query-parameters
                #:request-cookies)
  (:import-from #:lack.response
                #:make-response)
  (:import-from #:assoc-utils
                #:alist-hash))
(in-package #:apispec/tests/classes/operation)

(defun make-operation (parameters)
  (make-instance 'operation
                 :parameters parameters
                 :responses
                 `(("204" . ,(make-instance 'response
                                            :description "Success"
                                            :content nil)))))

(deftest validate-request-tests
  (testing "path"
    (let* ((operation (make-operation
                        (list
                          (make-instance 'parameter
                                         :name "car_id"
                                         :in "path"
                                         :schema (schema integer))
                          (make-instance 'parameter
                                         :name "driver_id"
                                         :in "path"
                                         :schema (schema string)))))
           (request (validate-request operation
                                      ()
                                      :path-parameters '(("car_id" . "1")
                                                         ("driver_id" . "xyz")))))
      (ok (typep request 'request))
      (ok (equalp (request-path-parameters request)
                  '(("car_id" . 1)
                    ("driver_id" . "xyz"))))))
  (testing "query"
    (let* ((operation (make-operation
                        (list
                          (make-instance 'parameter
                                         :name "role"
                                         :in "query"
                                         :schema (schema string))
                          (make-instance 'parameter
                                         :name "debug"
                                         :in "query"
                                         :schema (schema boolean)))))
           (request (validate-request operation
                                      '(:query-string "role=admin&debug=0"))))
      (ok (typep request 'request))
      (ok (equalp (request-query-parameters request)
                  '(("role" . "admin")
                    ("debug" . nil))))))
  (testing "header"
    (let* ((operation (make-operation
                        (list
                          (make-instance 'parameter
                                         :name "X-App-Version"
                                         :in "header"
                                         :schema (schema integer)))))
           (request (validate-request operation
                                      (list
                                        :headers (alist-hash
                                                   `(("x-app-version" . "3")))))))
      (ok (typep request 'request))
      (ok (equalp (request-header-parameters request)
                  '(("X-App-Version" . 3))))))
  (testing "cookie"
    (let* ((operation (make-operation
                        (list
                          (make-instance 'parameter
                                         :name "debug"
                                         :in "cookie"
                                         :schema (schema boolean))
                          (make-instance 'parameter
                                         :name "csrftoken"
                                         :in "cookie"
                                         :schema (schema string)))))
           (request (validate-request operation
                                      (list
                                        :headers (alist-hash
                                                   `(("cookie" . "debug=0; csrftoken=BUSe35dohU3O1MZvDCU")))))))
      (ok (typep request 'request))
      (ok (equalp (request-cookies request)
                  '(("debug" . nil)
                    ("csrftoken" . "BUSe35dohU3O1MZvDCU")))))))

(deftest validate-response-tests
  (let* ((media-type (make-instance 'media-type
                                    :schema (schema (object (("hello" string))))))
         (200-response (make-instance 'response
                                      :description "Success"
                                      :content `(("application/json" . ,media-type)))))
    (testing "200 OK (application/json)"
      (let ((operation (make-instance 'operation
                                      :parameters nil
                                      :responses
                                      `(("200" . ,200-response)))))
        (ok (equal (validate-response operation
                                      (make-response 200
                                                     '(:content-type "application/json; charset=utf-8")
                                                     '(("hello" . "こんにちは"))))
                   '(200 (:content-type "application/json; charset=utf-8") ("{\"hello\":\"こんにちは\"}"))))))
    (testing "204 No Content"
      (let* ((response (make-instance 'response
                                      :description "No Content"
                                      :content nil))
             (operation (make-instance 'operation
                                       :parameters nil
                                       :responses `(("204" . ,response)
                                                    ("2XX" . ,200-response)))))
        (ok (equal (validate-response operation
                                      (make-response 204))
                   '(204 () ())))))))
