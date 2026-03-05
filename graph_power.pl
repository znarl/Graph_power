#!/usr/bin/perl -w

use strict;
use lib "/usr/lib/perl/";
use RRDs;
use Math::Round;
use Env qw($TAPO_USERNAME $TAPO_PASSWORD $TAPO_CREDENTIALS_HASH);
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
my $graph_file_alltime = $output_path . $rrd . "_alltime.png";

my $seconds_in_a_day = (24 * 60 * 60);
my $seconds_in_a_week = ($seconds_in_a_day * 7);
my $seconds_in_a_month = ($seconds_in_a_day * 31);
my $seconds_in_a_year = ($seconds_in_a_day * 365);

my $phone_ip = "192.168.100.56";
my $ping_retries = 3;
my $ping_timeout = 2;
my $is_home = 0;
my $ping = Net::Ping->new();
my $is_home_human = "No";

# Device configuration: name, IP, use_newer_protocol
my @devices = (
    { name => "Wimpy",                   ip => "192.168.100.95",  newer => 1 },
    { name => "Entertainment System",    ip => "192.168.100.6",   newer => 1 },
    { name => "Internet Router",         ip => "192.168.100.20",  newer => 1 },
    { name => "Salt Stone",              ip => "192.168.100.4",   newer => 1 },
    { name => "Kitchen",                 ip => "192.168.100.99",  newer => 1 },
    { name => "Bedroom TV",              ip => "192.168.100.5",   newer => 1 },
    { name => "Fridge",                  ip => "192.168.100.123", newer => 1 },
    { name => "Whatevs",                 ip => "192.168.100.124", newer => 1 },
);
# total number of devices, used for dynamic RRD definitions
my $device_count = scalar @devices;

my @power_current = ();

# EPROC
my $cur_time = time();
# For Humans time
my $now_string = localtime;

# Do we have a TTY?
my $tty=istty();
print "Found a TTY, printing debug.\n" if $tty;


### If RRDtool DB not created, print instructions to create a suitable database.
if (! -f "$rrd_file" )  {
    # build DS entries for each device dynamically
    my @ds_entries = ("DS:is_home:GAUGE:600:U:U");
    for my $i (1 .. $device_count) {
        push @ds_entries, "DS:power_current$i:GAUGE:600:U:U";
    }
    my $ds_str = join(" ", @ds_entries);
    print "rrdtool create $rrd_d/$rrd.rrd --step 60 $ds_str RRA:AVERAGE:0.5:1:10080 RRA:AVERAGE:0.5:6:8928 RRA:AVERAGE:0.5:60:43800\n";
    exit;
}


for my $i (1 .. $ping_retries) {
  if ( $ping->ping($phone_ip, $ping_timeout) ) {
    $is_home = 1;
    $is_home_human = "Yes";
  }
}
print "Is Karl Home? $is_home_human ; and in binary now? $is_home\n" if ( $tty );

# Retrieve power usage from all devices
foreach my $device (@devices) {
    my $power = get_power_usage($device);
    push @power_current, $power;
}


# Build RRD update string
my $power_string = join ":", @power_current;
my @templates = (map { "power_current" . ($_ + 1) } 0 .. $#devices);
push @templates, "is_home";
my $template_str = join(":", @templates);
RRDs::update("$rrd_file", "--template=$template_str", "N:$power_string:$is_home");

# Graph configurations
my @graphs = (
    { label => "Daily",   file => $graph_file_daily,   offset => $seconds_in_a_day },
    { label => "Weekly",  file => $graph_file_weekly,  offset => $seconds_in_a_week },
    { label => "Monthly", file => $graph_file_monthly, offset => $seconds_in_a_month },
    { label => "Yearly",  file => $graph_file_yearly,  offset => $seconds_in_a_year },
    { label => "All Time", file => $graph_file_alltime, offset => $seconds_in_a_year * 10 },
);

# Generate graphs
foreach my $graph (@graphs) {
    my $start_place = $cur_time - $graph->{offset};
    graph_it($graph->{file}, $start_place, \@power_current, $is_home, \@devices);
    print "$graph->{label} graph $graph->{file}, $start_place\n" if ( $tty );
}

sub graph_it {
 	my ( $file_name, $start_time, $power_ref, $is_home, $devices_ref) = @_;
 	my @power_values = @$power_ref;
 	my @dev_list = @$devices_ref;
 	
	RRDs::graph($file_name,
        "-w", "1800", "-h", "200",
        "--start", $start_time,
        "--end",   "now",
        "--watermark", $now_string,
        "--title",  "Power Usage",
	"--color=BACK#CCCCCC",
	"--color=SHADEB#9999CC",
        # device data DEFs
        (map { "DEF:data" . ($_ + 1) . "=$rrd_file:power_current" . ($_ + 1) . ":AVERAGE" } (0 .. $#dev_list)),
        # is_home def uses next index
        "DEF:data" . ($#dev_list + 2) . "=$rrd_file:is_home:AVERAGE",
        # create CDEFs for devices
        (map { "CDEF:cps" . ($_ + 1) . "=data" . ($_ + 1) } (0 .. $#dev_list)),
        # is_home CDEF
        "CDEF:cps" . ($#dev_list + 2) . "=data" . ($#dev_list + 2),
        # tick line for home indicator
        "TICK:cps" . ($#dev_list + 2) . "#ffffa0:1.0:  Home - $is_home_human",
        # actual device lines (cycle through colors if needed)
        (map { my $i = $_; my $color_map = ["#41f456", "#f44277", "#0000FF", "#8e90bd", "#8e10bd", "#Ce505d", "#ADD8E6", "#12D8E6"]; my $color = $color_map->[$i % @$color_map]; "LINE2:cps" . ($i + 1) . $color . ":" . $dev_list[$i]{name} . " - " . $power_values[$i] . " Watts" } (0 .. $#dev_list)),
	) or die "RRDs graph: " . RRDs::error();
}

sub get_power_usage {
    my ($device) = @_;
    my $device_ip = $device->{ip};
    my $use_newer = $device->{newer};
    my $device_name = $device->{name};
    $use_newer //= 1;  # Default to newer protocol

    print "Getting power from device $device_name ($device_ip)... \t" if $tty;
    
    my $command_output;
    if ($use_newer) {
        $command_output = `/usr/local/bin/kasa --credentials-hash "$TAPO_CREDENTIALS_HASH" --encrypt-type "KLAP" --device-family "SMART.TAPOPLUG" --host $device_ip`;
    } else {
        # Older protocol for older devices
        $command_output = `/usr/local/bin/kasa --credentials-hash "$TAPO_CREDENTIALS_HASH" --host $device_ip`;
    }

    if ($? != 0) {
        my $exit_code = $? >> 8;
        print "Error: Unable to get power usage from $device_name at $device_ip (Exit code: $exit_code).\n" if $tty;
        return 0;
    }

    if ($command_output =~ /(\d+\.?\d*)\s*W/) {
        print "$1 Watts\n" if $tty;
        return $1;  # Return the power usage in watts
    } else {
        print "Error: Unable to parse power usage from $device_name at $device_ip.\n" if $tty;
        return 0;  # Return 0 if parsing fails
    }
}

sub istty {
  return -t STDIN || -t STDOUT || -t STDERR;
}
