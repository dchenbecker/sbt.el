;; Support for running sbt in inferior mode.

(eval-when-compile (require 'cl))
(require 'tool-bar)
(require 'compile)
(require 'comint)
(require 'unit-test nil t)

(defgroup sbt nil
  "Run SBT REPL as inferior of Emacs, parse error messages."
  :group 'tools
  :group 'processes)

(defconst sbt-copyright    "Copyright (C) 2008 Raymond Paul Racine")
(defconst sbt-copyright-2  "Portions Copyright (C) Free Software Foundation")

(defconst sbt-authors-name  '("Luke Amdor" "Raymond Racine"))
(defconst sbt-authors-email '("luke.amdor@gmail.com" "ray.racine@gamail.com"))

(defconst sbt-legal-notice
  "This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation; either version 2, or (at your option) any later version.  This is
distributed in the hope that it will be useful, but without any warranty;
without even the implied warranty of merchantability or fitness for a
particular purpose.  See the GNU General Public License for more details.  You
should have received a copy of the GNU General Public License along with Emacs;
see the file `COPYING'.  If not, write to the Free Software Foundation, Inc.,
59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.")

(defgroup sbt nil
  "Support for sbt build REPL."
  :group  'sbt
  :prefix "sbt-")

(defcustom sbt-program-name "sbt"
  "Program invoked by the `run-sbt' command."
  :type 'string
  :group 'sbt)

(defcustom sbt-use-ui nil
  "Use unit-test to show failure/success in mode line"
  :group 'sbt
  :type 'boolean)

(defun sbt-update-ui (status)
  (if sbt-use-ui
      (mapcar (lambda (buffer)
                (with-current-buffer buffer
                  (if (eq status 'quit)
                      (show-test-none)
                    (show-test-status status))))
              (remove-if 'minibufferp (buffer-list))))) ;; change TODO to only files for directory

(defun sbt-process-output (output)
  (let ((cleaned-output (replace-regexp-in-string ansi-color-regexp "" output)))
    (if sbt-use-ui
        (cond
         ((string-match "\\[info\\] Compiling" cleaned-output) (sbt-update-ui 'running))
         ((string-match "\\[error\\] " cleaned-output) (sbt-update-ui 'failed))
         ((string-match "\\[success\\] " cleaned-output) (sbt-update-ui 'passed))
         ((string-match "\\[info\\] Total session time" cleaned-output) (sbt-update-ui 'quit))))))


(defun sbt-buffer-name (path)
  (concat "*sbt:"
          (car (last (butlast (split-string (file-name-as-directory path) "/"))))
          "*"))

(defun sbt-make-comint (root buffer-name)
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (cd root)
      (make-comint-in-buffer buffer-name buffer sbt-program-name)
      (compilation-shell-minor-mode t)
      (sbt-mode t)
      buffer)))

;; TODO: (add-hook 'comint-output-filter-functions 'sbt-process-output t t)
;; TODO: sbt-hook

(defun sbt-find-or-create-buffer ()
  (let* ((root (sbt-find-path-to-project))
         (buffer-name (sbt-buffer-name root)))
    (or (get-buffer buffer-name)
        (sbt-make-comint root buffer-name))))

;;;###autoload
(defun sbt ()
  "Launch interactive sbt"
  (interactive)
  (switch-to-buffer (sbt-find-or-create-buffer)))

;;;###autoload
(defun sbt-switch ()
  "Switch to sbt buffer or back"
  (interactive)
  (let ((sbt-buffer (sbt-find-or-create-buffer)))
    (if (eq (current-buffer) sbt-buffer)
        (switch-to-buffer (other-buffer))
      (switch-to-buffer sbt-buffer))))

(defun sbt-command (command)
  (let ((buffer (sbt-find-or-create-buffer)))
    (switch-to-buffer buffer)
    (comint-send-string (buffer-name buffer) (concat command "\n"))))

;;;###autoload
(defun sbt-compile ()
  "Switch to sbt buffer and run compile"
  (interactive)
  (sbt-command "compile"))

;;;###autoload
(defun sbt-test ()
  "Switch to sbt buffer and run compile"
  (interactive)
  (sbt-command "test"))

(defun sbt-current-test-in-buffer ()
  (save-excursion
    (goto-char (point-min))
    (let* ((pkg-name (progn
                       (re-search-forward "package ")
                       (filter-buffer-substring (point) (point-at-eol))))
           (test-name (progn
                        (re-search-forward "object ")
                        (filter-buffer-substring
                         (point)
                         (progn
                           (re-search-forward " ")
                           (forward-char -1)
                           (point))))))
      (concat pkg-name "." test-name))))

(defun sbt-test-only-current-test ()
  "Run test-only for the test in the current buffer"
  (interactive)
  (sbt-command (concat "test-only " (sbt-current-test-in-buffer))))

(defvar sbt-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c s s") 'sbt-switch)
    (define-key map (kbd "C-c s c") 'sbt-compile)
    (define-key map (kbd "C-c s t") 'sbt-test)
    (define-key map (kbd "C-c s o") 'sbt-test-only-current-test)
    map))

;;;###autoload
(define-minor-mode sbt-mode "SBT interaction"
  :group 'sbt
  :lighter " sbt"
  :keymap sbt-keymap)

;;;###autoload
(defun turn-on-sbt-mode ()
  (interactive)
  (sbt-mode t))

;;;###autoload
(defun turn-off-sbt-mode ()
  (interactive)
  (sbt-mode nil))

(defcustom sbt-identifying-files '("build.sbt" "project/build.properties")
  "Files at the root of a sbt project that identify it as the root")

(defun sbt-find-path-to-project ()
  (car
   (delq nil
         (mapcar
          (lambda (f) (locate-dominating-file default-directory f))
          sbt-identifying-files))))

(provide 'sbt)
