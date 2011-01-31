Senior design documentation.

For now, each file corresponds to a single final document. Documents are in the
format indicated by their extension, with Pandoc extensions where appropriate.

A Pandoc formatting template is also included. Use the following commands to
render the document, from a document's directory (note: need xetex and the
Skolar font to render properly; I'll set up a post-commit hook to automatically
regenerate and serve the PDF with the template later):

    markdown2pdf --xetex --template=../latex.template INPUT.md

