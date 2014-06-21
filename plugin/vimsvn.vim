if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif
let s:tmpFile0 = tempname()
let s:tmpFile1 = tempname()
let s:changeListFile = tempname()
let s:changeSummaryFile = tempname()
let s:scriptName = expand('<sfile>:p')
let s:dirName = fnamemodify(s:scriptName, ":h") 
let s:pathToRoot = ''
let s:workingCopyRev = ''
let s:logEndRev = ''
let s:logNum = 500

"
" functions for map settings
"
function! SetupMapChangeList()
    :nnoremap <enter> :call GetChange()<enter>
    :nnoremap <c-n> :call GetNextRange()<enter>
    :nnoremap <c-p> :call GetPrevRange()<enter>
    :nnoremap q :q<enter>
endfunction

function! SetupMapChangeSummary()
    :nnoremap <enter> :call GetFileDiff()<enter>
    let l:cmd = ':nnoremap q :b ' . s:changeListFile. '<enter>'
    execute l:cmd
endfunction

function! SetupMapDiff()
    let l:cmd = 'nnoremap q :on<enter>:b ' . s:changeSummaryFile . '<enter>'
    ":echo l:cmd
    execute l:cmd
endfunction

function! UnmapAll()
    silent! :nunmap <enter>
    silent! :nunmap q
    silent! :nunmap <c-n>
    silent! :nunmap <c-p>
endfunction

"
" map switcher
"
function! SetupMap()
    :call UnmapAll()
    if &filetype == "SvnChangeList"
        call SetupMapChangeList()
    elseif &filetype == "SvnChangeSummary"
        call SetupMapChangeSummary()
    elseif &filetype == "SvnDiff"
        call SetupMapDiff()
    endif
endfunction

"
" autocmd settings
"
autocmd BufEnter * call SetupMap()
autocmd FileType SvnChangeList call SetupMapChangeList()
autocmd FileType SvnChangeSummary call SetupMapChangeSummary()
autocmd FileType SvnDiff call SetupMapDiff()

"
" entrance function
"
function! VimSvn()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    changeListFile = vim.eval("s:changeListFile")

    # setup buff
    vim.command(":silent e " + changeListFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnChangeList")

    svn = svnWrapper.SvnWrapper()
    # init and export variables
    (rv, pathToRoot, workingCopyRev) = svn.init()
    if rv != 0:
        return 1
    vim.command(":let s:pathToRoot = \"%s\""%(pathToRoot))
    vim.command(":let s:workingCopyRev = \"%s\""%(workingCopyRev))
    vim.command(":let s:logEndRev = \"%s\""%(workingCopyRev))
    logNum = vim.eval("s:logNum")

    vim.command(":let s:rv = UpdateChangeList()")
    rv = vim.eval("s:rv")
    if rv != 0:
        return 1
# run
func()

EOF
endfunction

"
" update change list.
" range of revision is specified by vim variable.
"
function! UpdateChangeList()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    vim.command(":setlocal noro")
    logEndRev = vim.eval("s:logEndRev")
    logNum = vim.eval("s:logNum")
    svn = svnWrapper.SvnWrapper()
    (rv, lines) = svn.getChangeList(logEndRev, logNum)
    if rv != 0:
        return 1

    del vim.current.buffer[:]
    i = 0
    for l in lines:
        if i == 0:
            vim.current.buffer[0] = l
        else:
            vim.current.buffer.append(l)
        i+=1
    vim.command(":silent w")
    vim.command(":setlocal ro")
# run
func()

EOF
endfunction

"
" get next range of change list
"
function! GetNextRange()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    logEndRev = int(vim.eval("s:logEndRev"))
    logNum = int(vim.eval("s:logNum"))
    logEndRev -= logNum
    vim.command(":let s:logEndRev = \"%s\""%(logEndRev))
    vim.command(":let s:rv = UpdateChangeList()")
    rv = vim.eval("s:rv")
    if rv != 0:
        return 1
# run
func()

EOF
endfunction

"
" get previous range of change list
"
function! GetPrevRange()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    workingCopyRev = int(vim.eval("s:workingCopyRev"))
    logEndRev = int(vim.eval("s:logEndRev"))
    logNum = int(vim.eval("s:logNum"))
    logEndRev += logNum
    if logEndRev > workingCopyRev:
        logEndRev = workingCopyRev
    vim.command(":let s:logEndRev = \"%s\""%(logEndRev))
    vim.command(":let s:rv = UpdateChangeList()")
    rv = vim.eval("s:rv")
    if rv != 0:
        return 1
# run
func()

EOF
endfunction

"
" get change summary of the revision below the cursor
"
function! GetChange()
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    changeSummaryFile = vim.eval("s:changeSummaryFile")

    # get revision
    rev = 0
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^([0-9]+):', line)
    if m:
        rev = m.group(1)

    # setup buff
    vim.command(":silent e "+changeSummaryFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnChangeSummary")

    svn = svnWrapper.SvnWrapper()
    lines = svn.getChangeSummary(rev)

    del vim.current.buffer[:]
    vim.current.buffer[0] = "rev: " + str(rev)
    for l in lines:
        vim.current.buffer.append(l)
    vim.command(":w")
    vim.command(":setlocal ro")
# run
func()

EOF
endfunction

"
" get difference between specified revision and its previous revision.
"
function! GetFileDiff()
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

pathToRoot = vim.eval("s:pathToRoot")
tmpFile0 = vim.eval("s:tmpFile0")
tmpFile1 = vim.eval("s:tmpFile1")

def func():
    rev = 0
    fileName = ""
    # get revision
    line = vim.current.buffer[0]
    m = re.match(r'rev: ([0-9]+)', line)
    if m:
        rev = m.group(1)

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^.*\t(.*)$', line)
    if m:
        fileName = pathToRoot + m.group(1)
    else:
        return

    svn = svnWrapper.SvnWrapper()
    lines = svn.getFileDiff(rev, fileName, tmpFile0, tmpFile1)
    vim.command(":e! " + tmpFile1)
    vim.command(":setlocal filetype=svndiff")
    vim.command(":setlocal ro")
    vim.command(":vert diffsplit " + tmpFile0)
    vim.command(":setlocal filetype=svndiff")
    vim.command(":setlocal ro")
# run
func()

EOF
endfunction
