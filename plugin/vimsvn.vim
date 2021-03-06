"Copyright (c) 2014, katonori All rights reserved.
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
let s:isDiffLocal = 0

"
" define commands
"
command! -nargs=? -complete=file SvnGetLog :call <SID>SvnGetLogWrapper(<q-args>)
command! -nargs=0 SvnGetLogRoot :call <SID>SvnGetLogWrapperRoot()
command! -nargs=? -complete=file SvnGetStat :call <SID>SvnGetStatWrapper(<q-args>)
command! -nargs=0 SvnGetStatRoot :call <SID>SvnGetStatWrapperRoot()
command! -nargs=0 SvnOpenLog :call <SID>SvnOpenLog()
command! -nargs=0 SvnGetLogNextRange :call <SID>SvnGetLogNextRange()
command! -nargs=0 SvnGetLogPrevRange :call <SID>SvnGetLogPrevRange()
command! -nargs=0 SvnGetFileDiff :call <SID>SvnGetFileDiff()
command! -nargs=0 SvnGetChange :call <SID>SvnGetChange()
command! -nargs=0 SvnToggleCommit :call <SID>SvnToggleCommit()
command! -nargs=0 SvnCommitMarkedItems :call <SID>SvnCommitMarkedItems()
command! -nargs=0 SvnAddFile :call <SID>SvnAddFile()
command! -nargs=0 SvnRevertFile :call <SID>SvnRevertFile()

"
" functions for map settings
"
function! s:SetupMapChangeListView()
    nnoremap <buffer> <enter> :call <SID>SvnGetChange()<enter>
    nnoremap <buffer> <c-n> :call <SID>SvnGetLogNextRange()<enter>
    nnoremap <buffer> <c-p> :call <SID>SvnGetLogPrevRange()<enter>
    syntax match revisionNum '^[0-9]\+'
    syntax match dateNum ' [0-9\-T:\.]\+Z'
    highlight link revisionNum Number
    highlight link dateNum Comment
endfunction

function! s:SetupMapChangeSummaryView()
    nnoremap <buffer> <enter> :call <SID>SvnGetFileDiff()<enter>
    let l:cmd = ':nnoremap <buffer> q :b ' . s:changeListFile. '<enter>'
    execute l:cmd
    syntax match modeified '^M'
    syntax match added '^A'
    syntax match deleted '^D'
    highlight link modeified Macro
    highlight link added Comment
    highlight link deleted Number
endfunction

function! s:SetupMapStatView()
    nnoremap <buffer> <enter> :call <SID>SvnGetFileDiff()<cr>
    nnoremap <buffer> <space> :call <SID>SvnToggleCommit()<cr>
    vnoremap <buffer> <space> :call <SID>SvnToggleCommit()<cr>
    nnoremap <buffer> a :call <SID>SvnAddFile()<cr>
    vnoremap <buffer> a :call <SID>SvnAddFile()<cr>
    nnoremap <buffer> r :call <SID>SvnRevertFile()<cr>
    vnoremap <buffer> r :call <SID>SvnRevertFileRange()<cr>
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
" view log
"
function! s:SvnGetLogWrapperRoot()
    return s:SvnGetLog("")
endfunction

"
" view log
"
function! s:SvnGetLogWrapper(dir)
    if a:dir == ""
        return s:SvnGetLog(".")
    endif
    return s:SvnGetLog(a:dir)
endfunction

