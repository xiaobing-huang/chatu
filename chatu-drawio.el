;;; chatu-drawio.el --- Chatu for drawio  -*- lexical-binding: t -*-

;; Copyright (c) 2024 Kimi Ma <kimi.im@outlook.com>

;; Author:  Kimi Ma <kimi.im@outlook.com>
;; URL: https://github.com/kimim/chatu
;; Keywords: multimedia convenience

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
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

;; script and open function for drawio

;;; Code:

(require 'chatu-common)

(defcustom chatu-drawio-executable-func #'chatu-drawio--find-executable
  "The function to find the drawio executable."
  :group 'chatu
  :type 'function)

(defcustom chatu-drawio-empty
  "<mxfile><diagram><mxGraphModel></mxGraphModel></diagram></mxfile>"
  "Content of empty drawio file."
  :group 'chatu
  :type 'string)

(defcustom chatu-drawio-svg-converter 'inkscape
  "The tool to use for converting PDF to SVG.
Supported values:
  \\='inkscape - Use inkscape for better SVG quality (recommended)
  \\='pdf2svg  - Use pdf2svg for faster conversion"
  :group 'chatu
  :type '(choice (const :tag "Inkscape (recommended)" inkscape)
          (const :tag "pdf2svg" pdf2svg)))

(defcustom chatu-drawio-inkscape-path "inkscape"
  "Path to the inkscape executable.
Default is \"inkscape\" which assumes it is in PATH."
  :group 'chatu
  :type 'string)

(defun chatu-drawio--find-executable ()
  "Find the drawio executable on PATH, or else return an error."
  (condition-case nil
      (file-truename (or (executable-find "draw.io")
                         ;; for wsl emacs to find windows draw.io.exe
                         (executable-find "draw.io.exe")
                         ;; drawio on gentoo
                         (executable-find "drawio")))
    (wrong-type-argument
     (message "Cannot find the draw.io executable on the PATH."))))

(defun chatu-drawio--get-pdf-to-svg-command (pdf-path svg-path)
  "Generate the command to convert PDF-PATH to SVG-PATH.
Uses the converter specified by `chatu-drawio-svg-converter'."
  (pcase chatu-drawio-svg-converter
    ('inkscape
     (format "%s %s --export-type=svg --export-filename=%s --export-area-drawing --export-margin 20"
             (shell-quote-argument chatu-drawio-inkscape-path)
             (shell-quote-argument pdf-path)
             (shell-quote-argument svg-path)))
    ('pdf2svg
     (format "pdf2svg %s %s"
             (shell-quote-argument pdf-path)
             (shell-quote-argument svg-path)))
    (_
     (error "Unknown SVG converter: %s. Use 'inkscape or 'pdf2svg"
            chatu-drawio-svg-converter))))

(defun chatu-drawio-script (keyword-plist)
  "Get conversion script.
KEYWORD-PLIST contains parameters from the chatu line."
  (let* ((input-path
          (chatu-common-with-extension
           (plist-get keyword-plist :input-path) "drawio"))
         (output-ext (plist-get keyword-plist :output-ext))
         (output-path (plist-get keyword-plist :output-path))
         (output-path-pdf (file-name-with-extension output-path "pdf"))
         (page (plist-get keyword-plist :page))
         (drawio-path (shell-quote-argument (funcall chatu-drawio-executable-func)))
         ;; special handling for WSL emacs invoke Windows draw.io.exe
         (input-path
          (if (string= "exe"
                       (file-name-extension drawio-path))
              (string-trim
               (shell-command-to-string
                (format "wslpath -aw '%s'" (file-truename input-path))))
            input-path)))
    (if (string= output-ext "svg")
        (format "%s %s -x %s -p %s -o %s && %s && rm %s"
                drawio-path
                (if (plist-get keyword-plist :nocrop)  "" "--crop")
                (shell-quote-argument input-path)
                (or page "0")
                (shell-quote-argument output-path-pdf)
                (chatu-drawio--get-pdf-to-svg-command output-path-pdf output-path)
                (shell-quote-argument output-path-pdf))
      (format "%s %s -f %s -x %s -p %s -o %s"
              drawio-path
              (if (plist-get keyword-plist :nocrop) "" "--crop")
              (shell-quote-argument output-ext)
              (shell-quote-argument input-path)
              (or page "0")
              (shell-quote-argument (file-name-with-extension output-path output-ext))))))


(defun chatu-drawio-open (keyword-plist)
  "Open .drawio file.
KEYWORD-PLIST contains parameters from the chatu line."
  (interactive)
  (let* ((input-path (plist-get keyword-plist :input-path))
         (input-path (file-truename (chatu-common-with-extension input-path "drawio")))
         (drawio-path (shell-quote-argument (funcall chatu-drawio-executable-func))))
    (chatu-common-open-external drawio-path input-path chatu-drawio-empty)))

(provide 'chatu-drawio)

;;; chatu-drawio.el ends here
