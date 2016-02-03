#!/usr/bin/perl

 our $timeout = 30; # in seconds
 our $workspace = $ARGV[0];
 our $libvmipath = $ARGV[1];

#############################################################
sub cleanup {
    if (defined $_[0]) {
        `sudo xl pause $_[0]`;
    }

    # Kill any hung processes
    `sudo killall drakvuf 2>&1 > /dev/null`;
    `sudo killall injector 2>&1 > /dev/null`;
}

sub test {
    my $vm = $_[0];
    my $domid = $_[1];
    my $taskmgr = $_[2];

    print "Running Injector for calc.exe through PID $taskmgr\n";
    eval {
        local $SIG{ALRM} = sub { die "alarm2\n" }; # NB: \n required
        alarm $timeout;
        system("sudo LD_LIBRARY_PATH=$libvmipath/lib $workspace/src/injector /opt/jenkins/$vm.json $domid $taskmgr calc.exe 2>&1 > $workspace/output2.txt");
        alarm 0;
    };

    if ($@ eq "alarm2\n") {
        print "Injection failed in $timeout seconds\n";
        cleanup($domid);
        exit 1;    
    } else {
        my $output = `cat $workspace/output2.txt | grep "Process startup success" | wc -l`;
        chomp($output);
        if ($output eq "0") {
            `cat $workspace/output2.txt`;
            cleanup($domid);
            exit 1;
        } else {
            chomp($output);
            print "Injection worked ($output)\n";
        }
    }

    print "Running DRAKVUF for $timeout seconds\n";
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
        alarm $timeout;
        system("sudo LD_LIBRARY_PATH=$libvmipath/lib $workspace/src/drakvuf -r /opt/jenkins/$vm.json -d $domid 2>&1 > $workspace/output.txt");
        alarm 0;
    };

    my $drakvuf_pid = `/opt/jenkins/findpid.sh`;
    if ($drakvuf_pid ne "") {
        #print "DRAKVUF PID: $drakvuf_pid\n";
        `sudo kill -SIGINT $drakvuf_pid`;
    }

    if ($@ eq "alarm\n") {    
        my $bps = `grep "SYSCALL" $workspace/output.txt | wc -l`;
        chomp($bps);

        if ($bps eq "0") {
            print "No syscalls were hit\n";
            cleanup($domid);
            exit 1;
        }
        print "Syscalls trapped: $bps\n";

        my $files = `grep "FILETRACER" $workspace/output.txt | wc -l`;
        chomp($files);

        if ($files eq "0") {
            print "No files were accessed\n";
            cleanup($domid);
            exit 1;
        }
        print "Files accessed: $files\n";

    } else {
        print "DRAKVUF exited before timeout\n";
        `cat $workspace/output.txt`;
        cleanup($domid);
        exit 1;
    }

    `sudo xl pause $domid`;
}
#################################################################

cleanup();

my $test_ran = 0;

print "Running environment reset..\n";
my $reset_result = `sudo /opt/jenkins/reset`;
print "Reset result: $reset_result\n";

my @testvms = split(',', $reset_result);
foreach $vm (@testvms) {
    my @values = split(':', $vm);

    if($values[0] eq "win7x64") {
        print "Received Windows 7 x64 Test VM ID: $values[1]\n";

        test($values[0], $values[1], $values[2]);

        $test_ran++;
    }

    if($values[0] eq "win7x86") {
        print "Received Windows 7 x86 Test VM ID: $values[1]\n";

        test($values[0], $values[1], $values[2]);

        $test_ran++;
    }
}

cleanup();

if($test_ran > 0) {
    exit 0;
} else {
    print "No test ran, mark build as fail\n";
    exit 1;
}
