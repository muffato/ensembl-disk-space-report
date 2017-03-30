#!/usr/bin/perl

use strict;
use warnings;

use Net::SSH::Perl;
use Data::Dumper;
use DBI;

$|++;

#my @compara_servers = qw/compara1 compara2 compara3 compara4/;
my $path_to_mysql_dbs = "/mysql/data_3306/databases/";
my $innodb_file_name = "ibdata1\n";
my $df_call = "df -t xfs -P";
my $ls_call = "ls -l $path_to_mysql_dbs/$innodb_file_name";
my $html_file = "compara_servers_disk_load.html";

my $currTime = localtime();

my @servers = (
	       {
		name => 'compara1',
		mysql_port => 2911,
		ssh_port => 2951,
	       },
	       {
		name => 'compara2',
		mysql_port => 2912,
		ssh_port => 2952,
	       },
	       {
		name => 'compara3',
		mysql_port => 2913,
		ssh_port => 2953,
	       },
	       {
		name => 'compara4',
		mysql_port => 2914,
		ssh_port => 2954,
	       },
	       {
		name => 'compara5',
		mysql_port => 2916,
		ssh_port => 2955,
	       }
	      );

my $stm = "SELECT sum(size_in_meg) from (SELECT round(sum(data_length + index_length ) , 2 ) size_in_meg, min(create_time), max(update_time) FROM information_schema.TABLES WHERE ENGINE=(?)   GROUP BY table_schema   ORDER BY size_in_meg DESC) as q;";

open my $outR, ">", "compara_servers_disk.txt";
print $outR join "\t", qw/server Total InnoDB Free InnoDB_free/;
print $outR "\n";

for my $server (@servers) {
  my $mysql_port = $server->{mysql_port};
  $server->{dbh} =  DBI->connect("dbi:mysql:mysql:127.0.0.1:$mysql_port", "ensadmin","ensembl");
  @$server{qw/size avail innodb_tot/} = login($server->{ssh_port});
  my $sth = $server->{dbh}->prepare($stm);
  # $sth->execute('MyISAM');
  # $server->{myisam_u} = $sth->fetchrow_arrayref()->[0];
  $sth->execute('InnoDB');
  $server->{innodb_u} = $sth->fetchrow_arrayref()->[0];

  if (($server->{name} eq 'compara3') || ($server->{name} eq 'compara5')) { # per-table innodb server
    print $outR join "\t", ($server->{name},
			    $server->{size},
			    $server->{innodb_u},
			    $server->{avail},
			    0);  # No innodb available for compara3,5
  } else {
    print $outR join "\t", ($server->{name},
			    $server->{size},
			    $server->{innodb_tot},
			    $server->{avail},
			    $server->{innodb_tot} - $server->{innodb_u});
  }
  print $outR "\n";
}
close ($outR);

# Run R and get the graph back
my $rcommand = "R CMD BATCH compara_servers_disk.R";
system($rcommand);
output_page();

sub login {
## ssh -p 2951 mp12@localhost
  my ($port) = @_;
  my $host = "localhost";
  my $user = "mp12";
  my $pass = "";
  my $ssh = Net::SSH::Perl->new($host, 'port'=>$port, 'debug'=>0);
  $ssh->login($user, $pass);

  my ($ibdata1_info, $err, $exit) = $ssh->cmd($ls_call);
  my ($innodb) = (split/\s+/, $ibdata1_info)[4];

  my ($size, $avail);
  my ($df_info, $err2, $exit2) = $ssh->cmd($df_call);
  for my $df_line (split /\n/, $df_info) {
    my @flds = split /\s+/, $df_line;
    if ($flds[5] =~ /mysql/) {
      ($size, $avail) = @flds[1,3];
    }
  }
  return ($size * 1024, $avail * 1024, $innodb);
}

sub output_page {
  open my ($outhtml), ">", $html_file, or die $!;
  my $div = 1024 * 1024 * 1024;
  print $outhtml "<html>
<body>
<h1>Compara servers disk load</h1>
<p><i>last updated: $currTime</i></p>
<img src='compara_servers_disk.png'></img>
<ol>

<li>Compara1
 <ul>
   <li>Free       : " . sprintf("%.1f", ($servers[0]->{avail}/$div)) . "</li>
   <li>InnoDB free: " . sprintf("%.1f", (($servers[0]->{innodb_tot} - $servers[0]->{innodb_u})/$div)) . "</li>
   <li>InnoDB used: " . sprintf("%.1f", ($servers[0]->{innodb_u}/$div)) . "</li>
   <li>MyISAM used: " . sprintf("%.1f", (($servers[0]->{size} - $servers[0]->{innodb_tot} - $servers[0]->{avail})/$div)) . "</li>
 </ul>
</li>

<li>Compara2
 <ul>
   <li>Free       : " . sprintf("%.1f", ($servers[1]->{avail}/$div)) . "</li>
   <li>InnoDB free: " . sprintf("%.1f", (($servers[1]->{innodb_tot} - $servers[1]->{innodb_u})/$div)) . "</li>
   <li>InnoDB used: " . sprintf("%.1f", $servers[1]->{innodb_u}/$div) . "</li>
   <li>MyISAM used: " . sprintf("%.1f", (($servers[1]->{size} - $servers[1]->{innodb_tot} - $servers[1]->{avail})/$div)) . "</li>
 </ul>
</li>

<li>Compara3
 <ul>
   <li>Free       : " . sprintf("%.1f", ($servers[2]->{avail}/$div)) . "</li>
   <li>InnoDB free: " . sprintf("NA") . "</li>
   <li>InnoDB used: " . sprintf("%.1f", ($servers[2]->{innodb_u}/$div)) . "</li>
   <li>MyISAM used: " . sprintf("%.1f", (($servers[2]->{size} - $servers[2]->{innodb_tot} - $servers[2]->{innodb_u} - $servers[2]->{avail})/$div)) . "</li>
 </ul>
</li>

<li>Compara4
 <ul>
   <li>MyISAM free: " . sprintf("%.1f", ($servers[3]->{avail}/$div)) . "</li>
   <li>InnoDB free: " . sprintf("%.1f", (($servers[3]->{innodb_tot} - $servers[3]->{innodb_u})/$div)) . "</li>
   <li>InnoDB used: " . sprintf("%.1f", ($servers[3]->{innodb_u}/$div)) . "</li>
   <li>MyISAM used: " . sprintf("%.1f", (($servers[3]->{size} - $servers[3]->{innodb_tot} - $servers[3]->{avail})/$div)) . "</li>
 </ul>
</li>

<li>Compara5
 <ul>
   <li>MyISAM free: " . sprintf("%.1f", ($servers[4]->{avail}/$div)) . "</li>
   <li>InnoDB free: " . sprintf("NA") . "</li>
   <li>InnoDB used: " . sprintf("%.1f", ($servers[4]->{innodb_u}/$div)) . "</li>
   <li>MyISAM used: " . sprintf("%.1f", (($servers[4]->{size} - $servers[4]->{innodb_tot} - $servers[4]->{avail})/$div)) . "</li>
 </ul>
</li>

</ol>
</body>
</html>\n";

  close ($outhtml);
}
