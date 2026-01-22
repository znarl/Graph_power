# Graph Power

Graph the power usage of different smart plugs using RRD and generate time-series visualizations.

## Features

- Monitors multiple TP-Link Tapo smart plugs via the `kasa` CLI tool
- Tracks home presence using IP-based device detection (phone ping)
- Generates RRD graphs for daily, weekly, monthly, and yearly power trends
- Displays power consumption and home status on graphs
- Supports both newer (KLAP) and older protocol versions for device compatibility

## Dependencies

- Perl 5 with the following modules:
  - `RRDs` - RRD database and graphing
  - `Math::Round` - Rounding utilities
  - `Net::Ping` - Network availability detection
- `rrdtool` - Time-series database engine
- `kasa` - TP-Link Tapo device CLI tool (installed at `/usr/local/bin/kasa`)

## Setup

### Database Initialization

If the RRD database doesn't exist, the script will display the command to create it:

```bash
rrdtool create graph_power.rrd --step 60 \
  DS:is_home:GAUGE:600:U:U \
  DS:power_current1:GAUGE:600:U:U \
  DS:power_current2:GAUGE:600:U:U \
  DS:power_current3:GAUGE:600:U:U \
  DS:power_current4:GAUGE:600:U:U \
  DS:power_current5:GAUGE:600:U:U \
  DS:power_current6:GAUGE:600:U:U \
  DS:power_current7:GAUGE:600:U:U \
  RRA:AVERAGE:0.5:1:10080 \
  RRA:AVERAGE:0.5:6:8928 \
  RRA:AVERAGE:0.5:60:43800
```

### Configuration

Edit the `@devices` array in the script to add/remove devices:

```perl
my @devices = (
    { name => "Device Name",  ip => "192.168.100.XX", newer => 1 },
    ...
);
```

- `name`: Display name for the device on graphs
- `ip`: IP address of the device on the network
- `newer`: Set to `1` for KLAP protocol (newer devices), `0` for older protocol

## Output

- Generated graphs are saved to `/var/www/html/graph_power/`:
  - `graph_power_daily.png` - Last 24 hours
  - `graph_power_weekly.png` - Last 7 days
  - `graph_power_monthly.png` - Last 31 days
  - `graph_power_yearly.png` - Last 365 days

## Usage

Run manually or via cron job:

```bash
./graph_power.pl
```

For verbose output, run with a TTY attached. When run as a cron job (no TTY), it operates silently.
