;; jabber-ft-server.el - handle incoming file transfers, by JEP-0096
;; $Id: jabber-ft-server.el,v 1.2 2004/04/11 21:01:59 legoscia Exp $

;; Copyright (C) 2002, 2003, 2004 - tom berger - object@intelectronica.net
;; Copyright (C) 2003, 2004 - Magnus Henoch - mange@freemail.hu

;; This file is a part of jabber.el.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

(require 'jabber-si-server)
(require 'jabber-util)

(defvar jabber-ft-sessions nil
  "Alist, where keys are (sid jid), and values are buffers of the files.")

(add-to-list 'jabber-advertised-features "http://jabber.org/protocol/si/profile/file-transfer")

(add-to-list 'jabber-si-profiles
	     (list "http://jabber.org/protocol/si/profile/file-transfer"
		   'jabber-ft-accept
		   'jabber-ft-start))

(defun jabber-ft-accept (xml-data)
  "Receive IQ stanza containing file transfer request, ask user"
  (let* ((from (jabber-xml-get-attribute xml-data 'from))
	 (query (jabber-iq-query xml-data))
	 (si-id (jabber-xml-get-attribute query 'id))
	 ;; TODO: check namespace
	 (file (car (jabber-xml-get-children query 'file)))
	 (name (jabber-xml-get-attribute file 'name))
	 (size (jabber-xml-get-attribute file 'size))
	 (date (jabber-xml-get-attribute file 'date))
	 (md5-hash (jabber-xml-get-attribute file 'hash))
	 (desc (car (jabber-xml-node-children
		     (car (jabber-xml-get-children file 'desc)))))
	 (range (car (jabber-xml-get-children file 'range))))
    (unless (and name size)
      ;; both name and size must be present
      (jabber-signal-error "modify" 'bad-request))

    (let ((question (format
		     "%s is sending you the file %s (%s bytes).%s  Accept? "
		     (jabber-jid-displayname from)
		     name
		     size
		     (if (not (zerop (length desc)))
			 (concat "  Description: '" desc "'")
		       ""))))
      (unless (yes-or-no-p question)
	(jabber-signal-error "cancel" 'forbidden)))

    ;; default is to save with given name, in current directory.
    ;; maybe that's bad; maybe should be customizable.
    (let* ((file-name (read-file-name "Download to: " nil nil nil name))
	   (buffer (find-file-noselect file-name t t)))
      (add-to-list 'jabber-ft-sessions
		   (cons (list si-id from) buffer)))
      
    ;; to support range, return something sensible here
    nil))

(defun jabber-ft-start (jid sid stream-read-function)
  "Fetch file from other user.
JID is JID of other user.  SID is stream ID.  STREAM-READ-FUNCTION
is function to call to get more data."
  (let ((buffer (cdr (assoc (list sid jid) jabber-ft-sessions)))
	data)
    (with-current-buffer buffer
      (goto-char (point-max))
      (while (setq data (funcall stream-read-function jid sid))
	(insert data)))))

(provide 'jabber-ft-server)
