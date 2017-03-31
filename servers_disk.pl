#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use DBI;
use File::Basename;
use JSON qw(decode_json);
use LWP::Simple;

my $dirname = dirname(__FILE__);

$|++;

my $currTime = localtime();

my $html_pertableinnodb = '
<li>%s
 <ul>
   <li>Free       : %.1f</li>
   <li>InnoDB used: %.1f</li>
   <li>MyISAM used: %.1f</li>
 </ul>
</li>
';

my $html_header = "<html>
<title>%s servers disk usage</title>
<body>
<h1>%s servers disk usage</h1>
<p><i>last updated: %s</i></p>
<img src='%s.png' />
<ol>
";

my $html_footer = "
</ol>
</body>
</html>
";

my $url = 'http://ens-prod-1.ebi.ac.uk:5005/status/';

my $stm = q{
SELECT ENGINE, ROUND(SUM(DATA_LENGTH + INDEX_LENGTH), 2)/(1024*1024*1024) AS size_in_meg
FROM information_schema.TABLES
WHERE ENGINE IN ("InnoDB", "MyISAM")
GROUP BY ENGINE;
};

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
    print $outR join "\t", qw/server Free InnoDB MyISAM/;
    print $outR "\n";

    my %all_stats;

    for my $server (@$servers) {
        my $stats_json = get($url.$server);
        warn "stats from $server: $stats_json\n";
        my $stats = decode_json($stats_json);
        $all_stats{$server} = $stats;
        foreach my $key (qw(disk_available disk_total disk_used)) {
            $stats->{$key} = $1*1024 if $stats->{$key} =~ /^(.*)T$/;
            $stats->{$key} = $1/1024 if $stats->{$key} =~ /^(.*)M$/;
            $stats->{$key} = $1 if $stats->{$key} =~ /^(.*)G$/;
        }
        warn "querying 'information_schema' on $server\n";
        my @size_cmd = ($server, 'batch', '', $stm);
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

        print $outR join "\t", ($server,
            $stats->{disk_available},
            $stats->{innodb_used},
            $stats->{myisam_used});
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
            print $outhtml sprintf($html_pertableinnodb,
                $s,
                $stats->{disk_available},
                $stats->{innodb_used},
                $stats->{myisam_used},
            );
    }
    print $outhtml $html_footer;
    close ($outhtml);
}


