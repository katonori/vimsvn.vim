"Copyright (c) 2013, katonori All rights reserved.
"
"Redistribution and use in source and binary forms, with or without modification, are
"permitted provided that the following conditions are met:
"
"  1. Redistributions of source code must retain the above copyright notice, this list
"     of conditions and the following disclaimer.
"  2. Redistributions in binary form must reproduce the above copyright notice, this
"     list of conditions and the following disclaimer in the documentation and/or other
"     materials provided with the distribution.
"  3. Neither the name of the katonori nor the names of its contributors may be used to
"     endorse or promote products derived from this software without specific prior
"     written permission.
"
"THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
"EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
"OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
"SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
"INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
"TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
"BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
"CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
"ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
"DAMAGE.

if !has('python')
    echo "Error: Required vim compiled with +python"
    finish
endif
let s:tmpFile0 = tempname()
let s:tmpFile1 = tempname()
let s:changeListFile = tempname()
let s:changeSummaryFile = tempname()
let s:statFile = tempname()
let s:scriptName = expand('<sfile>:p')
let s:dirName = fnamemodify(s:scriptName, ":h") 
let s:logNum = 500
let s:prevBufName = ""
let s:logFile = tempname()

"
" functions for map settings
"
function! SetupMapChangeListView()
    :nnoremap <enter> :call GetChange()<enter>
    :nnoremap <c-n> :call GetNextRange()<enter>
    :nnoremap <c-p> :call GetPrevRange()<enter>
    :nnoremap q :q<enter>
endfunction

function! SetupMapChangeSummaryView()
    :nnoremap <enter> :call GetFileDiff(0)<enter>
    let l:cmd = ':nnoremap q :b ' . s:changeListFile. '<enter>'
    execute l:cmd
endfunction

function! SetupMapStatView()
    :nnoremap <enter> :call GetFileDiff(1)<enter>
    let l:cmd = ':nnoremap q :q<enter>'
    execute l:cmd
endfunction

function! SetupMapDiffView()
    let l:cmd = 'nnoremap q :on<enter>:b ' . s:prevBufName . '<enter>'
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
    if &filetype == "SvnChangeListView"
        call SetupMapChangeListView()
    elseif &filetype == "SvnChangeSummaryView"
        call SetupMapChangeSummaryView()
    elseif &filetype == "SvnStatView"
        call SetupMapStatView()
    elseif &filetype == "SvnDiffView"
        call SetupMapDiffView()
    endif
endfunction

"
" autocmd settings
"
autocmd BufEnter * call SetupMap()
autocmd FileType SvnChangeListView call SetupMapChangeListView()
autocmd FileType SvnChangeSummaryView call SetupMapChangeSummaryView()
autocmd FileType SvnStatView call SetupMapStatView()
autocmd FileType SvnDiffView call SetupMapDiffView()

"
" entrance function
"
function! SvnGetLog()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    changeListFile = vim.eval("s:changeListFile")
    logFile = vim.eval("s:logFile")

    # setup buff
    vim.command(":silent e " + changeListFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnChangeListView")

    svn = svnWrapper.getInstance(logFile)

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
    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    vim.command(":setlocal noro")
    logEndRev = svn.getWorkingCopyRev()
    logNum = vim.eval("s:logNum")
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
    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    vim.command(":setlocal noro")
    logNum = vim.eval("s:logNum")
    (rv, lines) = svn.getNextChangeList(logNum)
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
    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    vim.command(":setlocal noro")
    logNum = vim.eval("s:logNum")
    (rv, lines) = svn.getPrevChangeList(logNum)
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
    vim.command(":silent e " + changeSummaryFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnChangeSummaryView")

    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    lines = svn.getChangeSummary(rev)

    del vim.current.buffer[:]
    vim.current.buffer[0] = "rev: " + str(rev)
    for l in lines:
        vim.current.buffer.append(l)
    vim.command(":w")
    vim.command(":setlocal ro")
    vim.command(":let s:prevBufName = " + "'" + changeSummaryFile + "'")
# run
func()

EOF
endfunction

"
" get difference between specified revision and its previous revision.
"
function! GetFileDiff(isLocal)
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

tmpFile0 = vim.eval("s:tmpFile0")
tmpFile1 = vim.eval("s:tmpFile1")
isLocal = vim.eval("a:isLocal")

def func():
    rev = 0
    fileName = ''
    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)

    if isLocal != '0':
        rev = -1
    else:
        # get revision
        line = vim.current.buffer[0]
        m = re.match(r'rev: ([0-9]+)', line)
        if m:
            rev = m.group(1)
        else:
            print "ERROR: could not detect revision."

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^M\t\t(.*)$', line)
    if m:
        fileName = m.group(1)
    else:
        return

    file0 = ''
    file1 = ''
    if isLocal == '0':
        file0 = tmpFile0
        file1 = tmpFile1
    else:
        file0 = tmpFile0
        file1 = fileName

    lines = svn.getFileDiff(rev, fileName, tmpFile0, tmpFile1)
    vim.command(":view! " + file1)
    vim.command(":setlocal filetype=SvnDiffView")
    vim.command(":vert diffsplit " + file0)
    vim.command(":setlocal filetype=SvnDiffView")
    vim.command(":setlocal ro")
# run
func()

EOF
endfunction

"
" get current status of working copy
"
function! SvnGetStat()
python << EOF
import vim
import sys
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    statFile = vim.eval("s:statFile")

    # setup buff
    vim.command(":silent e " + statFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnStatView")

    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    statList =svn.getStat()
    del vim.current.buffer[:]
    vim.current.buffer[0] = "rev: " + str(svn.getWorkingCopyRev())
    for s in statList:
        (stat, path) = s
        line = stat + "\t\t" + path
        vim.current.buffer.append(line)
    vim.command(":w")
    vim.command(":setlocal ro")
    vim.command(":let s:prevBufName = " + "'" + statFile + "'")

# run
func()

EOF
endfunction

function! SvnOpenLog()
    execute "split " . s:logFile
endfunction

