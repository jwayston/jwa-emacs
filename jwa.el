;;; jwa.el --- Personal utility functions -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:
;;;; Visual appearance
(defun jwa-hi-hashtags()
  "Add font-lock keywords to highlight hashtags."
  (font-lock-add-keywords nil '(("\\(?:^\\|\\s-\\)\\(#\\)\\([[:alnum:]_]+\\)"
				 (1 '(face nil invisible t))
				 (2 'so-long-mode-line-inactive t)))))

;;;; Buffers
(defun jwa-unsaved-buffers-p ()
  "List unsaved buffers."
  (seq-filter (lambda (buf)
		(and (buffer-modified-p buf)
                     (buffer-file-name buf)))
              (buffer-list)))

(defun jwa-buffer-essential-p (buf)
  "Is BUF essential for the system?"
  (let ((name (buffer-name buf)))
    (or (string-prefix-p " " name)
	(member name (list "*new*" "*Messages*" "*scratch*")))))

(defun jwa-buffer-active-p (buf)
  "Is there current activity in the BUF?"
  (or (and (buffer-modified-p buf)
	   (not (string-prefix-p "*" (buffer-name buf))))
      (get-buffer-process buf)
      (get-buffer-window-list buf)))

(defun jwa-buffer-current-p (buf)
  "Is the current buffer BUF?"
  (eq buf (current-buffer)))

(defun jwa-kill-futile-buffers ()
  "Kill all buffers except for unsaved, active or otherwise necessary ones."
  (interactive)
  (let* ((all (buffer-list))
	 (list-1 (seq-remove #'jwa-buffer-essential-p all))
	 (list-2 (seq-remove #'jwa-buffer-active-p list-1))
	 (to-kill (seq-remove #'jwa-buffer-current-p list-2))
	 (killed-names (mapcar #'buffer-name to-kill)))
    (if to-kill
	(progn
	  (dolist (buf to-kill) (kill-buffer buf))
	  (message "Killed %d buffers: %s" (length to-kill) (mapconcat #'identity killed-names ", ")))
      (message "Nothing to kill"))))

;;;; Text editing
(defun jwa--text-add-marker-line-below (char &optional line-chars)
  "Add text marker line below of length LINE-CHARS using CHAR."
  (interactive "cChar: \nP")
  (let ((num (or line-chars fill-column))
	(char (if (or (null char) (= char ?\C-m)) ?- char)))
    (save-excursion (end-of-line) (newline) (insert (make-string num char)))))

(defun jwa-text-line-to-heading (char)
  "Generate contiguous heading markers below the text line using CHAR."
  (interactive "cChar: ")
  (let* ((line-chars (- (line-end-position) (line-beginning-position))))
    (jwa--text-add-marker-line-below char line-chars)))

(defun jwa-text-line-to-columns-header (char)
  "Format current line as a N-column header with header markerline CHAR below.
Columns must be separated with two spaces.  Column alignment is adjusted as per
`fill-column'."
  (interactive "cChar: ")
  (let* ((separator "  ")
	 (line-chars (- (line-end-position) (line-beginning-position)))
	 (fill-cap (max 0 (- fill-column line-chars)))
	 (columns (how-many separator (line-beginning-position) (line-end-position))))
    (save-excursion
      (beginning-of-line)
      (dotimes (_ columns)
	(when (search-forward separator (line-end-position) t)
	  (insert (make-string (/ fill-cap columns) ?\s))))
      (end-of-line)
      (when (< (current-column) fill-column)  ; Add missing spaces if any
	(let ((line-len (current-column)))
	  (when (search-backward "  " (line-beginning-position) t)
	    (insert (make-string (- fill-column line-len) ?\s)))))
      (jwa-text-line-to-heading char))))

(defun jwa-text-region-to-box ()
  "Draw box around a selection using external `boxes' command."
  (interactive)
  (let* ((styles-raw (shell-command-to-string "/opt/homebrew/opt/grep/bin/ggrep -oP 'BOX \\K(.*)' /opt/homebrew/share/boxes-config | sed 's/.*/\"&\"/'"))
	 (styles-lisp (car (read-from-string (concat "(" styles-raw ")"))))
	 (style (completing-read "Style (default ansi): " styles-lisp nil t nil nil "ansi"))
	 (width (read-number "Width: " 76))
	 (cmd   (format "boxes -a hc -d %s -s %d" style width)))
    (shell-command-on-region (region-beginning) (region-end) cmd t t)))

(defun jwa-newline-above ()
  "Insert newline above, indent and jump there."
  (interactive)
  (move-beginning-of-line 1)
  (newline-and-indent) (forward-line -1) (indent-according-to-mode))

(defun jwa-newline-below ()
  "Insert newline below, indent and jump there."
  (interactive)
  (move-end-of-line 1) (newline-and-indent))

(defun jwa-mark-line ()
  "Mark the current line and leave point at the end of the line."
  (interactive)
  (move-beginning-of-line 1)
  (when (not (use-region-p)) (set-mark (point)))
  (move-end-of-line 1))

(defun jwa-join-line-with-below ()
  "Join current line with the line below."
  (interactive)
  (delete-indentation 1))

;;;; Programming
(defun jwa-indent-fun ()
  "Indent a defun under the cursor."
  (interactive)
  (save-excursion
    (mark-defun)
    (indent-region (region-beginning) (region-end))))

(defun jwa-matching-paren-jump ()
  "Jump to matching paren."
  (interactive)
  (cond ((looking-at "[([{\"']") (forward-sexp 1))
	((looking-at "[)]}\"']") (backward-sexp 1))
	 (t (message "Cursor not next to a paren"))))

(defun jwa-move-line-up-and-indent ()
  "Move current line up and indent according to mode."
  (interactive)
  (transpose-lines 1)
  (forward-line -2)
  (indent-according-to-mode))

(defun jwa-move-line-down-and-indent ()
  "Move current line down and indent according to mode."
  (interactive)
  (forward-line 1)
  (transpose-lines 1)
  (forward-line -1)
  (indent-according-to-mode))

(defun jwa-mark-sexp ()
  "Mark the current sexp no matter where the cursor is."
  (interactive)
  (call-interactively 'backward-up-list)
  (call-interactively 'mark-sexp))

;;;; Miscellaneous
(defun jwa--base45 (n)
  "Convert a number N to a base45 string representation."
  (let ((chars "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖÜ_-$!%^"))
    (if (< n 45) (string (elt chars n))
      (concat (jwa--base45 (/ n 45)) (string (elt chars (% n 45)))))))

(defun jwa--zettel-get-uid (initial-identifier date)
  "Generate a Zettelkasten UID.  INITIAL-IDENTIFIER and DATE are optional."
  (let* ((now (decode-time))
	 (mins (+ (* (nth 2 now) 60) (nth 1 now)))
	 (secs (+ (nth 0 now) (* mins 60)))
	 (xx (format "%2s" (jwa--base45 secs))))
    (concat (format-time-string "%y%m%d")
	    (replace-regexp-in-string " " "0" xx))))

(defun jwa-zettel-insert-uid ()
  "Insert a new Zettelkasten UID."
  (interactive) (insert (jwa--zettel-get-uid)))

;;;; Org
(defun jwa-consult-ripgrep-roam-path ()
  "Open `consult-ripgrep' on Org Roam path.
Search is case-insensitive and results are sorted by the filename (descending).
Output is not grouped."
  (interactive)
  (let* ((my-args " --sortr path --ignore-case")
	 (vertico-group-format nil)
	 (consult-ripgrep-args (concat consult-ripgrep-args my-args)))
    (consult-ripgrep org-roam-directory)))

;;;; Window management
(defun jwa-next-command-open-below ()
  "Prefix function to open a window created by next command below."
  (interactive)
  (display-buffer-override-next-command
   (lambda (buffer alist)
     (cons (display-buffer-below-selected buffer alist) nil))))

(provide 'jwa)
;;; jwa.el ends here
