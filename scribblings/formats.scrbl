#lang scribble/manual

@(require scribble/eval pollen/render pollen/world (for-label racket (except-in pollen #%module-begin) pollen/world sugar pollen/pagetree))

@(define my-eval (make-base-eval))
@(my-eval `(require pollen pollen/file))


@title{File formats}


@section{Source formats}

@defmodulelang*[(pollen/pre pollen/markdown pollen/markup pollen/ptree)]


The Pollen language is divided into variants, or @italic{dialects}, that are tailored to suit each of the core source formats.

These dialects can be invoked one of two ways: either by invoking a specific dialect in the first line of the file (also known as the @litchar{#lang} line), or by using the generic @litchar{#lang pollen} as the first line, and then the correct dialect will be automatically selected based on the source file extension.

If the @litchar{#lang} line specifies a dialect different from the one specified by the file extension, the @litchar{#lang} line will take precedence. 


For ease of use, the behavior of the Pollen language departs from the standard Racket language in several ways. The differences are noted below.

@subsection{Command syntax using ◊}

Commands must start with the special lozenge character @litchar{◊}. Other material is interpreted as plain text. See @secref["reader"] for more.

@bold{How is this different from Racket?} In Racket, everything is a command, and plain text must be quoted.

@subsection{Any command is valid}

There are no undefined commands in Pollen. If a command has not already been defined, it's treated as a tag function. See @secref["reader"] for more.

@bold{How is this different from Racket?} In Racket, if you try to treat an identifier as a function before defining it with @racket[define], you'll get an error.


@subsection{Standard exports}

By default, every Pollen source file exports two symbols, which you can access by using the source file with @racket[require]:

@racket['doc] contains the output of the file. The type of output depends on the source format (documented below).

@racket['metas] is a hash of key–value pairs with extra information that is extracted from the source. These @racket['metas] will always contain the key @racket['here-path], which returns a string representation of the full path to the source file. Beyond that, the only @racket['metas] are the ones that are specified within the source file (see the source formats below for more detail on how to specify metas).

@bold{How is this different from Racket?} In Racket, you must explicitly @racket[define] and then @racket[provide] any values you want to export.

@subsection{Custom exports}

Any value or function that is defined within the source file using @racket[define] is automatically exported.

@bold{How is this different from Racket?} In Racket, you must explicitly @racket[provide] any values you want to export. Unlike Racket, every Pollen source file impliedly uses @racket[(provide (all-defined-out))].


@subsection{The @code{@(format "~a" world:project-require)} file}

If a file called @code{@(format "~a" world:project-require)} exists in the same directory with a source file, it's automatically imported when the source file is compiled.

@bold{How is this different from Racket?} In Racket, you must explicitly import files using @racket[require].

@subsection{Preprocessor (@(format ".~a" world:preproc-source-ext) extension)}

Invoke the preprocessor dialect by using @code{#lang pollen/pre} as the first line of your source file, or by using @code{#lang pollen} with a file extension of @code{@(format ".~a" world:preproc-source-ext)}. These forms are equivalent:


@racketmod[#:file "sample.css.pp" pollen
_...source...
]

@racketmod[#:file "sample.css" pollen/pre
_...source...
]

When no dialect is explicitly specified by either the @litchar{#lang} line or the file extension, Pollen will default to using the preprocessor dialect. For instance, this file will be treated as preprocessor source:

@racketmod[#:file "test.yyz" pollen
_...source...
]

Of course, you're better off specifying the preprocessor dialect explicitly rather than relying on this default behavior.

The output of the preprocessor dialect, provided by @racket['doc], is plain text.



@subsection{Markdown (@(format ".~a" world:markdown-source-ext) extension)}

Invoke the Markdown dialect by using @code{#lang pollen/markdown} as the first line of your source file, or by using @code{#lang pollen} with a file extension of @code{@(format ".~a" world:markdown-source-ext)}. These forms are equivalent:


@racketmod[#:file "sample.txt.pmd" pollen
_...source...
]

@racketmod[#:file "sample.txt" pollen/markdown
_...source...
]

The output of the Markdown dialect, provided by @racket['doc], is a tagged X-expression.


@subsection{Markup (@(format ".~a" world:markup-source-ext) extension)}

Invoke the Pollen markup dialect by using @code{#lang pollen/markup} as the first line of your source file, or by using @code{#lang pollen} with a file extension of @code{@(format ".~a" world:markup-source-ext)}. These forms are equivalent:


@racketmod[#:file "about.html.pm" pollen
_...source...
]

@racketmod[#:file "about.html" pollen/markup
_...source...
]

The output of the Pollen markup dialect, provided by @racket['doc], is a tagged X-expression.

@subsection{Pagetree  (@(format ".~a" world:pagetree-source-ext) extension)}


Invoke the pagetree dialect by using @code{#lang pollen/ptree} as the first line of your source file, or by using @code{#lang pollen} with a file extension of @code{@(format ".~a" world:pagetree-source-ext)}. These forms are equivalent:


@racketmod[#:file "main.ptree" pollen
_...source...
]

@racketmod[#:file "main.rkt" pollen/ptree
_...source...
]



The output of the pagetree dialect, provided by @racket['doc], is a @racket[pagetree?] that is checked for correctness using @racket[validate-pagetree].




@section{Utility formats}

These aren't source formats because they don't contain a @litchar{#lang pollen} line. But for convenience, they get special handling by the Pollen project server.



@subsection{Scribble  (@(format ".~a" world:scribble-source-ext) extension)}

Scribble files are recognized by the project server and can be compiled and previewed in single-page mode.


@subsection{Null (@(format ".~a" world:null-source-ext) extension)}

Files with the null extension are simply rendered as a copy of the file without the extension, so @code{index.html.p} becomes @code{index.html}. 

This can be useful you're managing your project with git. Most likely you'll want to ignore @code{*.html} and other file types that are frequently regenerated by the project server. But if you have isolated static files — for instance, a @code{index.html} that doesn't have source associated with it — they'll be ignored too. You can cure this problem by appending the null extension to these static files, so they'll be tracked in your source system without actually being source files.
