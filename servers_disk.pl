#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use DBI;

use JSON qw(decode_json);

$|++;

my $df_call = 'df -t xfs -P';

my $currTime = localtime();

my $html_pertableinnodb = '
<li>%s: %d
 <ul>
   <li>Free       : %.1f</li>
   <li>InnoDB free: NA</li>
   <li>InnoDB used: %.1f</li>
   <li>MyISAM used: %.1f</li>
 </ul>
</li>
';

my $html_nopertableinnodb = '
<li>%s: %d
 <ul>
   <li>Free       : %.1f</li>
   <li>InnoDB free: %.1f</li>
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

my $stm = "SELECT sum(size_in_meg) from (SELECT round(sum(data_length + index_length ) , 2 ) size_in_meg, min(create_time), max(update_time) FROM information_schema.TABLES WHERE ENGINE=(?)   GROUP BY table_schema   ORDER BY size_in_meg DESC) as q;";

process($_) for @ARGV;

sub process {
    my $config_file = shift;
    local $/;
    open( my $fh, '<', $config_file );
    my $json_text = <$fh>;
    my $json_config = decode_json($json_text);
    my $servers = $json_config->{servers};
    print Dumper($servers);
    my $title = $json_config->{title};
    my $filename_prefix = lc $title;
    warn "Processing $title\n";

    open my $outR, ">", "${filename_prefix}.txt";
    print $outR join "\t", qw/server Total InnoDB Free InnoDB_free/;
    print $outR "\n";

    for my $server (@$servers) {
        $server->{mysql_port} ||= 3306;
        my $mysql_port = $server->{mysql_port};
        warn "ssh-ing $server->{name}\n";
        my $path = ($server->{path} || "/mysql/data_${mysql_port}/")."/databases/ibdata1";
        eval {
            @$server{qw/size avail innodb_tot/} = login($server->{name}, $path);
            #@$server{qw/size avail innodb_tot/} = login($server->{name}, "/mysql/data_${mysql_port}/databases/ibdata1");
        };
        next if $@ or not defined $server->{size};

        warn "querying 'information_schema' on $server->{name}\n";
        eval {
            my $dbh =  DBI->connect("dbi:mysql::$server->{name}:$mysql_port", "ensro", "");
            my $sth = $dbh->prepare($stm);
            $sth->execute('InnoDB');
            $server->{innodb_u} = $sth->fetchrow_arrayref()->[0] || 0;
        };
        if ($@) {
            $server->{innodb_u} =  $server->{innodb_tot};
            $server->{pertableinnodb} = 1;
        }

        my $m = $server->{mult} || 1;
        print $outR join "\t", ($server->{name},
            $m * ($server->{size}),
            $m * ($server->{pertableinnodb} ? $server->{innodb_u} : $server->{innodb_tot}),
            $m * ($server->{avail}),
            $m * ($server->{pertableinnodb} ? 0 : $server->{innodb_tot} - $server->{innodb_u}));
        print $outR "\n";
        $server->{complete} = 1;
    }
    close ($outR);

    # Run R and get the graph back
    my $rcommand = "Rscript ../servers_disk.R ${filename_prefix}.txt ${filename_prefix}.png";
    warn "Calling R: $rcommand\n";
    system($rcommand);
    warn "Parsing R's output\n";

    open(my $outhtml, ">", "${filename_prefix}.html") or die $!;
    my $div = 1024 * 1024 * 1024;
    print $outhtml sprintf($html_header, $title, $title, $currTime, $filename_prefix);
    foreach my $s (@$servers) {
        next unless $s->{complete};
        if ($s->{pertableinnodb}) {
            print $outhtml sprintf($html_pertableinnodb,
                $s->{name}, $s->{mysql_port},
                $s->{avail}/$div,
                $s->{innodb_u}/$div,
                ($s->{size} - $s->{innodb_tot} - $s->{innodb_u} - $s->{avail})/$div,
            );
        } else {
            print $outhtml sprintf($html_nopertableinnodb,
                $s->{name}, $s->{mysql_port},
                $s->{avail}/$div,
                ($s->{innodb_tot} - $s->{innodb_u})/$div,
                $s->{innodb_u}/$div,
                ($s->{size} - $s->{innodb_tot} - $s->{avail})/$div,
            );
        }
    }
    print $outhtml $html_footer;
    close ($outhtml);
}

sub login {
  my ($host, $path) = @_;

  my $ibdata1_info = ssh($host, "ls -l $path\n");
  return if $?;
  my ($innodb) = (split/\s+/, $ibdata1_info)[4];

  my ($size, $avail);
  my $df_info = ssh($host, "df -P $path");
  return if $?;
  for my $df_line (split /\n/, $df_info) {
    next if $df_line =~ /^Filesystem/;
    my @flds = split /\s+/, $df_line;
    if ($flds[5] =~ /mysql/) {
      ($size, $avail) = @flds[1,3];
    }
  }
  return ($size * 1024, $avail * 1024, $innodb);
}

sub ssh {
    my ($host, $command) = @_;
    # Default parameters: port 22, same user, no password (keys are assumed)
    my $cmd = qq(ssh -o StrictHostKeyChecking=no $host $command);
    return `$cmd`;
}


