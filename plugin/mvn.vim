" ----------------------------------------------------------------------------- 
" Name: Simple maven plugin
" ----------------------------------------------------------------------------- 
" Author: Scott S. McCoy (tag@cpan.org)
" Description: This plugin creates a number of short cuts for dealing with java
" and scala files and maven.  Combined with the maven compiler plugin, it
" creates a compile-on-write feature which provides error checking
" functionality similar to most IDEs.

" This is super cool and fast and all but it's not very complete unfortunately.
let g:mvn_compiler_task = "compiler:compile compiler:testCompile"
" let g:mvn_compiler_task = "compile"
let g:mvn_line_ending = ";"

function! MvnAutoCompile ()
    if exists("g:mvn_auto_compile")
        au! BufReadPre *.java
        au! BufWritePost *.java

        au! BufReadPre *.scala
        au! BufWritePost *.scala

        unlet g:mvn_auto_compile
        echo "Auto Compile Off"
    else
        au BufEnter *.java silent call MvnSetClasspath()
        au BufEnter *.java silent let g:mvn_line_ending = ";"
        au BufWritePost *.java silent compiler mvn
        au BufWritePost *.java exec "silent make -B -ff -q -o " . g:mvn_compiler_task
        au BufWritePost *.java cwindow

        au BufEnter *.scala silent let g:mvn_compiler_task =
                    \"scala:compile compiler:compile " .
                    \"scala:testCompile compiler:testCompile"

        au BufEnter *.scala silent call MvnSetClasspath()
        au BufEnter *.scala silent let g:mvn_line_ending = ""
        au BufWritePost *.scala silent compiler mvn
        au BufWritePost *.scala exec "silent make -o " . g:mvn_compiler_task
        au BufWritePost *.scala cwindow

        let g:mvn_auto_compile = "mvn"
        echo "Auto Compile On"
    endif
endfunction

" Builds two indexes, target/classpath.txt and target/class-index.txt.  The
" first is faster to build as the class-list depends on the classpath.  Test
" for their existence, given one of the two filenames ("classpath.txt" or
" "class-index.txt") and if neither are provided then kick off the process that
" builds them (in the background).  If the requested file exists, exit
" returning the filename.
function! MvnBuildIndex(indexfile)
    let current_path = split(substitute(expand("%"), getcwd(), "", ""), "/")
    let current_module = current_path[0]

    let find_command = "find . -maxdepth 2 -name 'pom.xml'|cut -d / -f 2"
    let module_list = system(find_command)

    if current_module != "src" && match(module_list, current_module)
        let index  = current_module . "/target/" . a:indexfile
        let module = current_module
    else
        let index = "target/" . a:indexfile
    endif

    if !filereadable(index)
        echo "Building index, this may take a while"

        if exists("module")
            call system("mvn-classpath-index " . module . " &")
        else
            call system("mvn-classpath-index &")
        endif
    endif

    return index
endfunction

function! MvnFindClass(classname)
    let curline = line(".")
    let curcol  = col(".")

    let index = MvnBuildIndex("class-index.txt")

    if !filereadable(index)
        echohl Error
        echo "Class list not yet loaded, please try again later"
        echohl None
        return
    endif


    let grepcmd = "grep '\\<" . a:classname . "$' " . index . " | sort -u"
    let classes = split(system(grepcmd))

    if v:shell_error
        echohl Error
        echo "Class list not yet loaded, please try again later"
        echohl None
        return

    endif


    if len(classes) == 0
        echohl Error
        echo "No classes found"
        echohl None
        return
    elseif len(classes) == 1
        let class = classes[0]
    else
        let class_list = [ "Select a package:" ]
    
        for class in classes
            call add(class_list, len(class_list) . ". " . class)
        endfor

        let selected_class = inputlist(class_list)

        if selected_class > 0
            let class = classes[selected_class - 1]
        else
            return
        endif
    endif

    let statement = "import " . class . g:mvn_line_ending
    let slen      = strlen(statement)
    let winner    = 0
    let matchlen  = 0

    for lnum in range(line("$"))
        let lstr    = getline(lnum)
        let lstrlen = strlen(lstr)

        " If it's already in the file, just bail...
        if lstr == statement
            return
        endif

        if lstrlen < matchlen
            continue
        endif

        for i in range(matchlen, lstrlen)
            if strpart(lstr, 0, i) == strpart(statement, 0, i)
                let winner   = lnum
                let matchlen = i
            endif
        endfor
    endfor

    if matchlen == 0
        let winner = 1
    endif

    call cursor(winner, 0)

    call append(line("."), statement)

    call cursor(curline + 1, curcol)
endfunction

function! MvnSetClasspath()
    let classpath = MvnBuildIndex("classpath.txt")

    if !filereadable(classpath)
        echohl Error
        echo "Class path being generated, please try again later"
        echohl None
        return
    endif

    let $CLASSPATH = join(readfile(classpath, 'b'))
endfunction

