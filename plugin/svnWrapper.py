"""
Copyright (c) 2014, katonori All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list
     of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice, this
     list of conditions and the following disclaimer in the documentation and/or other
     materials provided with the distribution.
  3. Neither the name of the katonori nor the names of its contributors may be used to
     endorse or promote products derived from this software without specific prior
     written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
"""
from xml.etree.ElementTree import *
import commands
import re
import tempfile
import os

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))

# keep instance used from vim here
gInstance = None

class SvnWrapper:
    mWorkingCopyRev = 0
    mRelPathToRoot = '' # relative path to root of the working copy
    mLogEndRev = 0
    mLogStartRev = 0
    mLogFile = ''
    mPipe = ''
    mCommitList = []

    """
    " get repository information
    """
    def getReposInfo(self):
        global gRelPathToRoot
        cmd = 'svn info --xml'
        self.appendToLog(cmd)
        #print "cmd: " + cmd
        (rv, out) = commands.getstatusoutput(cmd)
        self.appendToLog(out)
        if 0 != rv:
            print "ERROR: could not get information from working copy"
            print out
            return 1
        root = fromstring(out)
        entry = root.find('entry')
        self.mWorkingCopyRev = entry.get('revision')
        curUrl = root.findtext('.//url') # url of current directory
        reposRoot = root.findtext('.//root')

        # get relative path to repository root
        curUrlBody = re.sub(r'^.+://', '', curUrl)
        reposRootBody = re.sub(r'^.+://', '', reposRoot)
        pathDiff = curUrlBody.replace(reposRootBody, '', 1) # FIXME: use re

        i = 0
        end = pathDiff.count('/') - 1
        self.mRelPathToRoot = './'
        while i < end:
            self.mRelPathToRoot += '../'
            i += 1

        #root = root.findtext('root')
        #print 'rev: ' + self.mWorkingCopyRev
        #print 'url: ' + str(curUrl)
        #print 'root: ' + reposRoot
        #print 'relPath: ' + self.mRelPathToRoot
        gRelPathToRoot = self.mRelPathToRoot
        return 0

    def getGlobal(self):
        global gRelPathToRoot
        return gRelPathToRoot

    def setCommitList(self, itemList):
        self.mCommitList = itemList

    """
    " get summary of changes at a revision
    """
    def getChangeSummary(self, rev):
        rev = int(rev)
        cmpRevStr = str(rev-1) + ':' + str(rev)

        # get log in xml format
        cmd = 'svn diff --summarize --xml -r %s '%(cmpRevStr) + self.mRelPathToRoot
        self.appendToLog(cmd)
        out = commands.getoutput(cmd)
        self.appendToLog(out)
        elem = fromstring(out)
        changeList = [] 

        # get changed list
        for e in elem.findall(".//path"):
            #changeList.append((e.get('item'), e.get('kind'), e.text))
            path = e.text
            item = e.get('item')
            if item == 'modified':
                item = 'M'
            elif item == 'added':
                item = 'A'
            kind = e.get('kind')
            if kind == 'dir':
                path += '/'
            changeList.append("%s\t\t%s"%(item, path))
        return changeList

    def getFileDiff(self, rev, path, tmpFile0, tmpFile1):
        rev = int(rev)
        if rev < 0:
            cmpRevStr = ''
        else:
            cmpRevStr = '-r ' + str(rev-1) + ':' + str(rev)
        cmd = 'svn diff ' + cmpRevStr + ' --diff-cmd="python" -x "%s/diffWrapper.py -0 %s -1 %s" '%(SCRIPT_DIR, tmpFile0, tmpFile1) + path
        self.appendToLog(cmd)
        diffOut = commands.getoutput(cmd)
        self.appendToLog(diffOut)
        #print diffOut
        lines = diffOut.split('\n')
        return lines[-1]

    def addFile(self, file):
        cmd = 'svn add %s'%(file)
        self.appendToLog(cmd)
        diffOut = commands.getoutput(cmd)
        self.appendToLog(diffOut)
        return 

    def revertFile(self, file):
        cmd = 'svn revert %s'%(file)
        self.appendToLog(cmd)
        diffOut = commands.getoutput(cmd)
        self.appendToLog(diffOut)
        return 

    """
    " commit items stored in list
    """
    def commitList(self, log):
        files = ""
        for f in self.mCommitList:
            files += ' "' + f + '"'
        cmd = 'svn ci --file %s %s'%(log, files)
        self.appendToLog(cmd)
        (rv, out) = commands.getstatusoutput(cmd)
        self.appendToLog(out)
        return rv

    def getChangeList(self, endRev, num):
        endRev = int(endRev)
        if endRev > self.mWorkingCopyRev: # currently log of newer revision of working copy is not allowed
            endRev = self.mWorkingCopyRev
        num = int(num)
        startRev = endRev - num + 1
        if startRev < 0:
            startRev = 0
        cmd = 'svn log --xml -r ' + str(endRev) + ':' + str(startRev) + " " + self.mRelPathToRoot
        self.mLogStartRev = int(startRev)
        self.mLogEndRev = int(endRev)

        self.appendToLog(cmd)
        (rv, out) = commands.getstatusoutput(cmd)
        self.appendToLog(out)
        if rv != 0:
            print "ERROR: could not get log"
            print out
            return (1, [])
        elem = fromstring(out)
        logStr = ''
        lines = []
        i = 0
        for e in elem.getiterator('logentry'):
            rev = e.get('revision')
            date = e.findtext('date')
            msg = e.findtext('msg')
            author = e.findtext('author')
            lines.append('%s| %s| %s| %s'%(rev, date, author, msg.replace('\n', ' ')))
            i += 1
        return (0, lines)

    def getStat(self, isRoot):
        cmd = 'svn stat --xml '
        if int(isRoot) != 0:
            cmd = 'svn stat --xml ' + self.mRelPathToRoot
        self.appendToLog(cmd)
        out = commands.getoutput(cmd)
        self.appendToLog(out)
        root = fromstring(out)
        entries = root.findall('.//entry')
        outList = []
        for e in entries:
            path = e.get('path')
            stat = e.find('wc-status').get('item')
            outList.append((self.getStatChar(stat), path))
        return outList

    def getStatChar(self, str):
        if str == 'unversioned':
            return '?'
        elif str == 'modified':
            return 'M'
        elif str == 'deleted':
            return 'D'
        elif str == 'added':
            return 'A'
        else:
            return str

    def getNextChangeList(self, num):
        return self.getChangeList(self.mLogStartRev-1, num)

    def getPrevChangeList(self, num):
        return self.getChangeList(self.mLogEndRev+int(num), num)

    def getRelPathToRoot(self):
        return self.mRelPathToRoot

    def getWorkingCopyRev(self):
        return self.mWorkingCopyRev

    def appendToLog(self, log):
        f = open(self.mLogFile, 'a')
        f.write(log)
        f.close()

    """
    " init and export variables
    """
    def init(self, logfile):
        self.mLogFile = logfile
        return self.getReposInfo()

def getInstance(logfile):
    global gInstance
    if gInstance is None:
        gInstance = SvnWrapper()
    gInstance.init(logfile)
    return gInstance

if __name__ == '__main__':
    svn = SvnWrapper()
    #svn.run()
