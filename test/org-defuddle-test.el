;;; org-defuddle-test.el --- Tests for org-defuddle  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Code:

(require 'ert)
(require 'cl-lib)

(defvar org-defuddle--module-loaded)
(defvar org-defuddle--module-version)
(declare-function org-defuddle--default-module-file "org-defuddle")
(declare-function org-defuddle--module-download-url "org-defuddle")
(declare-function org-defuddle--module-release-asset "org-defuddle")
(declare-function org-defuddle-download-module "org-defuddle" (&optional path))
(declare-function org-defuddle-html-to-org "org-defuddle" (html &optional url options))
(declare-function org-defuddle-load-module "org-defuddle" (&optional offer-download))

(defconst org-defuddle-test--root
  (file-name-directory
   (directory-file-name
    (file-name-directory (or load-file-name buffer-file-name))))
  "Repository root used by the org-defuddle tests.")

(load (expand-file-name "org-defuddle.el" org-defuddle-test--root) nil nil t)

(ert-deftest org-defuddle-test-release-assets-match-supported-platforms ()
  (dolist (case '((darwin "aarch64-apple-darwin" ".dylib"
                          "liborg-defuddle-aarch64-apple-darwin.dylib")
                  (darwin "x86_64-apple-darwin" ".dylib"
                          "liborg-defuddle-x86_64-apple-darwin.dylib")
                  (gnu/linux "x86_64-unknown-linux-gnu" ".so"
                             "liborg-defuddle-x86_64-unknown-linux-gnu.so")
                  (gnu/linux "aarch64-unknown-linux-gnu" ".so"
                             "liborg-defuddle-aarch64-unknown-linux-gnu.so")
                  (windows-nt "x86_64-pc-windows-msvc" ".dll"
                              "liborg-defuddle-x86_64-pc-windows-msvc.dll")))
    (pcase-let ((`(,platform ,configuration ,suffix ,asset) case))
      (let ((system-type platform)
            (system-configuration configuration)
            (module-file-suffix suffix))
        (should (equal (org-defuddle--module-release-asset) asset))))))

(ert-deftest org-defuddle-test-download-url-is-version-pinned ()
  (let ((system-type 'darwin)
        (system-configuration "aarch64-apple-darwin")
        (module-file-suffix ".dylib"))
    (should
     (equal
      (org-defuddle--module-download-url)
      (concat "https://github.com/LuciusChen/org-defuddle/releases/download/"
              org-defuddle--module-version
              "/liborg-defuddle-aarch64-apple-darwin.dylib")))))

(ert-deftest org-defuddle-test-download-installs-and-loads-default-path ()
  (let* ((directory (make-temp-file "org-defuddle-module-" t))
         (org-defuddle-module-file
          (expand-file-name (concat "liborg_defuddle_module" module-file-suffix)
                            directory))
         (org-defuddle--module-loaded nil)
         requested-url
         loaded-file)
    (unwind-protect
        (cl-letf (((symbol-function 'url-copy-file)
                   (lambda (url path &optional _ok-if-already-exists)
                     (setq requested-url url)
                     (with-temp-file path
                       (insert "module"))))
                  ((symbol-function 'org-defuddle--load-module-file)
                   (lambda (path)
                     (setq loaded-file path
                           org-defuddle--module-loaded t))))
          (org-defuddle-download-module)
          (should (equal requested-url (org-defuddle--module-download-url)))
          (should (equal loaded-file org-defuddle-module-file))
          (should (file-exists-p org-defuddle-module-file)))
      (delete-directory directory t))))

(ert-deftest org-defuddle-test-interactive-load-offers-release-download ()
  (let ((org-defuddle--module-loaded nil)
        offered
        downloaded)
    (cl-letf (((symbol-function 'org-defuddle--existing-module-file)
               (lambda () nil))
              ((symbol-function 'yes-or-no-p)
               (lambda (prompt)
                 (setq offered prompt)
                 t))
              ((symbol-function 'org-defuddle-download-module)
               (lambda (&optional _path)
                 (setq downloaded t
                       org-defuddle--module-loaded t))))
      (org-defuddle-load-module t)
      (should (string-match-p "download pre-built release" offered))
      (should downloaded))))

(ert-deftest org-defuddle-test-noninteractive-load-does-not-download ()
  (let ((org-defuddle--module-loaded nil))
    (cl-letf (((symbol-function 'org-defuddle--existing-module-file)
               (lambda () nil)))
      (should-error (org-defuddle-load-module) :type 'user-error))))

(ert-deftest org-defuddle-test-real-module-call ()
  (let ((org-defuddle-module-file (org-defuddle--default-module-file))
        (org-defuddle--module-loaded nil))
    (unless (file-exists-p org-defuddle-module-file)
      (ert-skip (format "Missing built module at %s" org-defuddle-module-file)))
    (org-defuddle-load-module)
    (should
     (string-match-p
      "Rust dynamic module extraction works"
      (org-defuddle-html-to-org
       (concat "<article><h1>Module Test</h1>"
               "<p>Rust dynamic module extraction works through Emacs.</p>"
               "</article>")
       "https://example.com/module-test")))))

(provide 'org-defuddle-test)

;;; org-defuddle-test.el ends here
