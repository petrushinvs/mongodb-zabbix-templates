#!/usr/bin/perl -w

=head1 AUTHORS

Vasily Petrushin, http://petrushin.org

=head1 COPYRIGHT

**********************************************************************
                          MIT License
**********************************************************************
Copyright (c) 2016 Vasily Petrushin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

************************************************************************

=head1 SUPPORT / WARRANTY

This is free Open Source software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=cut


use strict;

use Getopt::Std;
use Zabbix::Sender;

my (%opts, $mongo_name, $zab_host, $mongo_port, $mongo_user, $mongo_pass);

getopts("h:u:p:s:n:D",\%opts);

$mongo_name = $opts{h};
$zab_host = $opts{n};
$mongo_port = $opts{p};
$mongo_user = $opts{u};
$mongo_pass = $opts{s};

my $zab = Zabbix::Sender->new({
        'server' => '127.0.0.1',
        'port' => 10051,
        'hostname' => $zab_host,
    });


my $str = "mongostat -u $mongo_user -p $mongo_pass -h $mongo_name:$mongo_port --authenticationDatabase=admin --rowcount 1 --noheaders".' 2>&1';

my $res = `$str`;

print "DEBUG: str\n", $str, "\n\n";
print "DEBUG: res\n", $res, "\n\n";

my ($insert, $query, $update, $delete, $getmore, $command);
my ($dirty, $used, $flushes, $vsize, $resm);
my ($qr, $qw, $ar, $aw, $flt);
my ($netin, $netout, $conn);
my ($set, $repl);

my ($err, $state, $t, $total_ops);

my @r;

if ($res =~ m/error/) {
	$state = 0;
	$err = $res;
	$zab->send("mongos_state", $state);
	$zab->send("mongos_errstr", $err);
	exit 0;
};


$res =~ s/\*//g;
$res =~ s/^ +//g;

@r = split (/ +/, $res);
if ($#r > 0) {
	$state = 1;
	$err = "OK";
	($insert, $query, $update, $delete, $getmore, $command, $flushes, $vsize, $resm, $flt, $qr, $ar, $netin, $netout, $conn, $set, $repl, $t) = @r;
	$zab->send("mongos_state", $state);
        $zab->send("mongos_errstr", $err);
	$zab->send("mongos_insert", $insert);
	$zab->send("mongos_query", $query);
	$zab->send("mongos_update", $update);
	$zab->send("mongos_delete", $delete);
	$zab->send("mongos_getmore", $getmore);
	if ($command =~ /(\d+)\|(\d+)/) {
		$command = $1 + $2;
	};
	$zab->send("mongos_command", $command);
	$total_ops = $insert + $query + $update + $delete + $getmore + $command;
	$zab->send("mongos_total_ops", $total_ops);
	$zab->send("mongos_conn", $conn);
	if (($vsize =~ /(\d+\.\d+)([a-z]|[A-Z]+)/) or ($vsize =~ /(\d+)([a-z]|[A-Z]+)/)) { 
                if ($2 eq 'k') {
                        $vsize = $1 * 1024;
                } elsif (($2 eq 'M') or ($2 eq 'm')) {
                        $vsize = $1 * 1024 * 1024;
                } elsif (($2 eq 'G') or ($2 eq 'g')) {
                        $vsize = $1 * 1024 * 1024 * 1024;
                } else {
                        $vsize = $1;
                };
        };
	$vsize = int $vsize;
	$zab->send("mongos_vsize", $vsize);
	if (($netin =~ /(\d+\.\d+)([a-z]|[A-Z]+)/) or ($netin =~ /(\d+)([a-z]|[A-Z]+)/)) {
		if ($2 eq 'k') {
			$netin = $1 * 1024;
		} elsif (($2 eq 'M') or ($2 eq 'm')) {
			$netin = $1 * 1024 * 1024;
		} elsif (($2 eq 'G') or ($2 eq 'g')) {
			$netin = $1 * 1024 * 1024 * 1024;
		} else {
			$netin = $1;
		};
	};
	$netin = int $netin;
	$zab->send("mongos_netin", $netin);
	if (($netout =~ /(\d+\.\d+)([a-z]|[A-Z]+)/) or ($netout =~ /(\d+)([a-z]|[A-Z]+)/)) {
                if ($2 eq 'k') {
                        $netout = $1 * 1024;
                } elsif (($2 eq 'M') or ($2 eq 'm')) {
                        $netout = $1 * 1024 * 1024;
                } elsif (($2 eq 'G') or ($2 eq 'g')) {
                        $netout = $1 * 1024 * 1024 * 1024;
                } else {
                        $netout = $1;
                };
        };
	$netout = int $netout;
	$zab->send("mongos_netout", $netout);
} else {
	$state = 1;
	$err = "UNKNOWN ERROR! ".$res;
	$zab->send("mongos_state", $state);
        $zab->send("mongos_errstr", $err);
};


exit 1;



