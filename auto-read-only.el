;;; auto-read-only.el --- Automatically activate read-only-mode  -*- lexical-binding: t; -*-

;; Copyright (C) 2017 USAMI Kenta
;; Copyright (C) 2026 Abdulnafé Toulaïmat

;; Author: USAMI Kenta <tadsan@zonu.me>,
;;         Abdulnafé Toulaïmat <abdulnafe.toulaimat@gmail.com>
;; Created: 4 Mar 2017
;; Version: 0.1.0
;; Keywords: files, convenience
;; Homepage: https://github.com/zonuexe/auto-read-only.el
;; Package-Requires: ((emacs "27.1") (cl-lib "0.5"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Automatically activate `read-only-mode' in file-viewing buffers, if those files’ names
;; match one of the regexps in `auto-read-only-file-regexps'. For example, this can be
;; used to protect library code provided by third parties.
;;
;; Setup:
;;
;; put into your =.emacs= file (=init.el=)
;;
;;     (require 'auto-read-only)
;;     (auto-read-only-mode 1)
;;
;;
;; Or, with `use-package':
;;
;;     (use-package auto-read-only
;;       :init
;;       (auto-read-only-mode 1))
;;
;; Customize:
;;
;;     ;; Automatically activate `read-only-mode' in /vendor/ directories
;;     (add-to-list 'auto-read-only-file-regexps "/vendor/")
;;

;;; Code:

(require 'cl-lib)
(eval-when-compile
  (require 'regexp-opt)
  (require 'rx))

(defgroup auto-read-only ()
  "Automatically activate `read-only-mode'."
  :prefix "auto-read-only-"
  :group 'editing)

(defcustom auto-read-only-file-regexps
  (list (concat (regexp-opt '(".elc" ".pyc")) "\\'")                        ; byte-compiled code
        (rx "/share/" (+ nonl) "/site-lisp/")                               ; (maybe system wide) emacs bundled lisp directory
        (rx (literal (expand-file-name user-emacs-directory)) "el-get" "/") ; user’s `el-get' package directory
        (rx (literal (expand-file-name package-user-dir)))                  ; user’s package directory
        (rx "/" (or ".bundle" ".cask") "/")                                 ; project specific bundled packages
        )
  "List of filename regexp patterns to enable `read-only-mode' in."
  :type '(repeat regexp))

(defcustom auto-read-only-function nil
  "Function to call to make buffers read-only. The default value, nil,
means to use `read-only-mode'.

`view-mode' stands out as another possibility. If you want to use that,
however, consider setting the builtin variable `view-read-only' to a
non-nil value instead."
  :type '(choice (const    :tag "Unspecified (default to use `read-only-mode')" nil)
                 (function :tag "Arbitrary function/minor-mode analogous to read-only.")))

(defcustom auto-read-only-protect-projects nil
  "Nil (the default) means to let buffers visiting project files be
editable, even if they would otherwise match
`auto-read-only-file-regexps'.

Non-nil means to treat such buffers like any other."
  :type 'boolean)

(defvar auto-read-only-mode-lighter " AutoRO")

(defun auto-read-only--maybe-activate (window-or-frame)
  "Activate `auto-read-only' in the buffer displayed in WINDOW-OR-FRAME, if
appropriate.

The fact that the buffer is being viewed by WINDOW-OR-FRAME means that
it has not been visited programmatically, and so lisp code that visits
files non-interactively should be unaffected.

When `auto-read-only-mode' is enabled, this function is added to
`window-buffer-change-functions', which see."

  (let ((buffer (cond
                 ((windowp window-or-frame)
                  (window-buffer window-or-frame))

                 ((framep window-or-frame)
                  (window-buffer (frame-selected-window window-or-frame))))))
    (with-current-buffer buffer
      (auto-read-only))))

;;;###autoload
(define-minor-mode auto-read-only-mode
  "Minor mode that automatically activates `read-only-mode' in certain buffers.

The conditions to enable `read-only-mode' in a given buffer are:
1) the buffer must be visiting a file, and
2) that file’s name must match one of the regexps in `auto-read-only-file-regexps', which see.

Files that are part of a project may be exempt from this based on the
user option `auto-read-only-protect-projects', which see."

  :init-value nil
  :lighter auto-read-only-mode-lighter
  :keymap nil
  :global t
  (if auto-read-only-mode
      (add-hook 'window-buffer-change-functions #'auto-read-only--maybe-activate )
    (remove-hook 'window-buffer-change-functions #'auto-read-only--maybe-activate)))

;;;###autoload
(defun auto-read-only ()
  "Activate `read-only-mode' in the current buffer.

Specifically, activate read-only mode if the current buffer is visiting
 a file which matches one of the regexps in
 `auto-read-only-file-regexps'.

Files that are part of a project are exempt if
 `auto-read-only-protect-projects' is nil (the default)."

  (when (and buffer-file-name
             (cl-loop for regexp in auto-read-only-file-regexps
                      thereis (string-match-p regexp buffer-file-name))
             (or auto-read-only-protect-projects
                 (not (project-current))))
    (if auto-read-only-function
        (funcall auto-read-only-function)
      (read-only-mode 1))))

(provide 'auto-read-only)
;;; auto-read-only.el ends here
