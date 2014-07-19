" stat
:silent !svn del 0.txt dir0
:silent !echo "asdf" > 1.txt
:silent !touch 2.txt
:silent !svn add 2.txt
:silent !touch 0/a.txt
:silent !svn add 0/a.txt

:SvnGetStat
:w! res1-0.txt
:cd 0
:SvnGetStat
:w! ../res1-1.txt
:cd ..

:silent !svn revert 0.txt 2.txt dir0 0/a.txt
:silent !echo "" > 1.txt

:q

