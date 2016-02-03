#!/usr/bin/perl
my $win7x64 = `/share/jenkins/clone.pl windows7-sp1-x64 0 /share/cfg/windows7-sp1-x64.cfg`;
my $taskmgr_win7x64 = `/share/jenkins/findtaskmgr.sh windows7-sp1-x64-0-clone`;
chomp($taskmgr_win7x64);

my $win7x86 = `/share/jenkins/clone.pl windows7-sp1-x86 0 /share/cfg/windows7-sp1-x86.cfg`;
my $taskmgr_win7x86 = `/share/jenkins/findtaskmgr.sh windows7-sp1-x86-0-clone`;
chomp($taskmgr_win7x86);

print "win7x64:$win7x64:$taskmgr_win7x64,win7x86:$win7x86:$taskmgr_win7x86,";
