package cactus;

sub cactus_init
{
  my $fd = new FileHandle;
  my $config_dir = undef;
  my $config = undef;
  my $cactus_dir = undef;

  if(-d "./src/include/cctk_core.h") {
    $cactus_dir = ".";
  }

  for(my $argn = 0;$argn <= $#ARGV;$argn++) {
    my $arg = $ARGV[$argn];
    if($arg eq "-k") {
      $cactus_dir = $ARGV[++$argn];
      $cactus_dir =~ s{/+$}{};
      die "invalid cactus_dir: $cactus_dir"
        unless(-r "$cactus_dir/src/include/cctk_core.h");
    } elsif($arg eq "-c") {
      $config = $ARGV[++$argn];
    }
  }

  die "cactus_dir not defined" unless(defined($cactus_dir));

  $config_dir = "$cactus_dir/configs";

  if(defined($ENV{CACTUS_CONFIGS_DIR})) {
    $config_dir = $ENV{CACTUS_CONFIGS_DIR};
    $config_dir =~ s{/+$}{};
  }

  if(!defined($config)) {
    my $dd = new FileHandle;
    mkdir($config_dir) unless(-d $config_dir);
    opendir($dd,$config_dir) or die "cannot open $config_dir";
    my @f = ();
    while(my $f = readdir($dd)) {
      next if($f eq ".");
      next if($f eq "..");
      $f[$#f+1]=$f;
    }
    if($#f == 0) {
      $config = $f[0];
    } elsif($#f == -1) {
      $config = "sim";
    } else {
      die "Which config? ".join(", ",@f)."\n";
    }
  }
  my $thorn_list = "$config_dir/$config/ThornList";
  open($fd,$thorn_list) or die "cannot open $thorn_list";
  my %thorn_list = ();
  my %arr_list = ();
  while(my $line = <$fd>) {
    if($line =~ m{^(\w+)/(\w+)}) {
      my ($arr,$thorn) = ("\L$1","\L$2");
      if(defined($thorn_list{$thorn})) {
        print "Thorn $thorn is multiply defined:\n";
        print "Arrangement 1: $arr\n";
        print "Arrangement 2: ",$thorn_list{$thorn},"\n";
      }
      $thorn_list{$thorn} = $arr;
      $arr_list{$arr}++;
    }
  }
  ($cactus::cactus_dir,$cactus::config,$cactus::config_dir,$cactus::thorn_list,$cactus::arr_list)=
    ($cactus_dir,$config,$config_dir,\%thorn_list,\%arr_list);
}

sub visit_thorns
{
  my $func = shift;
  my $darr = new FileHandle;
  my $arr_dir = "$cactus_dir/arrangements";
  opendir($darr,$arr_dir) or die "cannot open $arr_dir";
  while(my $arr = readdir($darr)) {
    next unless(defined($arr_list->{"\L$arr"}));
    my $darr1 = new FileHandle;
    my $arr1_dir = "$arr_dir/$arr";
    opendir($darr1,$arr1_dir) or die "cannot open $arr1_dir";
    while(my $th_dir = readdir($darr1)) {
      my $th = "\L${arr}::$th_dir";
      if(defined($thorn_list->{"\L$th_dir"})) {
        &$func("$arr1_dir/$th_dir",$th_dir);
      }
    }
  }
}

1;
