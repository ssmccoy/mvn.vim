" Vim Compiler File
" Compiler:	mvn
" Last Change:	Sun May 10 22:03:09 PDT 2009

if exists("current_compiler")
    finish
endif

let current_compiler = "mvn"

" Seems silly to create an alias for setlocal
"if exists(":CompilerSet") != 2		" older Vim always used :setlocal
"  command -nargs=* CompilerSet setlocal <args>
"endif

setlocal makeprg=mvn

" This is a very complicated format.
" The first two lines are for scala, which emits messages like:
" [ERROR] Filename.scala:83: error: not found: type SBool
" [INFO]     success             : SBool,
" [INFO]                           ^
"
" Following those are some for the ajc compiler when invoked through
" maven-aspectj-plugin.
"
" Following that are standard maven/plexus messages, and ignores for dependency
" resolution and the like.
"
" Following those are checkstyle output, for running make checkstyle:check, to
" create a quick-fix list from style issues.  Checkstyles output is quite
" simple:
"
" Filename.java:line:column: Use of tabs is disallowed.
"
" And then finally, some catch-all ignore.

"    \%A%[%^[]%\\@=%f:%l:\ %t%[a-z]%#\ %m, " Multiline error/warning message
"    \%-Z[INFO]\ %p^,                      " column pointer for above
"    %[%t%^[]%\\@=%f:[%l\\,%v]\ %m,        " Unspecified single line typed message..
"    \%-Z[INFO]\ %p^,                      " column pointer for above
"    \%-Clocation\ %#:%.%#,                " Ignore this (???)  Shouldn't be needed...
"    \%-CDownloading%#:%.%#,               " Ignore dependency resolution
"    \%f:%l:%v:\ %m,                       " Checkstyle (with column)
"    \%f:%l:\ %m,                          " Checkstyle (line numbers only)
"    \%C%[%^:]%#%m,                        " For the long messages from ajc
"    \%E[ERROR]\ %f:%l:\ error:\ %m,       " maven-scala-plugin
"    \%-Z[INFO]\ %p^,                      " column pointer for above
"    \%-G%.%#,                             " Ignore everything else...
"
"    \%E[ERROR]\ %f:%l:\ %t%*[^:]:\ %m,
"    \%-Z[INFO]\ %p^,
"    \%f:%l:%v:\ %m,
"    \%f:%l:\ %m,
"    \%-G%.%#,

setlocal errorformat=
    \%E[ERROR]\ %f:%l:\ %t%*[^:]:\ %m,
    \%-Z[INFO]\ %p^,
    \%W[WARNING]\ %f:%l:\ %t%*[^:]:\ %m,
    \%-Z[INFO]\ %p^,
    \%E[ERROR]\ %f:[%l\\,%v]\ %t%*[^:]:\ %m,
    \%-Z[INFO]\ %p^,
    \%E\%f:[%l\\,%v]\ %m,
    \%-Z[INFO]\ %p^,
    \%C%[%^:]%#%m,
    \%f:%l:%v:\ %m,
    \%f:%l:\ %m,
    \%-G%.%#,


" I took this out, because it's not matching warnings right now.  I'm not sure
" if it does in AJC or what
"   \%-Z\ %#,			    " End of warnings
"
"   Same with this, was on line one.
"   \%-G[%\\(WARNING]%\\)%\\@!%.%#,
