#!/usr/bin/perl
my $win7x64 = `/share/work/drakvuf-ci/dom0/clone.pl windows7-sp1-x64`;
my $taskmgr_win7x64 = `/share/work/drakvuf-ci/dom0/findtaskmgr.sh windows7-sp1-x64-jenkins`;
chomp($taskmgr_win7x64);

my $win7x86 = `/share/work/drakvuf-ci/dom0/clone.pl windows7-sp1-x86`;
my $taskmgr_win7x86 = `/share/work/drakvuf-ci/dom0/findtaskmgr.sh windows7-sp1-x86-jenkins`;
chomp($taskmgr_win7x86);

print "win7x64:$win7x64:$taskmgr_win7x64,win7x86:$win7x86:$taskmgr_win7x86,";
