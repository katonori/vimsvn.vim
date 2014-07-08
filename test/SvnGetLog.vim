" log list
:SvnGetLog
:w! res0-0.txt
:SvnGetLogNextRange
:w! res0-1.txt
:SvnGetLogNextRange
:w! res0-2.txt
:SvnGetLogPrevRange
:w! res0-3.txt
:SvnGetLogPrevRange
:w! res0-4.txt

" change summary
:14
:SvnGetChange
:w! res0-5.txt
:2
:SvnGetFileDiff
:w! res0-6.txt
:normal l
:w! res0-7.txt

:q
:q
