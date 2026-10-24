;;; jwa-modeline.el --- Personal utility functions -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'jwa)
(require 'battery)

;;;; General settings
(setq-default mode-line-position
      '((:propertize " %l:" face shadow)
        (:propertize "%c " face shadow)))

(setq mode-line-collapse-minor-modes '(not)
      mode-line-modes-delimiters '("" . ""))

(defun jwa-modeline-set-theme (&rest _)
  "Setup jwa-modeline theming.
Can be used with hook `enable-theme-functions' to dynamically follow
theme changes."
  (let* ((bg (face-attribute 'default :background nil t))
         (line (face-attribute 'fill-column-indicator :foreground nil t)))
    (custom-set-faces `(mode-line-active
                        ((t ( :background ,bg
                              :box (:line-width 8 :color ,bg)
                              :overline ,line)))
                        t))))

(defun jwa-modeline-set-theme (&rest _)
  "Setup jwa-modeline theming.
Can be used with hook `enable-theme-functions' to dynamically follow
theme changes."
  (let* ((bg (face-attribute 'default :background nil t))
         (line (face-attribute 'fill-column-indicator :foreground nil t)))
    (set-face-attribute 'mode-line-active nil
                        :background bg
                        :box `(:line-width 8 :color ,bg)
                        :overline line)))

(add-hook 'enable-theme-functions #'jwa-modeline-set-theme 90)

;;;; Battery status; show only when not on AC
(display-battery-mode t)

(defvar jwa-modeline--battery-format " %p %%%% ")
(setq battery-mode-line-format jwa-modeline--battery-format)

(defun jwa-modeline--battery-hide-on-ac (orig-fun &rest args)
  "Advice around `battery-update' to hide battery info when on AC power.
Call ORIG-FUN with ARGS, but temporarily bind `battery-mode-line-format'
to \" AC \" if AC power is detected, otherwise use
`jwa-modeline--battery-format'."
  (let ((battery-mode-line-format
	 (if (string-match-p "AC" (battery-format "%L" (funcall battery-status-function)))
	     " AC " jwa-modeline--battery-format)))
    (apply orig-fun args)))

(advice-add 'battery-update :around #'jwa-modeline--battery-hide-on-ac)

;;;; Mode-line segments
(defvar-local jwa-modeline--unsaved-buffers-indicator
  '(:eval (when (jwa-unsaved-buffers-p)
	    (propertize " • " 'face 'error)))
  "Construct to display unsaved buffers indicator.")

(defvar-local jwa-modeline--buffer-state
  '(:eval (when (mode-line-window-selected-p)
	    (cond (view-mode "")
		  (buffer-read-only (propertize " RO " 'face 'next-error))
		  (t (propertize " RW " 'face 'next-error)))))
  "Construct to display buffer state (readonly/readwrite) in the mode-line.")

(defvar-local jwa-modeline--buffer-name
  '(:eval (propertize (format " %s " (buffer-name))
		      'face (if (buffer-modified-p) 'org-warning 'mode-line-buffer-id)))
  "Construct to display buffer name in the mode-line.")

(defvar-local jwa-modeline--vc
  '(:eval (when (and (mode-line-window-selected-p) vc-mode)
	    (propertize
	     (replace-regexp-in-string "^ Git:\\(.*\\)" " [\\1] " vc-mode)
	     'face '(:inherit shadow))))
  "Construct to display version control infromation in the mode-line.")

(defvar-local jwa-modeline--tabs
  '(:eval (when (and (mode-line-window-selected-p)
		     tab-bar-mode
		     (> (length (funcall tab-bar-tabs-function)) 1))
	    (list " " (propertize (format " %s/%s "
					  (1+ (tab-bar--current-tab-index))
					  (length (tab-bar-tabs)))
				  'face 'completions-highlight))))
  "Construct to show the current tab number on the mode-line.")

(defvar-local jwa-modeline--modes
  '(:eval (when (mode-line-window-selected-p) mode-line-modes))
  "Construct to show major and minor modes on the mode-line.")

(defvar-local jwa-modeline--position
  '(:eval (when (mode-line-window-selected-p) mode-line-position))
  "Construct to show cursor position on the mode-line.")

(defvar-local jwa-modeline--narrow
  '(:eval (when (buffer-narrowed-p)
	    (list (propertize " NARROW " 'face 'diff-added) " ")))
  "Construct to express narrow state on the mode-line.")

(defvar-local jwa-modeline--battery
  '(:eval (when (mode-line-window-selected-p)
	    (list " " (propertize battery-mode-line-string
				  'face 'completions-highlight)))))

(dolist (construct '(jwa-modeline--buffer-state
		     jwa-modeline--buffer-name
		     jwa-modeline--vc
		     jwa-modeline--tabs
		     jwa-modeline--modes
		     jwa-modeline--position
		     jwa-modeline--narrow
		     jwa-modeline--battery
		     jwa-modeline--unsaved-buffers-indicator))
  (put construct 'risky-local-variable t))

;;;; Setup mode-line
(setq-default mode-line-format
	      '("%e"
		mode-line-front-space
		jwa-modeline--narrow
		;; jwa-modeline--buffer-state
		jwa-modeline--tabs
		" "
		jwa-modeline--buffer-name
		jwa-modeline--unsaved-buffers-indicator
		" "
		jwa-modeline--vc
		mode-line-format-right-align
		jwa-modeline--position
		"  "
		jwa-modeline--modes
		" "
		jwa-modeline--battery
		mode-line-end-spaces))

(provide 'jwa-modeline)
;;; jwa-modeline.el ends here
