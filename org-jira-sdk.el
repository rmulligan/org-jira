;;; org-jira-sdk.el -- SDK Layer for entities

;; Copyright (C) 2018 Matthew Carter <m@ahungry.com>
;;
;; Authors:
;; Matthew Carter <m@ahungry.com>
;;
;; Maintainer: Matthew Carter <m@ahungry.com>
;; URL: https://github.com/ahungry/org-jira
;; Version: 3.1.1
;; Keywords: ahungry jira org bug tracker
;; Package-Requires: ((emacs "24.5") (cl-lib "0.5") (request "0.2.0") (s "0.0.0"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/> or write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;; 02110-1301, USA.

;;; Commentary:

;; This provides an SDK wrapper for more strictly defining the entities we interact with.

;;; Code:

(require 'jiralib)
(require 'cl-lib)
(require 's)
(require 'eieio)
(require 'dash)

(defclass org-jira-sdk-record ()
  ((id :initarg :id :type string :required t)
   (data :initarg :data :documentation "The area to hold a big alist of data.")
   (hydrate-fn :initform (lambda (id) (message "Not implemented."))))
  "The ID of the record.")

(defun org-jira-sdk-string-but-first (s) (cl-subseq s 1))

(defun org-jira-sdk-to-string (s) (format "%s" s))

(defun org-jira-sdk-to-prefixed-string (s) (format "org-jira-sdk-%s" s))

(defun org-jira-sdk-record-type-to-symbol (record-type)
  (-> record-type symbol-name org-jira-sdk-string-but-first org-jira-sdk-to-prefixed-string intern))

(defun org-jira-sdk-create-from-id (record-type id &optional callback)
  (let ((rec (funcall (org-jira-sdk-record-type-to-symbol record-type) :id (format "%s" id))))
    (with-slots (data) rec
      (setf data (org-jira-sdk-hydrate rec callback)))))

(defun org-jira-sdk-create-from-data (record-type data)
  (let ((rec (funcall (org-jira-sdk-record-type-to-symbol record-type) :data data)))
    (org-jira-sdk-from-data rec)))

(defun org-jira-sdk-create-record-from-data (record-type)
  (lambda (data) (org-jira-sdk-create-from-data record-type data)))

(cl-defmethod org-jira-sdk-hydrate ((rec org-jira-sdk-record) &optional callback)
  "Populate the record with data from the remote endpoint."
  (with-slots (id hydrate-fn) rec
    (funcall hydrate-fn id callback)))

(cl-defmethod org-jira-sdk-from-data ((rec org-jira-sdk-record)))

(cl-defmethod org-jira-sdk-dump ((rec org-jira-sdk-record))
  "A decent pretty print/object dump for working with the class items."
  (let ((slots (mapcar (lambda (slot) (aref slot 1)) (eieio-class-slots 'org-jira-sdk-issue))))
    (setq slots (cl-remove-if (lambda (s) (not (slot-boundp rec s))) slots))
    (apply #'concat
     (mapcar (lambda (slot)
               (let ((slot (intern (org-jira-sdk-to-string slot))))
                 (format "\n%+16s:   %s" slot (slot-value rec (intern (org-jira-sdk-to-string slot)))))
               )
             slots))))

(defun org-jira-sdk-path (alist key-chain)
  "Query a nested path in some type of ALIST by traversing down the keys of KEY-CHAIN."
  (cl-reduce (lambda (a k) (alist-get k a)) key-chain :initial-value alist))

(defclass org-jira-sdk-issue (org-jira-sdk-record)
  ((assignee :type string :initarg :assignee)
   (components :type string :initarg :components)
   (created :type string :initarg :created)
   (description :type string :initarg :description)
   (duedate :type string :initarg :duedate)
   (headline :type string :initarg :headline)
   (id :type string :initarg :id)
   (issue-id :type string :initarg :issue-id)
   (priority :type string :initarg :priority)
   (proj-key :type string :initarg :proj-key)
   (reporter :type string :initarg :reporter)
   (resolution :type string :initarg :resolution)
   (start-date :type string :initarg :start-date)
   (status :type string :initarg :status)
   (summary :type string :initarg :summary)
   (type :type string :initarg :type)
   (updated :type string :initarg :updated)
   (data :initarg :data :documentation "The remote Jira data object (alist).")
   (hydrate-fn :initform #'jiralib-get-issue :initarg :hydrate-fn))
  "An issue on the end.  ID of the form EX-1, or a numeric such as 10000.")

(cl-defmethod org-jira-sdk-from-data ((rec org-jira-sdk-issue))
  (with-slots (data proj-key issue-id) rec
    (flet ((path (keys) (org-jira-sdk-path data keys)))
      (org-jira-sdk-issue
       :assignee (path '(fields assignee)) ; confirm
       :components (mapconcat (lambda (c) (org-jira-sdk-path c '(name))) (path '(fields components)) ", ")
       :created (path '(fields created))   ; confirm
       :description (path '(fields description)) ; confirm
       :duedate (path '(fields duedate))         ; confirm
       :headline (path '(fields summary)) ; Duplicate of summary, maybe different.
       :id (path '(key))
       :issue-id (path '(id))
       :priority (path '(fields priority name))
       :proj-key (path '(fields project key))
       :reporter (path '(fields reporter)) ; confirm
       :resolution (path '(fields resolution)) ; confirm
       :start-date (path '(fields start-date)) ; confirm
       :status (org-jira-decode (path '(fields status name)))
       :summary (path '(fields summary))
       :type (path '(fields issuetype name))
       :updated (path '(fields updated)) ; confirm
       :data data        ; TODO: stop gap, eventually we can drop this
       ))))

(defun org-jira-sdk-create-issue-from-data (d) (org-jira-sdk-create-from-data :issue d))

(defun org-jira-sdk-create-issues-from-data-list (ds) (mapcar #'org-jira-sdk-create-issue-from-data ds))

(provide 'org-jira-sdk)
;;; org-jira-sdk.el ends here