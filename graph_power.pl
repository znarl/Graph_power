#!/usr/bin/perl -w

use strict;
use lib "/usr/lib/perl/";
use RRDs;
use Math::Round;
use Env qw($TAPO_USERNAME $TAPO_PASSWORD);
use Net::Ping;

my $rrd_d = "/home/karl/bin";
my $rrd = "graph_power";
my $rrd_file = "$rrd_d/$rrd.rrd";
my $end   = "now";
my $output_path = "/var/www/html/graph_power/";
my $graph_file_daily = $output_path . $rrd . "_daily.png";
my $graph_file_weekly = $output_path . $rrd . "_weekly.png";
my $graph_file_monthly = $output_path . $rrd . "_monthly.png";
my $graph_file_yearly = $output_path . $rrd . "_yearly.png";

my $seconds_in_a_day = (24 * 60 * 60);
my $seconds_in_a_week = ($seconds_in_a_day * 7);
my $seconds_in_a_month = ($seconds_in_a_day * 31);
my $seconds_in_a_year = ($seconds_in_a_day * 365);

my $phone_address = "48:2C:A0:29:C8:71";
my $phone_ip = "192.168.100.56";
my $is_home = 0;
my $ping = Net::Ping->new();
my $is_home_human = "No";
my $wimpy_power_ip = "192.168.100.5";
my $ps5_power_ip = "192.168.100.6";
my $router_ip = "192.168.100.20";
my $saltstone_ip = "192.168.100.4";
my $kitchen_ip = "192.168.100.44";


my ( $power_current1, $power_current2, $power_current3, $power_current4, $power_current5) = 0;

# EPROC
my $cur_time = time();
# For Humans time
my $now_string = localtime;

# Do we have a TTY?
my $tty;
isatty();
print "Detected TTY!\n" if ( $tty );

### If RRDtool DB not created, ask manually to create.
if (! -f "$rrd_file" )  {
  print "rrdtool create $rrd_d/$rrd.rrd --step 60 DS:is_home:GAUGE:600:U:U DS:power_current1:GAUGE:600:U:U DS:power_current2:GAUGE:600:U:U DS:power_current3:GAUGE:600:U:U DS:power_current4:GAUGE:600:U:U DS:power_current5:GAUGE:600:U:U RRA:AVERAGE:0.5:1:10080 RRA:AVERAGE:0.5:6:8928 RRA:AVERAGE:0.5:60:43800\n";
  exit;
}

if ( $ping->ping($phone_ip, 5) ) {
	#( pingecho($phone_ip) ) {
  $is_home = 1;
  $is_home_human = "Yes";
}
print "Is Karl Home? $is_home_human ; and in binary now? $is_home\n" if ( $tty );

$power_current1 = get_power_usage ($wimpy_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$power_current2 = get_power_usage ($ps5_power_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$power_current3 = get_power_usage ($router_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$power_current4 = get_power_usage ($saltstone_ip, $TAPO_USERNAME, $TAPO_PASSWORD);
$power_current5 = get_power_usage ($kitchen_ip, $TAPO_USERNAME, $TAPO_PASSWORD);


RRDs::update("$rrd_file", "--template=power_current1:power_current2:power_current3:power_current4:power_current5:is_home", "N:$power_current1:$power_current2:$power_current3:$power_current4:$power_current5:$is_home");

# Daily
my $start_place = $cur_time - $seconds_in_a_day;
graph_it( $graph_file_daily, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home);
print "Daily graph $graph_file_daily, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home\n" if ( $tty );

# Weekly
$start_place = $cur_time - $seconds_in_a_week;
graph_it( $graph_file_weekly, $start_place, , $power_current1, $power_current2, $power_current3, $power_current4, $is_home);
print "Weekly graph $graph_file_daily, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home\n" if ( $tty );

# Monthly
$start_place = $cur_time - $seconds_in_a_month;
graph_it( $graph_file_monthly, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home);
print "Monthly graph $graph_file_daily, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home\n" if ( $tty );

# Yearly
$start_place = $cur_time - $seconds_in_a_year;
graph_it( $graph_file_yearly, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home);
print "Yearly graph $graph_file_daily, $start_place, $power_current1, $power_current2, $power_current3, $power_current4, $is_home\n" if ( $tty );

sub graph_it {
 	my ( $file_name, $start_time, $power_current1, $power_current2, $power_current3, $power_current4, $is_home) = @_;
 	
	RRDs::graph($file_name,
        "-w", "1800", "-h", "200",
        "--start", $start_time,
        "--end",   "now",
        "--watermark", $now_string,
        "--title",  "Power Usages",
	"--color=BACK#CCCCCC",
	"--color=SHADEB#9999CC",
        "DEF:data1=$rrd_file:power_current1:AVERAGE",
        "DEF:data2=$rrd_file:power_current2:AVERAGE",
        "DEF:data3=$rrd_file:power_current3:AVERAGE",
        "DEF:data4=$rrd_file:power_current4:AVERAGE",
        "DEF:data4=$rrd_file:power_current5:AVERAGE",
        "DEF:data5=$rrd_file:is_home:AVERAGE",
        "CDEF:cps1=data1",
        "CDEF:cps2=data2",
        "CDEF:cps3=data3",
        "CDEF:cps4=data4",
        "CDEF:cps5=data5,50,*",
        "TICK:cps5#ffffa0:1.0:  Home - $is_home_human",
        "LINE2:cps1#41f456:Wimpy - $power_current1 Watts",
        "LINE2:cps2#f44277:Entertainment System - $power_current2 Watts",
        "LINE2:cps3#0000FF:Internet Router - $power_current3 Watts",
        "LINE2:cps4#8e90bd:Salt Stone - $power_current4 Watts",
        "LINE2:cps4#8e10bd:Kitchen - $power_current5 Watts",
	) or die "RRDs graph: " . RRDs::error();
}

sub get_power_usage {
    my ($device_ip, $username, $password) = @_;

    # Run the kasa command to get power usage
    my $command_output = `/usr/local/bin/kasa --host $device_ip --username $username --password $password`;

    # Check if the command was successful
    if ($? != 0) {
        my $exit_code = $? >> 8;
        print "Error: Unable to get power usage from device at $device_ip (Exit code: $exit_code).\n";
        return undef; # Return undefined on failure
    }

    # Extract power usage from the command output
    if ($command_output =~ /(\d+\.?\d*)\s*W/) {
        return $1; # Return the power usage in watts
    } else {
        print "Error: Unable to parse power usage from device at $device_ip.\n";
        return undef; # Return undefined if parsing fails
    }
}

sub isatty {
  return -t STDIN || -t STDOUT || -t STDERR;
}
