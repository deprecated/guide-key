;;; guide-key.el

;;; TODO:
;; - write document
;; - DONE? enrichment of guide buffer
;;   - select color to be used
;; - DONE automatically guide all following keys
;; - DONE pop up guide buffer at top or bottom
;; - cooperate with polling of popwin.el?
;; - confine a length of command name
;; - confine the number of items to guide
;; - a feature to exclude or include guide by command name
;; - define (buffer local) minor mode instead of global minor mode

(eval-when-compile
  (require 'cl))

(require 'popwin)

;;; variables
(defgroup guide-key nil
  "Guide key bidings."
  :group 'help
  :prefix "guide-key:")

(defcustom guide-key:show-key-sequence nil
  "*Key sequences to show its bindings."
  :type '(repeat string)
  :group 'guide-key)

(defcustom guide-key:polling-time 0.1
  "*Polling time to show bindings."
  :type 'float
  :group 'guide-key)

(defcustom guide-key:highlight-command-regexp ""
  "*Regexp of command to highlight."
  :type 'regexp
  :group 'guide-key)

(defcustom guide-key:align-command-by-space-flag nil
  "*If non-nil, align command by space."
  :type 'boolean
  :group 'guide-key)

(defcustom guide-key:popup-window-position 'bottom
  "*Position to pop up buffer. This variable must be one of `right', `bottom', `left' and `top'."
  :type 'symbol
  :group 'guide-key)

(defface guide-key:prefix-command-face
  '((t (:foreground "cyan")))
  "Face for prefix command"
  :group 'guide-key)

(defface guide-key:highlight-command-face
  '((t (:foreground "yellow")))
  "Face for command to highlight"
  :group 'guide-key)

(defface guide-key:key-face
  '((t (:foreground "red")))
  "Face for key"
  :group 'guide-key)

;;; internal variables
;; (defvar guide-key:guide-list nil
;;   "List of key guide. Element of this is like (KEY SPACE COMMAND).")

(defvar guide-key:polling-timer nil
  "Polling timer for show bindings.")

(defvar guide-key:buffer-name "*guide-key*"
  "Buffer name to show bindings.")

(defvar guide-key:last-command-keys-vector nil
  "Last command keys as vector.")

;; or hook
;; (add-hook 'pre-command-hook 'guide-key:hook-command)
;; (setq pre-command-hook nil)
;; (add-hook 'post-command-hook 'guide-key:key-event)
;; (add-hook 'pre-command-hook 'show-this-command)

;;; functions
;;;###autoload
(define-minor-mode guide-key-mode
  "Show bindings automatically."
  :global t
  :lighter " Guide"
  (funcall (if guide-key-mode
               'guide-key:turn-on-timer
             'guide-key:turn-off-timer)))

;;; internal functions
(defun guide-key:polling-timer-function ()
  "Function executed every `guide-key:polling-time' second."
  (let ((dsc-buf (current-buffer))
        (key-seq (this-command-keys-vector))
        (max-width 0))
    (if (guide-key:display-popup-p key-seq)
        (when (guide-key:update-popup-p key-seq)
          (with-current-buffer (get-buffer-create guide-key:buffer-name)
            (unless truncate-lines (setq truncate-lines t))   ; don't fold
            (when indent-tabs-mode (setq indent-tabs-mode nil)) ; don't use tab as white space
            (erase-buffer)
            (describe-buffer-bindings dsc-buf key-seq)
            (if (> (guide-key:format-guide-buffer key-seq) 0)
                (progn
                  (guide-key:pre-command-popup-close)
                  (guide-key:popup-guide-buffer))
              (message "No following key."))))
      (guide-key:pre-command-popup-close))
    (setq guide-key:last-command-keys-vector key-seq)))

(defun guide-key:popup-guide-buffer ()
  "Pop up guide buffer."
  (with-current-buffer (get-buffer guide-key:buffer-name)
    (apply 'popwin:popup-buffer (current-buffer)
           :position guide-key:popup-window-position
           :noselect t
           (cond ((popwin:position-horizontal-p guide-key:popup-window-position)
                  `(:width ,(+ (guide-key:buffer-max-width) 3)))
                 ((popwin:position-vertical-p guide-key:popup-window-position)
                  `(:height ,(1+ (count-lines (point-min) (point-max)))))))
    ))

(defun guide-key:pre-command-popup-close ()
  "Close guide buffer at `pre-command-hook'."
  (when (guide-key:poppedup-p)
    (popwin:close-popup-window)))

(add-hook 'pre-command-hook 'guide-key:pre-command-popup-close)

(defun guide-key:update-popup-p (key-seq)
  "Return t if show bindings buffer should be updated."
  (not (equal guide-key:last-command-keys-vector key-seq)))

(defun guide-key:display-popup-p (key-seq)
  "Return t if show bindings buffer should be displayed."
;  (and (> (length key-seq) 0)
       (member key-seq (mapcar 'guide-key:convert-key-sequence-to-vector
                               guide-key:show-key-sequence))
       );)

(defun guide-key:convert-key-sequence-to-vector (key-seq)
  "Convert key sequence KEY-SEQ to vector representation."
  (vconcat (read-kbd-macro key-seq)))

(defun guide-key:poppedup-p ()
  "Return t if show bindings buffer is popped up."
  (eq popwin:popup-buffer (get-buffer guide-key:buffer-name)))

(defun guide-key:turn-on-timer ()
  "Turn on polling timer."
  (setq guide-key:polling-timer
        (run-at-time t guide-key:polling-time 'guide-key:polling-timer-function)))

(defun guide-key:turn-off-timer ()
  "Turn off polling timer."
  (cancel-timer guide-key:polling-timer))

(defun guide-key:format-guide-buffer (key-seq)
  "Format a guide buffer. This function returns the number of key guides."
  (let ((guide-list nil)      ; list of (key space command)
        (guide-str-list nil)  ; list of fontified string of key guides
        (guide-list-len 0)    ; length of above lists
        (key-dsc (key-description key-seq)))
    (untabify (point-min) (point-max))  ; replace tab to space
    (goto-char (point-min))
    ;; extract key guide from buffer bindings
    (while (re-search-forward
            (format "^%s \\([^ \t]+\\)\\([ \t]+\\)\\(\\(?:[^ \t\n]+ ?\\)+\\)$" key-dsc) nil t)
      (add-to-list 'guide-list
                   (list (match-string 1) (match-string 2) (match-string 3)) t))
    (erase-buffer)
    (when (> (setq guide-list-len (length guide-list)) 0)
      ;; fontify key guide string
      (setq guide-str-list
            (loop for (key space command) in guide-list
                  collect (guide-key:fontified-string key space command)))
      ;; insert a few strings per line
      (cond ((popwin:position-horizontal-p guide-key:popup-window-position)
             (guide-key:insert-guide-str-list
              guide-str-list (1+ (/ (length guide-str-list) (1- (frame-height))))))
            ((popwin:position-vertical-p guide-key:popup-window-position)
             (guide-key:insert-guide-str-list  ; caluculation of second argument is rough
              guide-str-list (/ (frame-width)
                                (apply 'max (mapcar 'length guide-str-list))))))
      (align-regexp (point-min) (point-max) "\\(\\s-*\\) \\[" 1 1 t)
      (goto-char (point-min)))
    guide-list-len))

(defun guide-key:insert-guide-str-list (guide-str-list columns)
  "Insert GUIDE-STR-LIST COLUMNS."
  (loop for guide-str in guide-str-list
        for column from 1
        do (insert guide-str (if (= (mod column columns) 0) "\n" " "))))

(defun guide-key:fontified-string (key space command)
  "Fontified string for key guide"
  (concat (propertize "[" 'face 'guide-key:key-face)
          (guide-key:propertize-string-according-to-command key command)
          (propertize "]" 'face 'guide-key:key-face)
          (if guide-key:align-command-by-space-flag space " ") ; white space
          (guide-key:propertize-string-according-to-command command command)))

(defun guide-key:propertize-string-according-to-command (string command)
  "Return STRING putted text property accordinig to COMMAND"
  (cond ((string-match "prefix" command)
         (propertize string 'face 'guide-key:prefix-command-face))
        ((string-match guide-key:highlight-command-regexp command)
         (propertize string 'face 'guide-key:highlight-command-face))
        (t
         string)))

(defun guide-key:buffer-max-width ()
  "Return max width in current buffer."
  (let ((buf-str (buffer-substring-no-properties (point-min) (point-max))))
    (apply 'max (mapcar 'length (split-string buf-str "\n")))))

;;; debug
(defun guide-key:message-events ()
  ""
  (message (format "lce:%S tck:%S tckv:%S lie:%S uce:%S popb:%S cls:%S"
                   last-command-event
                   (this-command-keys)
                   (this-command-keys-vector)
                   last-input-event
                   unread-command-events
                   popwin:popup-buffer
                   (guide-key:poppedup-p)
                   )))
;; (setq ttt (run-at-time t 1 'guide-key:message-events))
;; (cancel-timer ttt)

(provide 'guide-key)
;;; guide-key.el ends here
