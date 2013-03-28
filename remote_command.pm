#!/usr/bin/perl -w
# By:      john@stilen.com
# Purpose: Run command on remote host over ssh, 
#          but gracefully don't hang the program
#          if there is a problem.
#---------------------------------
# Install Modules:
#   aptitude install libgmp3-dev
#   perl -MCPAN -e 'install Net::SSH::Perl'
#   perl -MCPAN -e 'install Math::BigInt::GMP'
#   perl -MCPAN -e 'install Math::GMP
#   perl -MCPAN -e '$ENV{FTP_PASSIVE} = 1; install Math::Pari'
#   perl -MCPAN -e 'install Net::SCP::Expect'
# Test install:
#   perl -mMath::BigInt -e 1
#   perl -mMath::BigInt::Calc -e 1
#   perl -mMath::GMP -e 1
#   perl -mNet::SSH::Perl -e 1
# Usage:
#   use remote_command qw(&run_remote);
#   $remote_host="myhost.my.domain.com";
#   $remote_user="builder";
#   $remote_command="ls";
#   &run_remote($remote_host,$remote_user,$remote_command);
#----------------------------------
#
# Module Name
#
package remote_command;
#
# Loading phayse exports sub run_remote()
#
BEGIN {
    use Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(run_remote copy_remote);
}
#
# Load dependent modules
#
use strict;
use Net::SSH::Perl;
use Math::BigInt::GMP;     # Don't forget this!
use Math::GMP;
use Net::SCP::Expect;
#
# Takes a server, user, and command
# This does not rely on sshkeys for authenticaiton
#
sub run_remote(){
    #print "Inside run_remote\n";
    #
    # get the command to run
    # 
    my $server=shift();
    my $username=shift();
    my $password=shift();
    my $command=shift();
    #
    # this is a hack ensures a $ssh exists in case Create object fails.
    #
    my $ssh;
    #
    # Create object, can fail for many reasons
    #
    eval{
        $ssh = Net::SSH::Perl->new(
            $server,
            debug => 0, 
            protocol => 2,
            options => [
                "UserKnownHostsFile=/dev/null",
                "StrictHostKeyChecking=no",
                "BatchMode=yes",
            ],
        ) || die "NEW-UNK-ERR:$!\n";
    };
    if ($@){
        if( $@ =~ /Net::SSH: Bad host name/){
	        die "BAD_HOST\n"; # name resolution
        } elsif( $@ =~ /Connection refused at/){
	        die "CON_REFU\n"; # sshd port not responding
	    } elsif( $@ =~ /No route to host/){
	        die "HOST_DWN\n"; # no host at IP
	    } else {
            die $@;           # unanticipated error
        }
    }
    #
    # Log-in, use user/passwd if given
    #
    if ( ($username =~ m//) || ($password =~ m// )){
        eval{
            $ssh->login($username,$password) || die "LOGIN-UNK-ERR:$!\n";
        };
    } else {
        eval{
            $ssh->login($username,$password) || die "LOGIN-UNK-ERR:$!\n";
        };
    }
    if ($@){
        if( $@ =~ /Permission denied/){
	        die "PRM_DENY";    # ssh key not authorized
        } elsif( $@ =~ /Too many authentication failures for/){
	        die "ATH_FAILL\n"; # too many authenticaton failures in little time
	    } elsif( $@ =~ /Bad file descriptor/){
	        die "BAD_DESC\n";  # no host at IP
	    } else {
            die $@;            # unanticipated error
        }
    }
    #
    # Print stdout as we get it
    #
    $ssh->register_handler( 
        "stdout", 
        sub {
            my($channel, $buffer) = @_;
            print $buffer->bytes;
        }
    ) || die"REG-UNK-ERR";;
    #
    # Run the command
    #
    local $|=1;
    my ($stdout, $stderr, $exit) = $ssh->cmd($command); # Check output
    return;
}
#
# Copy file to remote 
#
sub copy_remote(){
    #print "Inside copy_remote\n";
    #
    # get the command to run
    # 
    my $server=shift();
    my $username=shift();
    my $password=shift();
    my $local_source=shift();
    my $remote_detination=shift();
    #
    #  Test if file exists
    # 
    ( -f $local_source )|| die "Error: File does not exist: ($local_source):$!\n";
    #
    # Copy the file 
    #   UserKnownHostsFile=/dev/null
    #   StrictHostKeyChecking=no 
    # 
    my $scpe;
    eval{
        $scpe = Net::SCP::Expect->new(
            host=>$server, 
            user=>$username, 
            password=>$password,
            protocol=>2,
            auto_yes=>'yes',
            timeout=>30,
            options => [
                "UserKnownHostsFile /dev/null",
                "StrictHostKeyChecking no",
                "BatchMode yes",
            ],
        );
    };
    if ($@){
        if( $@ =~ /scp timed out/){
	        die "TIME_OUT\n";    # scp timed out while trying to connect to
        } elsif( $@ =~ /Problem performing scp/){
	        die "LOST_CON\n";    # Problem performing scp: Lost connection 
        } else {
            die $@;              # unanticipated error
        }
    }
    $scpe->scp($local_source,$remote_detination) || die "REG-UNK-ERR";
    return;
}
return 1;
END { }
