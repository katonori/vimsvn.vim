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
let s:logNum = 200
let s:prevBufName = ""
let s:logFile = tempname()
let s:commitMsg = tempname()
let s:statLineOrig = &statusline

"
" define commands
"
command! -nargs=0 SvnGetLog :call <SID>SvnGetLog()
command! -nargs=0 SvnGetStat :call <SID>SvnGetStat()
command! -nargs=0 SvnOpenLog :call <SID>SvnOpenLog()
command! -nargs=0 SvnGetLogNextRange :call <SID>SvnGetLogNextRange()
command! -nargs=0 SvnGetLogPrevRange :call <SID>SvnGetLogPrevRange()

"
" functions for map settings
"
function! s:SetupMapChangeListView()
    nnoremap <enter> :call <SID>GetChange()<enter>
    nnoremap <c-n> :call <SID>SvnGetLogNextRange()<enter>
    nnoremap <c-p> :call <SID>SvnGetLogPrevRange()<enter>
    nnoremap q :q<enter>
    syntax match revisionNum '^[0-9]\+'
    syntax match dateNum ' [0-9\-T:\.]\+Z'
    highlight link revisionNum Number
    highlight link dateNum Comment
endfunction

function! s:SetupMapChangeSummaryView()
    :nnoremap <enter> :call <SID>GetFileDiff(0)<enter>
    let l:cmd = ':nnoremap q :b ' . s:changeListFile. '<enter>'
    execute l:cmd
    syntax match modeified '^M'
    syntax match added '^A'
    syntax match deleted '^D'
    highlight link modeified Macro
    highlight link added Comment
    highlight link deleted Number
endfunction

function! s:SetupMapStatView()
    :nnoremap <enter> :call <SID>GetFileDiff(1)<enter>
    let l:cmd = ':nnoremap q :q<enter>'
    execute l:cmd
    syntax match modeified '^M'
    syntax match added '^A'
    syntax match deleted '^D'
    highlight link modeified Macro
    highlight link added Comment
    highlight link deleted Number
endfunction

function! s:SetupMapDiffView()
    let l:cmd = 'nnoremap q <c-w>c<c-w>p:b ' . s:prevBufName . '<enter>'
    ":echo l:cmd
    execute l:cmd
endfunction

function! s:UnmapAll()
    silent! :nunmap <enter>
    silent! :nunmap q
    silent! :nunmap <c-n>
    silent! :nunmap <c-p>
endfunction

"
" map switcher
"
function! s:SetupMap()
    :call <SID>UnmapAll()
    if &filetype == "SvnChangeListView"
        call <SID>SetupMapChangeListView()
    elseif &filetype == "SvnChangeSummaryView"
        call <SID>SetupMapChangeSummaryView()
    elseif &filetype == "SvnStatView"
        call <SID>SetupMapStatView()
    elseif &filetype == "SvnDiffView"
        call <SID>SetupMapDiffView()
    endif
endfunction

"
" autocmd settings
"
autocmd BufEnter * call <SID>SetupMap()
autocmd FileType SvnChangeListView call <SID>SetupMapChangeListView()
autocmd FileType SvnChangeSummaryView call <SID>SetupMapChangeSummaryView()
autocmd FileType SvnStatView call <SID>SetupMapStatView()
autocmd FileType SvnDiffView call <SID>SetupMapDiffView()

"
" entrance function
"
function! s:SvnGetLog()
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

    vim.command(":let s:rv = s:UpdateChangeList()")
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
function! s:UpdateChangeList()
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
            vim.current.buffer[0] = l.encode('utf-8')
        else:
            vim.current.buffer.append(l.encode('utf-8'))
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
function! s:SvnGetLogNextRange()
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
            vim.current.buffer[0] = l.encode('utf-8')
        else:
            vim.current.buffer.append(l.encode('utf-8'))
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
function! s:SvnGetLogPrevRange()
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
            vim.current.buffer[0] = l.encode('utf-8')
        else:
            vim.current.buffer.append(l.encode('utf-8'))
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
function! s:GetChange()
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
    m = re.match(r'^([0-9]+)|', line)
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
        vim.current.buffer.append(l.encode('utf-8'))
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
function! s:GetFileDiff(isLocal)
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
    fileInfos = lines.split('|')
    vim.command(":view! " + file1)
    vim.command(":setlocal filetype=SvnDiffView")
    # setup status line
    statline = vim.eval("s:statLineOrig")
    fileInfos[1] = fileInfos[1].replace('revision', 'r')
    statline = '[' + re.sub('[ \t]', '', fileInfos[1]) + '] ' + statline
    statline = statline.replace(' ', '\ ')
    statline = statline.replace('	', '\	')
    vim.command(":setlocal statusline=%s"%(statline))

    vim.command(":vert diffsplit " + file0)
    # setup status line
    statline = vim.eval("s:statLineOrig")
    fileInfos[0] = fileInfos[0].replace('revision', 'r')
    statline = '[' + re.sub('[ \t]', '', fileInfos[0]) + '] ' + statline
    statline = statline.replace(' ', '\ ')
    statline = statline.replace('	', '\	')
    vim.command(":setlocal statusline=%s"%(statline))
    vim.command(":setlocal filetype=SvnDiffView")
    vim.command(":setlocal ro")
# run
func()

EOF
endfunction

"
" add file to repository
"
function! SvnAddFile()
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = ''
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^\?\t\t(.*)$', line)
    if m:
        fileName = m.group(1)
    else:
        return

    svn.addFile(fileName)
    vim.command(":call SvnGetStat()")

# run
func()

EOF
endfunction

"
" revert file
"
function! SvnRevertFile()
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = ''
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^[AMD]\t\t(.*)$', line)
    if m:
        fileName = m.group(1)
    else:
        return

    svn.revertFile(fileName)
    vim.command(":call SvnGetStat()")

# run
func()

EOF
endfunction

"
" commit file
"
function! SvnCommitFile(fileName)
python << EOF
import vim
import sys
import re
import os
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = vim.eval("a:fileName")
    commitMsgFile = vim.eval("s:commitMsg")
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))
    if os.path.getsize(commitMsgFile) != 0:
        svn.commitFile(fileName, commitMsgFile)
        vim.command(":call SvnGetStat()")

# run
func()

EOF
endfunction

"
" commit file
"
function! SvnEditCommitLog()
python << EOF
import vim
import sys
import re
# add script directory to search path
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = ''
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m = re.match(r'^[AMD]\t\t(.*)$', line)
    if m:
        fileName = m.group(1)
    else:
        return

    vim.command(":new! " + vim.eval("s:commitMsg"))
    vim.command("setlocal statusline=[commit\ message\ buffer]\ add\ message\ and\ close\ to\ check\ in.\ close\ buffer\ leaving\ empty\ to\ cancel:\ " + vim.eval("s:commitMsg"))
    del vim.current.buffer[:]
    vim.command(":autocmd BufUnload <buffer> call SvnCommitFile(" + "'" + fileName + "')")

# run
func()

EOF
endfunction

"
" get current status of working copy
"
function! s:SvnGetStat()
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
        vim.current.buffer.append(line.encode('utf-8'))
    vim.command(":w!")
    vim.command(":setlocal ro")
    vim.command(":let s:prevBufName = " + "'" + statFile + "'")

# run
func()

EOF
endfunction

function! s:SvnOpenLog()
    execute "split " . s:logFile
endfunction

