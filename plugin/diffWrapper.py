"""
Copyright (c) 2013, katonori All rights reserved.

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
import sys
import getopt
import shutil
import commands

argvs = sys.argv
argc = len(argvs)

fileList = []
tmpFileList = ['', '']

# parse args
try:
    opts, args = getopt.getopt(sys.argv[1:], 'L:0:1:')
except getopt.GetoptError:
    usage()
    sys.exit(1)
output = None
for o, a in opts:
    if o == '-L':
        fileList.append(a)
    elif o == '-0':
        tmpFileList[0] = a;
    elif o == '-1':
        tmpFileList[1] = a;

if len(args) != 2:
    print "ERROR: arg num is not correct"
    sys.exit(1)

shutil.copy(args[0], tmpFileList[0])
shutil.copy(args[1], tmpFileList[1])

if fileList[0]:
    print fileList[0],
print '|',
if fileList[1]:
    print fileList[1],