"
" view log
"
function! s:SvnGetLog(dir)
python << EOF
# add script directory to search path
import vim, sys
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    dirname = vim.eval("a:dir")
    changeListFile = vim.eval("s:changeListFile")
    logFile = vim.eval("s:logFile")

    # setup buff
    vim.command(":silent e " + changeListFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnChangeListView")

    svn = svnWrapper.getInstance(logFile)

    logNum = vim.eval("s:logNum")

    vim.command(":let s:rv = s:UpdateChangeList('" + dirname +"')")
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
function! s:UpdateChangeList(dir)
python << EOF
# add script directory to search path
import vim, sys
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    dirname = vim.eval("a:dir")
    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    vim.command(":setlocal noro")
    logEndRev = svn.getWorkingCopyRev()
    logNum = vim.eval("s:logNum")
    (rv, lines) = svn.getChangeList(logEndRev, dirname, logNum)
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
# add script directory to search path
import vim, sys
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
# add script directory to search path
import vim, sys
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
function! s:SvnGetChange()
    let s:isDiffLocal = 0
python << EOF
# add script directory to search path
import vim, sys, re
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
function! s:SvnGetFileDiff()
python << EOF
# add script directory to search path
import vim, sys, re
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

tmpFile0 = vim.eval("s:tmpFile0")
tmpFile1 = vim.eval("s:tmpFile1")
isLocal = vim.eval("s:isDiffLocal")

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
function! s:SvnAddFile()
python << EOF
# add script directory to search path
import vim, sys, re
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
    vim.command(":call s:SvnGetStat('.')")

# run
func()

EOF
endfunction

"
" revert file
"
function! s:SvnRevertFile()
    call s:SvnRevertFileOne(getline(line(".")))
    call s:SvnGetStat('.')
endfunction

"
" revert file
"
function! s:SvnRevertFileRange() range
    let l:start = line("'<")
    let l:end = line("'>")
    for l:i in range(l:start, l:end)
        call s:SvnRevertFileOne(getline(l:i))
    endfor
    call s:SvnGetStat('.')
endfunction

"
" revert file
"
function! s:SvnRevertFileOne(line)
python << EOF
# add script directory to search path
import vim, sys, re
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = ''
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # get fileName
    line = vim.eval("a:line")
    m = re.match(r'^[AMD]\t\t(.*)$', line)
    if m:
        fileName = m.group(1)
    else:
        return

    svn.revertFile(fileName)

# run
func()

EOF
endfunction

"
" 
"
function! s:SvnToggleCommit()
python << EOF
# add script directory to search path
import vim, sys, re
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileName = ''
    mark = ''
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # get fileName
    (row, col) = vim.current.window.cursor
    line = vim.current.buffer[row-1]
    m0 = re.match(r'(^[AMD])\t\t(.*)$', line)
    m1 = re.match(r'(^[AMD])\t\*\t(.*)$', line)
    if m0:
        mark = m0.group(1)
        fileName = m0.group(2)
        # mark as to be committed
        vim.command(":set noro")
        vim.current.buffer[row-1] = mark + "\t*\t" + fileName
        vim.command(":w")
        vim.command(":set ro")
    elif m1: # marked as to be committed
        mark = m1.group(1)
        fileName = m1.group(2)
        # mark as to be committed
        vim.command(":set noro")
        vim.current.buffer[row-1] = mark + "\t\t" + fileName
        vim.command(":w")
        vim.command(":set ro")
    else:
        return

# run
func()

EOF
endfunction

"
" commit file
"
function! s:SvnCommitMarkedItems()
python << EOF
# add script directory to search path
import vim, sys, re, os
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    fileList = []
    svn = svnWrapper.getInstance(vim.eval("s:logFile"))

    # make commit list
    for l in vim.current.buffer:
        m = re.match(r'^[AMD]\t\*\t(.*)$', l)
        if m:
            fileList.append(m.group(1))

    if fileList != []:
        vim.command(":new!" + vim.eval("s:commitMsg"))
        del  vim.current.buffer[:]
        vim.current.buffer.append("--This line, and those below, will be ignored--")
        for l in fileList:
            vim.current.buffer.append(l)
        svn.setCommitList(fileList)
        vim.command(":silent w!")
        vim.command(":autocmd BufUnload <buffer> call s:SvnDoCommit()")
# run
func()

EOF
endfunction

"
" commit file
"
function! s:SvnDoCommit()
python << EOF
# add script directory to search path
import vim, sys, re, os
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    commitMsgFile = vim.eval("s:commitMsg")
    f = open(commitMsgFile)
    lines = []
    doCommitFlag = False
    isValidMsg = False
    for l in f:
        if re.match(r'--This line, and those below, will be ignored--', l):
            doCommitFlag = True
            break
        m = re.match(r'\S+', l)
        if m:
            isValidMsg = True
        lines.append(l)
    f.close()

    if doCommitFlag == True and isValidMsg == True:
        f = open(commitMsgFile, "w")
        f.writelines(lines)
        f.close()
        svn = svnWrapper.getInstance(vim.eval("s:logFile"))
        if os.path.getsize(commitMsgFile) != 0:
            rv = svn.commitList(commitMsgFile)
            if rv != 0:
                vim.command("echo 'ERROR: svn: commit failed. invoke SvnOpenLog to open log'")

        vim.command(":call s:SvnGetStat('.')")
# run
func()

EOF
endfunction

"
" get current status of working copy
"
function! s:SvnGetStatWrapper(dir)
    if a:dir == ""
        return s:SvnGetStat(".")
    endif
    return s:SvnGetStat(a:dir)
endfunction

"
" get current status of working copy
"
function! s:SvnGetStatWrapperRoot()
    return s:SvnGetStat("")
endfunction

"
" get current status of working copy
"
function! s:SvnGetStat(dir)
    let s:isDiffLocal = 1
python << EOF
# add script directory to search path
import vim, sys
sys.path.append(vim.eval("s:dirName"))
import svnWrapper

def func():
    statFile = vim.eval("s:statFile")
    statDir = vim.eval("a:dir")

    # setup buff
    vim.command(":silent e " + statFile)
    vim.command(":setlocal noswapfile")
    vim.command(":setlocal filetype=SvnStatView")

    logFile = vim.eval("s:logFile")
    svn = svnWrapper.getInstance(logFile)
    statList =svn.getStat(statDir)
    del vim.current.buffer[:]
    vim.current.buffer[0] = "rev: " + str(svn.getWorkingCopyRev())
    for s in statList:
        (stat, path) = s
        line = stat + "\t\t" + path
        vim.current.buffer.append(line.encode('utf-8'))
    vim.command(":silent w!")
    vim.command(":setlocal ro")
    vim.command(":let s:prevBufName = " + "'" + statFile + "'")

# run
func()

EOF
endfunction

function! s:SvnOpenLog()
    execute "split " . s:logFile
endfunction