function! MvnCleanupImports()
    " For returning the cursor to its original position
    let startline = line(".")
    let startcol  = col(".")
    let bufsize   = line("$")

    let classes   = {}
    let marklist  = []

    let firstline = 2
    let lmatch = 0

    for lnum in range(line("$"))
	let lstr    = getline(lnum)
	let lstrlen = strlen(lstr)

	if match(lstr, "^\\s*import") >= 0
	    let lmatch = 1

	    if firstline == 0
		let firstline = lnum
	    endif

	    call add(marklist, lnum)

	    let lhs   = join(split(lstr, "\\s\\s*")[1:-1], " ")
	    let class = substitute(lhs, ";$", "", "")

	    let classes[class] = 1

	elseif lmatch == 1 && getline(lnum) == ""
	    " If the last line was an import, and this line is empty, delete
	    " this line as well.
	    call add(marklist, lnum)
	else
	    let lmatch = 0
	endif
    endfor

    let deletes   = 0

    for lnum in marklist
	let target = (lnum - deletes)

	exe ":" . target . "d"

	let deletes += 1
    endfor

    let currentline = firstline
    let currentpkg  = ""

    for class in sort(keys(classes))
	let pathparts = split(class, "\\.")
	let keyword   = pathparts[-1]

	if match(keyword, "^[a-zA-Z0-9][a-zA-Z0-9_]*$") >= 0
		    \ && search("\\<" . keyword . "\\>", "wn") == 0
	    unlet classes[class]
	else
	    " When we have package names in our import list, we'll order each
	    " grouping of imports by the first package in the hierarchy, namely
	    " com, javax, et alli.
	    if len(pathparts) > 1
		let pkg = pathparts[0]

		if currentpkg != "" && currentpkg != pkg
		    call append(currentline, "")

		    let currentline += 1
		endif

		let currentpkg = pkg
	    endif

	    call append(currentline, "import " . class . g:mvn_line_ending)

	    let currentline += 1
	endif
    endfor

    " Add a line at the end for padding.
    call append(currentline, "")

    let newpos = startline + (line("$") - bufsize)
    call cursor(newpos, startcol)
endfunction

function! MvnEnglishName(name)
    let pos     = 0
    let results = []

    while pos != -1
        let endpos   = match(a:name, '[A-Z]', pos + 1)
        let results += [ tolower(a:name[pos : max([ endpos - 1, -1 ])]) ]
        let pos      = endpos
    endwhile

    return join(results, ' ')
endfunction MvnEnglishName

function! MvnAddAccessorDocumentation()
    let line  = getline(".")
    let parts = matchlist(line, '\(get\|is\|has\|set\)\([a-zA-Z_0-9]*\) *(')

    if len(parts) > 0
        let lineno = line(".")
        let type = parts[1]
        let name = MvnEnglishName(parts[2])
        let doc  = []
        let ind  = repeat(" ", indent(lineno))

        if type == "set"
            " It's a setter
            let argname = matchlist(line, '[^ ]* \([^ ]*\))')[1]
            let doc += [ ind . "/**" ]
            let doc += [ ind . " * Set the " . name . "." ]
            let doc += [ ind . " * @param " . argname . " The " . name ]
            let doc += [ ind . " */" ] 
        else
            let doc += [ ind . "/**" ] 
            let doc += [ ind . " * Get the " . name . "." ]
            let doc += [ ind . " * @return The " . name ]
            let doc += [ ind . " */" ]
        endif

        call append(lineno - 1, doc)
        call cursor(lineno + 4)
    endif 
endfunction MvnAddAccessorDocumentation


command! -nargs=0 MvnAutoCompile :call MvnAutoCompile()
command! -nargs=0 MvnListErrors :grep -iE 'Failures: [^0]\|Errors: [^0]' **/surefire-reports/*.txt
command! -nargs=1 MvnFindClass :call MvnFindClass(<args>)
command! -nargs=0 MvnEnableAspectj :let g:mvn_compiler_task = "aspectj:compile aspectj:testCompile"
command! -nargs=0 MvnSetClasspath :call MvnSetClasspath()
command! -nargs=0 MvnCleanupImports :call MvnCleanupImports()

map <Leader>mi :call MvnFindClass(expand("<cword>"))<CR>
map <Leader>mc :call MvnCleanupImports()<CR>
map <Leader>me :MvnListErrors
map <Leader>md :call MvnAddAccessorDocumentation()<CR>

" These are completely unweidly macros, they should become functions.
map <Leader>ma :mark N<CR>Vy<ESC>/^}<CR>kp:s/.*\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z]\)\([a-zA-Z][a-zA-Z]*\)\>.*/\r    public \2 get\U\3\E\4 () {\r        return \3\4;\r    }\r\r    public void set\U\3\E\4 (final \2 \3\4) {\r        this.\3\4 = \3\4;\r    }/<CR><CR>`N:let @/ = ""<CR>
map <Leader>mG :mark N<CR>Vy<ESC>/^}<CR>kp:s/.*\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z]\)\([a-zA-Z][a-zA-Z]*\)\>.*/\r    public \2 get\U\3\E\4 () {\r        return \3\4;\r    }/<CR><CR>`N:let @/ = ""<CR>
map <Leader>mg :mark N<CR>Vy<ESC>/^}<CR>kp:s/.*\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z][a-zA-Z]*\)  *\([a-zA-Z]\)\([a-zA-Z][a-zA-Z]*\)\>.*/\r    public \2 \3\4 () {\r        return \3\4;\r    }/<CR><CR>`N: @/ = ""<CR>
