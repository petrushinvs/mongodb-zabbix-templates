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

use MongoDB;

use Getopt::Std;
use Zabbix::Sender;

use List::MoreUtils 'any';


my (%opts, $mongo_name, $zab_host, $mongo_port, $mongo_user, $mongo_pass);

getopts("h:u:p:s:n:D",\%opts);

$mongo_name = $opts{h};
$zab_host = $opts{n};
$mongo_port = $opts{p};
$mongo_user = $opts{u};
$mongo_pass = $opts{s};

my $mongo_conn = MongoDB::MongoClient->new("host" => "mongodb://".$mongo_user.':'.$mongo_pass.'@'.$mongo_name.':'.$mongo_port."/admin");

my $q = "mongo -u ".$mongo_user." -p ".$mongo_pass." ".$mongo_name.':'.$mongo_port.'/admin --eval "rs.status()" --quiet 2>&1';
print $q, "\n";
print "zab_host ", $zab_host, "\n";
my $status_str = `$q`;
# this data easy to read by human but can't parse with Jason module for easy automated processing 

my $zab = Zabbix::Sender->new({
        'server' => '127.0.0.1',
        'port' => 10051,
        'hostname' => $zab_host,
    });

$zab->send('mongors_status_str', $status_str); # Send to zabbix full output of rs.status(), also will report if any error with connection

unless ($mongo_conn) {
	$zab->send('mongors_conn_error', 1);  # Send connection error flag
	print "MongoDB connection error!\n";
	exit();
}

$zab->send('mongors_conn_error', 0);

my $db = $mongo_conn->get_database('admin');

my $res = $db->run_command(['replSetGetStatus' => 1]); # Get rs.status() via perl mongo driver -- this data is ready for processing

print $res->{"ok"}, "\n";

$zab->send('mongors_set', $res->{set}); # Send to zabbix replicaset name

my $rs_anyerror = 0;
my $rs_member_error = 0;
my $rs_anyerror_str = "\n";
my $rs_members_visible = 0;
my $rs_member_state = "\n";

for (my $j = 0; $j <= $#{$res->{members}}; $j++) {
	print "j $j\n";
	print "health ", $res->{members}->[$j]->{health}, "\n"; 
	print "state ", $res->{members}->[$j]->{state}, "\n";
	print "name ", $res->{members}->[$j]->{name}, "\n";
	unless (($res->{members}->[$j]->{health} == 1) or (any {$_ == $res->{members}->[$j]->{state}} (1, 2, 3, 5, 7))) {
		$rs_anyerror = 1;  # There is something wrong with replicaset
		$rs_anyerror_str .= "RS Member ".$res->{members}->[$j]->{name}. " is in state ". $res->{members}->[$j]->{state}."\n".
			"RS Member ".$res->{members}->[$j]->{name}. " error string: ".$res->{members}->[$j]->{stateStr}."\n".
			"RS Member ".$res->{members}->[$j]->{name}. " last hearbeat: ".$res->{members}->[$j]->{lastHeartbeat}."\n".
			"RS Member ".$res->{members}->[$j]->{name}. " last hearbeat msg: ".$res->{members}->[$j]->{lastHeartbeatMessage}."\n";
		# This should explain what's wrong with replicaset
		print "rs_anyerror_str: \n",$rs_anyerror_str;
		$rs_member_error = 1 if exists ($res->{members}->[$j]->{self}); # Flag if error occurs on monitored host
		next;
	}
	$rs_members_visible++;
	$rs_member_state = $res->{members}->[$j]->{stateStr} if exists ($res->{members}->[$j]->{self}); # Flag if error occurs on monitored host
}

if ($rs_anyerror == 0) {
	$rs_anyerror_str = "OK";
}

$zab->send('mongors_member_statestr', $rs_member_state);

$zab->send('mongors_anyerror', $rs_anyerror);

$zab->send('mongors_anyerror_str', $rs_anyerror_str);

$zab->send('mongors_member_error', $rs_member_error);

$zab->send('mongors_members_visible', $rs_members_visible);

$zab->send('mongors_members_total', $#{$res->{members}}+1);

print "mongors_members_total ", $#{$res->{members}}+1, "\n";

#print $status_str, "\n\n";



