#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Data::Dumper;
use DBI;
use File::Basename;
use IPC::Cmd qw(run);
use JSON qw(decode_json);
use LWP::Simple;

my $dirname = dirname(__FILE__);

$|++;

my $currTime = localtime();

my $html_perserver = '
<li>%s
 <ul>
   <li>Free       : %.1f</li>
   <li>InnoDB used: %.1f</li>
   <li>MyISAM used: %.1f</li>
   <li>Used (other): %.1f</li>
 </ul>
 <label for="%s">&gt; Show per-database disk usage</label>
 <input type="checkbox" id="%s"/>
 <div>
  <pre>
   %s
  </pre>
 </div>
 <br/>
</li>
';

my $html_header = q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
 <title>%s servers disk usage</title>
 <style type='text/css'>
input[type=checkbox] + div {
  display: none;
}
input[type=checkbox]:checked + div {
  display: block;
}
 </style>
</head>
<body>
<h1>%s servers disk usage</h1>
<p>
 <i>last updated: %s</i><br/>
 <img src='%s.png' alt='(Disk usage barplot)'/>
</p>
<ol>
};

my $html_footer = "
</ol>
</body>
</html>
";

my $url = 'http://ens-prod-1.ebi.ac.uk:5002/hosts/';
my $mysql_cmd_path = '/nfs/software/ensembl/mysql-cmds/ensembl/bin/';
my $stm = q{
SELECT ENGINE, ROUND(SUM(DATA_LENGTH + INDEX_LENGTH), 2)/(1024*1024*1024) AS size_in_meg
FROM information_schema.TABLES
WHERE ENGINE IN ("InnoDB", "MyISAM")
GROUP BY ENGINE;
};
my $db_space_path = '/homes/muffato/workspace/src/ensembl/ensembl/misc-scripts/db/db-space.pl';

process($_) for @ARGV;

sub process {
    my $config_file = shift;

    local $/;
    open( my $fh, '<', $config_file );
    my $json_text = <$fh>;
    close($fh);

    my $json_config = decode_json($json_text);
    my $servers = $json_config->{servers};
    print Dumper($servers);
    my $title = $json_config->{title};
    my $filename_prefix = lc $title;
    warn "Processing $title\n";

    open my $outR, ">", "${filename_prefix}.txt";
    print $outR join "\t", qw/server Free InnoDB MyISAM other/;
    print $outR "\n";

    my %all_stats;

    for my $server (@$servers) {
        my $stats_json = get($url.$server);
        warn "stats from $server: $stats_json\n";
        my $stats = decode_json($stats_json);
        $all_stats{$server} = $stats;
        warn "querying 'information_schema' on $server\n";
        my $mysql_cmd = $mysql_cmd_path.'/'.$server;
        my @size_cmd = ($mysql_cmd, 'batch', '', $stm);
        local $/ = "\n";
        open(my $size_fh, '-|', @size_cmd);
        while (<$size_fh>) {
            warn "Line: $_";
            my @t = split;
            if ($t[0] eq 'InnoDB') {
                $stats->{innodb_used} = $t[1];
            } else {
                $stats->{myisam_used} = $t[1];
            }
        }
        close($size_fh);
        my $per_db_size_cmd = "$db_space_path \$($mysql_cmd details script)";
        my @a = run( command => $per_db_size_cmd, verbose => 1 );
        die "Cannot run '$per_db_size_cmd': $a[1]\n" unless $a[0];
        $stats->{per_db} = join("", @{$a[3]});
        $stats->{per_db} =~ s/\n/<br\/>/g;

        print $outR join "\t", ($server,
            $stats->{disk_available_g},
            $stats->{innodb_used},
            $stats->{myisam_used},
            $stats->{disk_total_g}-$stats->{disk_available_g}-$stats->{innodb_used}-$stats->{myisam_used},
        );
        print $outR "\n";
    }
    close ($outR);

    # Run R and get the graph back
    my $rcommand = "Rscript $dirname/servers_disk.R ${filename_prefix}.txt ${filename_prefix}.png";
    warn "Calling R: $rcommand\n";
    system($rcommand);
    warn "Parsing R's output\n";

    open(my $outhtml, ">", "${filename_prefix}.html") or die $!;
    my $div = 1024 * 1024 * 1024;
    print $outhtml sprintf($html_header, $title, $title, $currTime, $filename_prefix);
    foreach my $s (@$servers) {
        my $stats = $all_stats{$s};
            print $outhtml sprintf($html_perserver,
                $s,
                $stats->{disk_available_g},
                $stats->{innodb_used},
                $stats->{myisam_used},
                $stats->{disk_total_g}-$stats->{disk_available_g}-$stats->{innodb_used}-$stats->{myisam_used},
                $s, $s,
                $stats->{per_db},
            );
    }
    print $outhtml $html_footer;
    close ($outhtml);
}


